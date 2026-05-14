import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_settings.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() =>
      _AccessibilityScreenState();
}

class _AccessibilityScreenState
    extends State<AccessibilityScreen> {

  bool voiceNavigation = false; // stays local
  double textSize = 0.5;

  @override
  Widget build(BuildContext context) {

    // 🔥 GLOBAL SETTINGS ACCESS
    final settings = Provider.of<AppSettings>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF071A2F),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

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
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 15),

                  const Text(
                    "Accessibility",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // 🎧 AUTO PLAY AUDIO (GLOBAL)
              _toggleTile(
                Icons.volume_up,
                "Audio Narration",
                "Auto-play audio guides",
                settings.autoPlayAudio,
                (v) => settings.toggleAutoPlay(v),
              ),

              const SizedBox(height: 12),

              // 🌗 HIGH CONTRAST (GLOBAL)
              _toggleTile(
                Icons.wb_sunny_outlined,
                "High Contrast Mode",
                "Increase visual contrast",
                settings.highContrast,
                (v) => settings.toggleContrast(v),
              ),

              const SizedBox(height: 12),

              // 🎤 VOICE NAV (LOCAL)
              _toggleTile(
                Icons.mic_none,
                "Voice Navigation",
                "Navigate with voice commands",
                voiceNavigation,
                (v) {
                  setState(() {
                    voiceNavigation = v;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 🔠 TEXT SIZE
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2F45),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(
                      children: [

                        Container(
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber
                                .withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(
                                    12),
                          ),
                          child: const Icon(
                            Icons.text_fields,
                            color: Colors.amber,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Text Size",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Adjust display text size",
                              style: TextStyle(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [

                        const Text(
                          "A",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),

                        Expanded(
                          child: Slider(
                            value: textSize,
                            activeColor: Colors.amber,
                            inactiveColor:
                                Colors.white24,

                            onChanged: (v) {
                              setState(() {
                                textSize = v;
                              });
                            },
                          ),
                        ),

                        const Text(
                          "A",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // 🔍 PREVIEW
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2F45),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),

                  child: Text(
                    "This is a sample text to preview your accessibility settings. Adjust the slider above to change text size.",

                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14 + (textSize * 10),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 REUSABLE TILE
  Widget _toggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF1E2F45),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        children: [

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.amber),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            activeThumbColor: Colors.amber,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}