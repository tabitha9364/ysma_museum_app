import 'package:flutter/material.dart';

import '../services/user_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<Map<String, dynamic>> pages = [
    {
      "title": "Scan Artworks with AR",
      "subtitle": "Dive deeper and discover hidden stories",
      "image": "assets/images/scan.png",
    },
    {
      "title": "Navigate the museum easily",
      "subtitle": "Find artworks instantly",
      "image": "assets/images/map.png",
    },
  ];

  Future<void> nextPage() async {
    if (currentIndex < pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      return;
    }

    await UserPreferences.setOnboardingComplete(true);

    if (!mounted) {
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Widget buildOnboardingPage(Map<String, dynamic> page) {
    final isFirstPage = page["image"] == "assets/images/scan.png";

    return Stack(
      children: [
        if (isFirstPage)
          Positioned.fill(
            child: Opacity(
              opacity: 0.48,
              child: Image.asset(
                page["image"] as String,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        if (isFirstPage)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A1E33).withValues(alpha: 0.34),
                    const Color(0xFF0A1E33).withValues(alpha: 0.58),
                    const Color(0xFF0A1E33).withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: (page["title"] as String).replaceAll("AR", ""),
                        ),
                        if ((page["title"] as String).contains("AR"))
                          const TextSpan(
                            text: "AR",
                            style: TextStyle(color: Color(0xFFFFC107)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    page["subtitle"] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              if (isFirstPage)
                const Spacer()
              else
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
                      page["image"] as String,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              Center(
                child: SizedBox(
                  width: 238,
                  child: ElevatedButton(
                    onPressed: nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
