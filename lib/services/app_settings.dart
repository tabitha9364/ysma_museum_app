import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool autoPlayAudio = true;
  bool highContrast = false;

  void toggleAutoPlay(bool value) {
    autoPlayAudio = value;
    notifyListeners();
  }

  void toggleContrast(bool value) {
    highContrast = value;
    notifyListeners();
  }
}