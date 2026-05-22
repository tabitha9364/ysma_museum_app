import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/user_preferences.dart';
import '../utils/colors.dart';
import 'accessibility_screen.dart';
import 'museum_map_screen.dart';
import 'scan_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<RecentActivity> recentActivities = [];
  int favouriteCount = 0;
  bool openingScanner = false;

  @override
  void initState() {
    super.initState();
    UserPreferences.activityVersion.addListener(_handleActivityChanged);
    _loadProfileActivity();
  }

  @override
  void dispose() {
    UserPreferences.activityVersion.removeListener(_handleActivityChanged);
    super.dispose();
  }

  void _handleActivityChanged() {
    _loadProfileActivity();
  }

  Future<void> _loadProfileActivity() async {
    final activities = await UserPreferences.getRecentActivities();
    final favourites = await UserPreferences.getFavoriteArtworkIds();

    if (!mounted) {
      return;
    }

    setState(() {
      recentActivities = activities;
      favouriteCount = favourites.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.supabase.auth.currentUser;
    final displayName =
    user?.userMetadata?['full_name'] ??
    user?.userMetadata?['name'] ??
    UserPreferences.getCurrentUserFirstName();
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProfileActivity,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardFor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            _initials(displayName),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textFor(context),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email.isEmpty ? 'Museum Visitor' : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.mutedTextFor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccessibilityScreen(),
                            ),
                          );

                          _loadProfileActivity();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context)
                                ? Colors.white10
                                : Colors.black12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.settings,
                            color: AppColors.mutedTextFor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Today's Journey",
                  style: TextStyle(
                    color: AppColors.textFor(context),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        Icons.remove_red_eye,
                        Colors.blue,
                        _countActivities('view').toString(),
                        'Artworks\nViewed',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        Icons.share,
                        Colors.green,
                        _countActivities('share').toString(),
                        'Shares',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        Icons.favorite,
                        Colors.pink,
                        favouriteCount.toString(),
                        'Favourites',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: AppColors.textFor(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                if (recentActivities.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.cardFor(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'No recent activity yet.',
                      style: TextStyle(color: AppColors.mutedTextFor(context)),
                    ),
                  )
                else
                  ...recentActivities
                      .take(10)
                      .map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _activityTile(activity),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: AppColors.surfaceFor(context),
        child: Row(
          children: [
            _navItem(
              Icons.home_outlined,
              'Home',
              false,
              () => Navigator.pop(context),
            ),
            _navItem(
              Icons.center_focus_strong,
              'Scan',
              false,
              openingScanner ? null : _openScannerFromProfile,
            ),
            _navItem(Icons.map_outlined, 'Map', false, _openMapFromProfile),
            _navItem(Icons.person, 'Profile', true, null),
          ],
        ),
      ),
    );
  }

  int _countActivities(String type) {
    return recentActivities.where((activity) => activity.type == type).length;
  }

  Future<void> _openScannerFromProfile() async {
    setState(() {
      openingScanner = true;
    });

    try {
      final artworks = await SupabaseService.fetchArtworks();

      if (!mounted) {
        return;
      }

      if (artworks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artwork data could not be loaded.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScanScreen(artworks: artworks)),
      );

      _loadProfileActivity();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open scanner: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          openingScanner = false;
        });
      }
    }
  }

  void _openMapFromProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MuseumMapScreen()),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback? onTap,
  ) {
    final color = active
        ? AppColors.textFor(context)
        : AppColors.mutedTextFor(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Container(
      height: 154,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textFor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedTextFor(context),
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(RecentActivity activity) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            _activityIcon(activity.type),
            color: _activityColor(activity.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityTitle(activity),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textFor(context)),
                ),
                Text(
                  _timeAgo(activity.createdAt),
                  style: TextStyle(
                    color: AppColors.mutedTextFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'favorite':
        return Icons.favorite;
      case 'share':
        return Icons.share;
      default:
        return Icons.remove_red_eye;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'favorite':
        return Colors.pink;
      case 'share':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _activityTitle(RecentActivity activity) {
    switch (activity.type) {
      case 'favorite':
        return 'Added ${activity.artworkTitle} to favourites';
      case 'share':
        return 'Shared ${activity.artworkTitle}';
      default:
        return 'Viewed ${activity.artworkTitle}';
    }
  }

  String _timeAgo(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    }

    return '${difference.inDays} days ago';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'V';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}
