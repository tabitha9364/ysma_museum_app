import 'package:flutter/material.dart';
import '../models/artwork.dart';
import '../services/supabase_service.dart';
import 'artwork_preview_screen.dart';
import 'recommended_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

      // ✅ PRELOAD IMAGES
      for (var art in artworks) {
        precacheImage(
          NetworkImage(art.imageUrl),
          context,
        );
      }

    } catch (e) {
      debugPrint("Error loading artworks: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A2F),

      // ✅ FIXED BOTTOM NAV BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF0F2A44),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            // ✅ HOME BUTTON NOW WORKS
            GestureDetector(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
                  ),
                  (route) => false,
                );
              },

              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    "Home",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  )
                ],
              ),
            ),

            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.center_focus_strong, color: Colors.white54),
                SizedBox(height: 4),
                Text("Scan",
                    style: TextStyle(color: Colors.white54, fontSize: 12))
              ],
            ),

            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: Colors.white54),
                SizedBox(height: 4),
                Text("Map",
                    style: TextStyle(color: Colors.white54, fontSize: 12))
              ],
            ),

            // ✅ PROFILE BUTTON
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, color: Colors.white54),
                  SizedBox(height: 4),
                  Text("Profile",
                      style:
                          TextStyle(color: Colors.white54, fontSize: 12))
                ],
              ),
            ),
          ],
        ),
      ),

      // ✅ BODY (NOW PROPERLY CONNECTED)
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              const Text("Welcome back",
                  style: TextStyle(color: Colors.white54)),

              const SizedBox(height: 5),

              const Text("Hello, Dorcas",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              // SEARCH BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2A44),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.white54),
                    SizedBox(width: 10),
                    Text("Search artwork, galleries...",
                        style: TextStyle(color: Colors.white38)),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ACTION CARDS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanScreen(artworks: artworks),
                        ),
                      );
                    },
                    child: buildActionCard(
                      Icons.center_focus_strong,
                      "Scan\nArtwork",
                      Colors.amber,
                    ),
                  ),
                  buildActionCard(Icons.map_outlined,
                      "Navigate\nMuseum", Colors.blue),
                  buildActionCard(Icons.image_outlined,
                      "Explore\nArtworks", Colors.purple),
                ],
              ),

              const SizedBox(height: 30),

              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recommended for You",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),

                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const RecommendedScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Text("See All",
                            style:
                                TextStyle(color: Color(0xFFFFC107))),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward,
                            color: Color(0xFFFFC107), size: 16),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ARTWORK LIST
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.amber),
                      )
                    : artworks.isEmpty
                        ? const Center(
                            child: Text("No artworks found",
                                style:
                                    TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: artworks.length,
                            itemBuilder: (context, index) {
                              final art = artworks[index];
                              return buildArtwork(context, art);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ACTION CARD
  Widget buildActionCard(
      IconData icon, String text, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // ARTWORK CARD
  Widget buildArtwork(
      BuildContext context, Artwork artwork) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ArtworkPreviewScreen(artwork: artwork),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: artwork.imageUrl,
                height: 100,
                width: 120,
                fit: BoxFit.cover,

                placeholder: (context, url) => Container(
                  height: 100,
                  width: 120,
                  color: const Color(0xFF1E2F45),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 2,
                    ),
                  ),
                ),

                errorWidget: (context, url, error) => Container(
                  height: 100,
                  width: 120,
                  color: const Color(0xFF1E2F45),
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(artwork.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12)),

            Text(artwork.artist,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}