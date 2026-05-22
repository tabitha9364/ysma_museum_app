import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode';
  static const String _autoPlayAudioKey = 'auto_play_audio';
  static const String _highContrastKey = 'high_contrast';
  static const String _textScaleKey = 'text_scale';
  static const String _voiceNavigationKey = 'voice_navigation';

  bool autoPlayAudio = true;
  bool highContrast = false;
  bool darkMode = true;
  bool voiceNavigation = false;
  double textScale = 0.5;

  AppSettings() {
    _load();
  }

  ThemeMode get themeMode => darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(_darkModeKey) ?? true;
    autoPlayAudio = prefs.getBool(_autoPlayAudioKey) ?? true;
    highContrast = prefs.getBool(_highContrastKey) ?? false;
    voiceNavigation = prefs.getBool(_voiceNavigationKey) ?? false;
    textScale = prefs.getDouble(_textScaleKey) ?? 0.5;
    notifyListeners();
  }

  Future<void> toggleAutoPlay(bool value) async {
    autoPlayAudio = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayAudioKey, value);
  }

  Future<void> toggleContrast(bool value) async {
    highContrast = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, value);
  }

  Future<void> toggleVoiceNavigation(bool value) async {
    voiceNavigation = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceNavigationKey, value);
  }

  Future<void> toggleDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> updateTextScale(double value) async {
    textScale = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, value);
  }
}
