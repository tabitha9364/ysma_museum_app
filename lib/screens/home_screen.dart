import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/artwork.dart';
import '../services/supabase_service.dart';
import '../services/user_preferences.dart';
import '../utils/colors.dart';
import 'artwork_spotlight_screen.dart';
import 'artwork_preview_screen.dart';
import 'museum_map_screen.dart';
import 'profile_screen.dart';
import 'recommended_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();

  List<Artwork> artworks = [];
  bool isLoading = true;
  String searchQuery = '';

  List<Artwork> get displayedArtworks {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return artworks;
    }

    return artworks.where((artwork) {
      return artwork.title.toLowerCase().contains(query) ||
          artwork.artist.toLowerCase().contains(query) ||
          artwork.tag.toLowerCase().contains(query) ||
          artwork.location.toLowerCase().contains(query) ||
          artwork.year.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    UserPreferences.profileVersion.addListener(_handleProfileChanged);
    loadArtworks();
  }

  @override
  void dispose() {
    UserPreferences.profileVersion.removeListener(_handleProfileChanged);
    searchController.dispose();
    super.dispose();
  }

  void _handleProfileChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> loadArtworks() async {
    try {
      final data = await SupabaseService.fetchArtworks();
      final ordered = data.toList()
        ..sort((a, b) {
          final priority = _homePriority(a).compareTo(_homePriority(b));
          if (priority != 0) {
            return priority;
          }

          return a.id.compareTo(b.id);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        artworks = ordered;
        isLoading = false;
      });

      debugPrint('Loaded ${artworks.length} artworks from Supabase');

      for (final artwork in artworks) {
        precacheImage(NetworkImage(artwork.imageUrl), context);
      }
    } catch (error) {
      debugPrint('Error loading artworks: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  void _openScanner() {
    if (isLoading) {
      _showMessage('Artwork data is still loading. Try again in a moment.');
      return;
    }

    if (artworks.isEmpty) {
      _showMessage('Artwork data could not be loaded. Check your connection.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(artworks: artworks)),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MuseumMapScreen()),
    );
  }

  void _openSpotlight() {
    if (isLoading) {
      _showMessage('Artwork data is still loading. Try again in a moment.');
      return;
    }

    if (artworks.isEmpty) {
      _showMessage('Artwork data could not be loaded. Check your connection.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtworkSpotlightScreen(artworks: artworks),
      ),
    );
  }

  int _homePriority(Artwork artwork) {
    final title = _homeKey(artwork.title);

    if (title == 'themansmind') {
      return 0;
    }

    if (title == 'senseofduty') {
      return 1;
    }

    return 2;
  }

  String _homeKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleArtworks = displayedArtworks;
    final background = AppColors.backgroundFor(context);
    final surface = AppColors.surfaceFor(context);
    final text = AppColors.textFor(context);
    final mutedText = AppColors.mutedTextFor(context);
    final displayName = UserPreferences.getCurrentUserFirstName();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: surface),
        child: Row(
          children: [
            _navItem(Icons.home, 'Home', true, () {}),
            _navItem(Icons.center_focus_strong, 'Scan', false, _openScanner),
            _navItem(Icons.map_outlined, 'Map', false, _openMap),
            _navItem(Icons.person_outline, 'Profile', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            }),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Welcome back', style: TextStyle(color: mutedText)),
              const SizedBox(height: 5),
              Text(
                'Hello, $displayName \u{1F44B}',
                style: TextStyle(
                  color: text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _searchBar(),
              SizedBox(height: keyboardOpen ? 18 : 25),
              if (!keyboardOpen) ...[
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        Icons.center_focus_strong,
                        'Scan\nArtwork',
                        Colors.amber,
                        _openScanner,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionCard(
                        Icons.map_outlined,
                        'Navigate\nMuseum',
                        Colors.blue,
                        _openMap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionCard(
                        Icons.image_outlined,
                        'Artwork\nSpotlight',
                        Colors.purple,
                        _openSpotlight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    searchQuery.trim().isEmpty
                        ? 'Recommended for You'
                        : 'Search Results',
                    style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  ),
                  if (searchQuery.trim().isEmpty)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecommendedScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(color: AppColors.primary),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    : visibleArtworks.isEmpty
                    ? Center(
                        child: Text(
                          searchQuery.trim().isEmpty
                              ? 'No artworks found'
                              : 'No artworks match "$searchQuery"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedText),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: visibleArtworks.length,
                            itemBuilder: (context, index) {
                              return _artworkCard(
                                visibleArtworks[index],
                                constraints.maxHeight,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        style: TextStyle(color: AppColors.textFor(context)),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Search artwork, artists...',
          hintStyle: TextStyle(color: AppColors.subtleTextFor(context)),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.mutedTextFor(context),
          ),
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close,
                    color: AppColors.mutedTextFor(context),
                  ),
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
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

  Widget _actionCard(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFor(context), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artworkCard(Artwork artwork, double availableHeight) {
    final safeHeight = availableHeight.isFinite ? availableHeight : 420.0;
    final showDetails = safeHeight >= 145;
    final rawImageHeight = showDetails ? safeHeight - 48 : safeHeight;
    final imageHeight = rawImageHeight.clamp(1.0, 420.0).toDouble();
    final cardWidth = (imageHeight * 0.72).clamp(96.0, 260.0).toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtworkPreviewScreen(artwork: artwork),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: artwork.imageUrl,
                height: imageHeight,
                width: cardWidth,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: imageHeight,
                  width: cardWidth,
                  color: AppColors.cardFor(context),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: imageHeight,
                  width: cardWidth,
                  color: AppColors.cardFor(context),
                  child: Icon(
                    Icons.broken_image,
                    color: AppColors.mutedTextFor(context),
                  ),
                ),
              ),
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                artwork.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textFor(context),
                  fontSize: 12,
                ),
              ),
              Text(
                artwork.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedTextFor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
