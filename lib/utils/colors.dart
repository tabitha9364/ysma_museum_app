import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_settings.dart';

class AppColors {
  static const Color background = Color(0xFF071A2F);
  static const Color surface = Color(0xFF0F2A44);
  static const Color card = Color(0xFF1E2F45);
  static const Color primary = Color(0xFFFFC107);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Colors.white54;

  static const Color lightBackground = Color(0xFFF4F5F7);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFE8EAED);
  static const Color lightText = Color(0xFF101418);
  static const Color lightTextGrey = Color(0xFF5F6872);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static bool isHighContrast(BuildContext context) {
    try {
      return context.watch<AppSettings>().highContrast;
    } catch (_) {
      return false;
    }
  }

  static Color backgroundFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? Colors.black : Colors.white;
    }

    return isDark(context) ? background : lightBackground;
  }

  static Color surfaceFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? const Color(0xFF101010) : Colors.white;
    }

    return isDark(context) ? surface : lightSurface;
  }

  static Color cardFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);
    }

    return isDark(context) ? card : lightCard;
  }

  static Color textFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? Colors.white : Colors.black;
    }

    return isDark(context) ? textWhite : lightText;
  }

  static Color mutedTextFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? Colors.white70 : Colors.black87;
    }

    return isDark(context) ? textGrey : lightTextGrey;
  }

  static Color subtleTextFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? Colors.white60 : Colors.black54;
    }

    return isDark(context) ? Colors.white38 : const Color(0xFF7C858E);
  }

  static Color panelGreyFor(BuildContext context) {
    if (isHighContrast(context)) {
      return isDark(context) ? const Color(0xFF252525) : const Color(0xFFECECEC);
    }

    return isDark(context) ? const Color(0xFF2E4056) : const Color(0xFFE5E7EB);
  }
}
