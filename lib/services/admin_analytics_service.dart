import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminActivityEvent {
  final String type;
  final String artworkTitle;
  final String visitorName;
  final String visitorEmail;
  final String visitorId;
  final DateTime createdAt;

  const AdminActivityEvent({
    required this.type,
    required this.artworkTitle,
    required this.visitorName,
    required this.visitorEmail,
    required this.visitorId,
    required this.createdAt,
  });

  factory AdminActivityEvent.fromJson(Map<String, dynamic> json) {
    return AdminActivityEvent(
      type: json['type']?.toString() ??
          json['event_type']?.toString() ??
          'view',
      artworkTitle: json['artworkTitle']?.toString() ??
          json['artwork_title']?.toString() ??
          'Artwork',
      visitorName: json['visitorName']?.toString() ??
          json['visitor_name']?.toString() ??
          'Visitor',
      visitorEmail: json['visitorEmail']?.toString() ??
          json['visitor_email']?.toString() ??
          '',
      visitorId: json['visitorId']?.toString() ??
          json['visitor_id']?.toString() ??
          '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'artworkTitle': artworkTitle,
      'visitorName': visitorName,
      'visitorEmail': visitorEmail,
      'visitorId': visitorId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'event_type': type,
      'artwork_title': artworkTitle,
      'visitor_name': visitorName,
      'visitor_email': visitorEmail,
      'visitor_id': visitorId.isEmpty ? null : visitorId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AdminAnalyticsService {
  static const String _localEventsKey = 'admin_activity_events';

  static Future<void> logEvent({
    required String type,
    required String artworkTitle,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final event = AdminActivityEvent(
      type: type,
      artworkTitle: artworkTitle,
      visitorName: _displayNameForUser(user),
      visitorEmail: user?.email ?? '',
      visitorId: user?.id ?? '',
      createdAt: DateTime.now(),
    );

    await _storeLocalEvent(event);

    try {
      await Supabase.instance.client
          .from('admin_activity_events')
          .insert(event.toSupabaseJson());
    } catch (error) {
      debugPrint('Admin analytics Supabase logging skipped: $error');
    }
  }

  static Future<List<AdminActivityEvent>> fetchEvents() async {
    try {
      final response = await Supabase.instance.client
          .from('admin_activity_events')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      return (response as List)
          .map((row) => AdminActivityEvent.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Admin analytics Supabase fetch skipped: $error');
      return _localEvents();
    }
  }

  static Future<void> _storeLocalEvent(AdminActivityEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _localEvents();

    events.insert(0, event);

    await prefs.setStringList(
      _localEventsKey,
      events.take(250).map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<List<AdminActivityEvent>> _localEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_localEventsKey) ?? [];

    return rows
        .map((row) {
          try {
            return AdminActivityEvent.fromJson(
              jsonDecode(row) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AdminActivityEvent>()
        .toList();
  }

  static String _displayNameForUser(User? user) {
    final metadata = user?.userMetadata ?? {};
    final metadataName =
        metadata['full_name'] ??
        metadata['name'] ??
        metadata['display_name'] ??
        metadata['preferred_username'];

    if (metadataName != null && metadataName.toString().trim().isNotEmpty) {
      return metadataName.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    final email = user?.email;

    if (email != null && email.trim().isNotEmpty) {
      return email.split('@').first.replaceAll('.', ' ');
    }

    return 'Visitor';
  }
}
