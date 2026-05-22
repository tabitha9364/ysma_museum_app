import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_settings.dart';
import '../services/voice_navigation_service.dart';
import '../utils/colors.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textFor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    'Accessibility',
                    style: TextStyle(
                      color: AppColors.textFor(context),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              _toggleTile(
                Icons.volume_up,
                'Audio Narration',
                'Auto-play audio narration',
                settings.autoPlayAudio,
                (value) {
                  settings.toggleAutoPlay(value);
                },
              ),
              const SizedBox(height: 12),
              _toggleTile(
                Icons.dark_mode_outlined,
                'Light/Dark Mode',
                'Toggle for light or dark mode',
                settings.darkMode,
                (value) {
                  settings.toggleDarkMode(value);
                },
              ),
              const SizedBox(height: 12),
              _toggleTile(
                Icons.contrast,
                'High Contrast Mode',
                'Increase visual contrast',
                settings.highContrast,
                (value) {
                  settings.toggleContrast(value);
                },
              ),
              const SizedBox(height: 12),
              _toggleTile(
                Icons.mic_none,
                'Voice Navigation',
                'Navigate with voice commands',
                settings.voiceNavigation,
                (value) => _toggleVoiceNavigation(settings, value),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.text_fields,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Text Size',
                                style: TextStyle(
                                  color: AppColors.textFor(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Adjust display text size',
                                style: TextStyle(
                                  color: AppColors.mutedTextFor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(color: AppColors.textFor(context)),
                        ),
                        Expanded(
                          child: Slider(
                            value: settings.textScale,
                            activeColor: Colors.amber,
                            inactiveColor: AppColors.isDark(context)
                                ? Colors.white24
                                : Colors.black26,
                            onChanged: (value) {
                              settings.updateTextScale(value);
                            },
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            color: AppColors.textFor(context),
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardFor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'This is a sample text to preview your accessibility settings. Adjust the slider above to change text size.',
                    style: TextStyle(
                      color: AppColors.mutedTextFor(context),
                      fontSize: 14 + (settings.textScale * 10),
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

  void _toggleVoiceNavigation(AppSettings settings, bool value) {
    unawaited(settings.toggleVoiceNavigation(value));
    if (value) {
      unawaited(
        VoiceNavigationService.speak(
          context,
          'Voice navigation is enabled. Open the museum map and choose a destination to hear directions.',
        ),
      );
      return;
    }

    unawaited(VoiceNavigationService.stop());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice navigation disabled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _toggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textFor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.mutedTextFor(context),
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
