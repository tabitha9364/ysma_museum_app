import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_analytics_service.dart';

class RecentActivity {
  final String type;
  final String artworkTitle;
  final DateTime createdAt;

  const RecentActivity({
    required this.type,
    required this.artworkTitle,
    required this.createdAt,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      type: json['type']?.toString() ?? 'view',
      artworkTitle: json['artworkTitle']?.toString() ?? 'Artwork',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'artworkTitle': artworkTitle,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class UserPreferences {
  static const String _savedEmailKey = 'saved_email';
  static const String _savedDisplayNamePrefix = 'saved_display_name.';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _favoriteArtworkIdsKey = 'favorite_artwork_ids';
  static const String _recentActivitiesKey = 'recent_activities';

  static final ValueNotifier<int> activityVersion = ValueNotifier<int>(0);
  static final ValueNotifier<int> profileVersion = ValueNotifier<int>(0);
  static final Map<String, String> _displayNamesByEmail = {};

  static String getCurrentUserDisplayName() {
    final user = Supabase.instance.client.auth.currentUser;
    return displayNameForUser(user);
  }

  static String getCurrentUserFirstName() {
    return _firstName(getCurrentUserDisplayName());
  }

  static String displayNameForUser(User? user) {
    final metadataName = metadataDisplayNameForUser(user);

    if (metadataName != null) {
      return metadataName;
    }

    final email = user?.email;
    if (email != null && email.trim().isNotEmpty) {
      final savedDisplayName = _displayNamesByEmail[_emailKey(email)];

      if (savedDisplayName != null && savedDisplayName.isNotEmpty) {
        return savedDisplayName;
      }

      return _cleanName(email.split('@').first.replaceAll('.', ' '));
    }

    return 'Visitor';
  }

  static String? metadataDisplayNameForUser(User? user) {
    final metadata = user?.userMetadata ?? {};
    final metadataName =
        metadata['full_name'] ??
        metadata['name'] ??
        metadata['display_name'] ??
        metadata['preferred_username'];

    if (metadataName == null || metadataName.toString().trim().isEmpty) {
      return null;
    }

    return _cleanName(metadataName.toString());
  }

  static bool hasMetadataDisplayName(User? user) {
    return metadataDisplayNameForUser(user) != null;
  }

  static String _firstName(String name) {
    final cleaned = _cleanName(name);

    if (cleaned.isEmpty) {
      return 'Visitor';
    }

    return cleaned.split(' ').first;
  }

  static String _cleanName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  static Future<void> saveEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedEmailKey, trimmedEmail);
  }

  static Future<String?> getSavedDisplayNameForEmail(String email) async {
    final key = _emailKey(email);

    if (key.isEmpty) {
      return null;
    }

    final cachedName = _displayNamesByEmail[key];
    if (cachedName != null && cachedName.isNotEmpty) {
      return cachedName;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('$_savedDisplayNamePrefix$key');
    final cleanedName = savedName == null ? null : _cleanName(savedName);

    if (cleanedName != null && cleanedName.isNotEmpty) {
      _displayNamesByEmail[key] = cleanedName;
    }

    return cleanedName;
  }

  static Future<void> saveDisplayNameForEmail(
    String email,
    String displayName,
  ) async {
    final key = _emailKey(email);
    final cleanedName = _cleanName(displayName);

    if (key.isEmpty || cleanedName.isEmpty) {
      return;
    }

    _displayNamesByEmail[key] = cleanedName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_savedDisplayNamePrefix$key', cleanedName);
    _notifyProfileChanged();
  }

  static Future<void> cacheProfileFromUser(User? user) async {
    final email = user?.email;

    if (email == null || email.trim().isEmpty) {
      return;
    }

    final metadataName = metadataDisplayNameForUser(user);

    if (metadataName != null) {
      await saveDisplayNameForEmail(email, metadataName);
      return;
    }

    await getSavedDisplayNameForEmail(email);
  }

  static Future<void> primeCurrentUserProfile() async {
    await cacheProfileFromUser(Supabase.instance.client.auth.currentUser);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  static Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, complete);
  }

  static Future<Set<int>> getFavoriteArtworkIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favoriteArtworkIdsKey) ?? [];

    return ids.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<bool> isFavoriteArtwork(int artworkId) async {
    final favorites = await getFavoriteArtworkIds();
    return favorites.contains(artworkId);
  }

  static Future<bool> toggleFavoriteArtwork({
    required int artworkId,
    required String artworkTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteArtworkIds();
    final added = favorites.add(artworkId);

    if (!added) {
      favorites.remove(artworkId);
    }

    await prefs.setStringList(
      _favoriteArtworkIdsKey,
      favorites.map((id) => id.toString()).toList(),
    );

    if (added) {
      await addRecentActivity(type: 'favorite', artworkTitle: artworkTitle);
    } else {
      _notifyActivityChanged();
    }

    return added;
  }

  static Future<List<RecentActivity>> getRecentActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_recentActivitiesKey) ?? [];

    return rows
        .map((row) {
          try {
            return RecentActivity.fromJson(
              jsonDecode(row) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentActivity>()
        .toList();
  }

  static Future<void> addRecentActivity({
    required String type,
    required String artworkTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = await getRecentActivities();

    activities.insert(
      0,
      RecentActivity(
        type: type,
        artworkTitle: artworkTitle,
        createdAt: DateTime.now(),
      ),
    );

    final trimmed = activities.take(20).map((activity) {
      return jsonEncode(activity.toJson());
    }).toList();

    await prefs.setStringList(_recentActivitiesKey, trimmed);
    await AdminAnalyticsService.logEvent(
      type: type,
      artworkTitle: artworkTitle,
    );
    _notifyActivityChanged();
  }

  static void _notifyActivityChanged() {
    activityVersion.value++;
  }

  static void _notifyProfileChanged() {
    profileVersion.value++;
  }

  static String _emailKey(String email) {
    return email.trim().toLowerCase();
  }
}
