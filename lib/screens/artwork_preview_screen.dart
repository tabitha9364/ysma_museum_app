import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/artwork.dart';
import '../services/user_preferences.dart';
import '../utils/colors.dart';
import 'artwork_detail_screen.dart';
import 'museum_map_screen.dart';

class ArtworkPreviewScreen extends StatefulWidget {
  final Artwork artwork;

  const ArtworkPreviewScreen({super.key, required this.artwork});

  @override
  State<ArtworkPreviewScreen> createState() => _ArtworkPreviewScreenState();
}

class _ArtworkPreviewScreenState extends State<ArtworkPreviewScreen> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    UserPreferences.addRecentActivity(
      type: 'view',
      artworkTitle: widget.artwork.title,
    );
  }

  Future<void> _loadFavoriteState() async {
    final favorite = await UserPreferences.isFavoriteArtwork(widget.artwork.id);

    if (!mounted) {
      return;
    }

    setState(() {
      isFavorite = favorite;
    });
  }

  Future<void> _toggleFavorite() async {
    final added = await UserPreferences.toggleFavoriteArtwork(
      artworkId: widget.artwork.id,
      artworkTitle: widget.artwork.title,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isFavorite = added;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added ${widget.artwork.title} to favourites.'
              : 'Removed ${widget.artwork.title} from favourites.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareArtwork() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${widget.artwork.title} by ${widget.artwork.artist}\n${widget.artwork.imageUrl}',
      ),
    );

    await UserPreferences.addRecentActivity(
      type: 'share',
      artworkTitle: widget.artwork.title,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Artwork details copied for sharing.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _locateArtwork() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuseumMapScreen(targetArtwork: widget.artwork),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;
    final panelColor = AppColors.cardFor(context);
    final textColor = AppColors.textFor(context);
    final mutedColor = AppColors.mutedTextFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: Stack(
        children: [
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: artwork.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.surfaceFor(context),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ),
              errorWidget: (context, url, error) {
                return Container(
                  color: AppColors.surfaceFor(context),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 50,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      'AR Result',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Share artwork',
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: _shareArtwork,
                          ),
                          IconButton(
                            tooltip: isFavorite
                                ? 'Remove from favourites'
                                : 'Add to favourites',
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.amber : Colors.white,
                            ),
                            onPressed: _toggleFavorite,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.isDark(context)
                            ? Colors.white24
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    artwork.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${artwork.artist} - ${artwork.year}',
                    style: TextStyle(color: mutedColor, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      artwork.location,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(Icons.volume_up, 'Play Audio', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtworkDetailScreen(
                                artwork: artwork,
                                initialTab: 1,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(Icons.menu_book, 'Read Info', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArtworkDetailScreen(
                                artwork: artwork,
                                initialTab: 0,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          Icons.map_outlined,
                          'Navigate',
                          _locateArtwork,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.isDark(context)
              ? Colors.white10
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Center(child: Icon(icon, color: Colors.amber, size: 28)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: AppColors.mutedTextFor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
