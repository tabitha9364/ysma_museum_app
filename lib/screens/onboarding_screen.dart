import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController _controller = PageController();
  int currentIndex = 0;

  List<Map<String, dynamic>> pages = [
    {
      "title": "Scan Artworks with AR",
      "subtitle": "Dive deeper and discover hidden stories",
      "image": "assets/images/scan.png"
    },
    {
      "title": "Navigate the museum easily",
      "subtitle": "Find artworks instantly",
      "image": "assets/images/map.png"
    },
  ];

  void nextPage() {
    if (currentIndex < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1E33),
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: pages.length,
          onPageChanged: (index) {
            setState(() => currentIndex = index);
          },
          itemBuilder: (context, index) {
            return buildOnboardingPage(pages[index]);
          },
        ),
      ),
    );
  }

  Widget buildOnboardingPage(Map page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          // 🔝 TOP SECTION
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Progress bars (2 pages)
              Row(
                children: List.generate(2, (index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? const Color(0xFFFFC107)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 30),

              // Title with AR highlight
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(
                      text: page["title"].replaceAll("AR", ""),
                    ),
                    if (page["title"].contains("AR"))
                      const TextSpan(
                        text: "AR",
                        style: TextStyle(color: Color(0xFFFFC107)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Text(
                page["subtitle"],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // 🖼 IMAGE CARD
          Center(
            child: Container(
              height: 260,
              width: 260,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF162C46),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                page["image"],
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 🔘 BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Next",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
