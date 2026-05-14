import 'package:flutter/material.dart';
import '../models/artwork.dart';
import 'artwork_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtworkPreviewScreen extends StatelessWidget {
  final Artwork artwork;

  const ArtworkPreviewScreen({
    super.key,
    required this.artwork,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        children: [

          // FULL IMAGE
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: artwork.imageUrl,
              fit: BoxFit.cover,

              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                  ),
                ),
              ),

              errorWidget: (context, url, error) {
                return Container(
                  color: Colors.grey.shade900,
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

          // TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const Text(
                    "AR Result",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM CARD
          Align(
            alignment: Alignment.bottomCenter,

            child: Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Color(0xFF1E2F45),

                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  // DRAG LINE
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,

                      margin: const EdgeInsets.only(bottom: 10),

                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // TITLE
                  Text(
                    artwork.title,

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ARTIST + YEAR
                  Text(
                    "${artwork.artist} · ${artwork.year}",

                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // LOCATION
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
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

                  const SizedBox(height: 16),

                  const SizedBox(height: 20),

                  // ACTION BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [

                      // PLAY AUDIO
                      _actionButton(
                        Icons.volume_up,
                        "Play Audio",
                        () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => ArtworkDetailScreen(
                                artwork: artwork,

                                // OPENS AUDIO TAB DIRECTLY
                                initialTab: 1,
                              ),
                            ),
                          );
                        },
                      ),

                      // READ INFO
                      _actionButton(
                        Icons.menu_book,
                        "Read Info",
                        () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => ArtworkDetailScreen(
                                artwork: artwork,
                                initialTab: 0,
                              ),
                            ),
                          );
                        },
                      ),

                      // VIEW AR
                      _actionButton(
                        Icons.view_in_ar,
                        "View AR",
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("AR feature coming soon"),
                            ),
                          );
                        },
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

  Widget _actionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 100,

        padding: const EdgeInsets.symmetric(vertical: 15),

        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(15),
        ),

        child: Column(
          children: [

            Icon(
              icon,
              color: Colors.amber,
              size: 28,
            ),

            const SizedBox(height: 6),

            Text(
              label,

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}