import 'package:flutter/material.dart';
import 'accessibility_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A2F),

      body: SafeArea(
        child: SingleChildScrollView( // ✅ prevents overflow
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 🔷 PROFILE CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2F45),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Row(
                  children: [

                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "DE",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    // Name + role
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dorcas Elijah",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Museum Visitor",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                    // ⚙️ SETTINGS BUTTON (WORKING)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccessibilityScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 🔷 TITLE
              const Text(
                "Today’s Journey",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              // 🔷 STATS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCard(Icons.remove_red_eye, Colors.blue, "24", "Artworks\nViewed"),
                  _statCard(Icons.history, Colors.green, "1h 42m", "Time spent"),
                  _statCard(Icons.favorite, Colors.pink, "8", "Favourites"),
                ],
              ),

              const SizedBox(height: 25),

              // 🔷 RECENT ACTIVITY TITLE
              const Text(
                "Recent Activity",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              // 🔷 ACTIVITY LIST
              _activityTile(Icons.masks_outlined, "Scanned Persian Mask", "18 mins ago"),
              const SizedBox(height: 10),
              _activityTile(Icons.favorite, "Added Bronze Head to favourites", "12 mins ago"),
              const SizedBox(height: 10),
              _activityTile(Icons.account_balance, "Started Museum tour", "10 mins ago"),
            ],
          ),
        ),
      ),

      // 🔻 NAV BAR (PROFILE ACTIVE)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: const Color(0xFF0F2A44),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            // ✅ HOME BUTTON NOW WORKS
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: _navItem(Icons.home_outlined, "Home", false),
            ),

            _navItem(Icons.center_focus_strong, "Scan", false),
            _navItem(Icons.map_outlined, "Map", false),
            _navItem(Icons.person, "Profile", true),
          ],
        ),
      ),
    );
  }

  // 🔷 NAV ITEM
  Widget _navItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: null,
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // 🔷 STAT CARD
  static Widget _statCard(
      IconData icon, Color color, String value, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2F45),
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 🔷 ACTIVITY TILE
  static Widget _activityTile(
      IconData icon, String title, String time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2F45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white)),
              Text(time,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}