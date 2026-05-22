import 'package:flutter/material.dart';
import '../models/artwork.dart';
import '../services/supabase_service.dart';
import 'artwork_preview_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecommendedScreen extends StatefulWidget {
  const RecommendedScreen({super.key});

  @override
  State<RecommendedScreen> createState() => _RecommendedScreenState();
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  List<Artwork> artworks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadArtworks();
  }

  Future<void> loadArtworks() async {
    try {
      final data = await SupabaseService.fetchArtworks();

      setState(() {
        artworks = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A2F),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 10),

              // 🔙 BACK + TITLE
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),

                    child: Container(
                      padding: const EdgeInsets.all(10),

                      decoration: const BoxDecoration(
                        color: Color(0xFF0F2A44),
                        shape: BoxShape.circle,
                      ),

                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Recommended for You",

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Personalized picks",

                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 🔲 GRID
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    : artworks.isEmpty
                    ? const Center(
                        child: Text(
                          "No artworks found",

                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : GridView.builder(
                        itemCount: artworks.length,

                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 0.75,
                            ),

                        itemBuilder: (context, index) {
                          final art = artworks[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                      ArtworkPreviewScreen(artwork: art),
                                ),
                              );
                            },

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                // IMAGE CARD
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),

                                    child: CachedNetworkImage(
                                      imageUrl: art.imageUrl,

                                      fit: BoxFit.cover,

                                      placeholder: (context, url) => Container(
                                        color: const Color(0xFF1E2F45),

                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),

                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: const Color(0xFF1E2F45),

                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.white54,
                                            ),
                                          ),

                                      imageBuilder: (context, imageProvider) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            image: DecorationImage(
                                              image: imageProvider,

                                              fit: BoxFit.cover,
                                            ),
                                          ),

                                          child: Stack(
                                            children: [
                                              // GRADIENT
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.transparent,

                                                        Colors.black.withValues(
                                                          alpha: 0.6,
                                                        ),
                                                      ],

                                                      begin:
                                                          Alignment.topCenter,

                                                      end: Alignment
                                                          .bottomCenter,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // TAG
                                              Positioned(
                                                bottom: 10,
                                                left: 10,

                                                child: Text(
                                                  art.tag,

                                                  style: const TextStyle(
                                                    color: Color(0xFFFFC107),

                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // TITLE
                                Text(
                                  art.title,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    color: Colors.white,

                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  art.artist,

                                  style: const TextStyle(
                                    color: Colors.white54,

                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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
}
