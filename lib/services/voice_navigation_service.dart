import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

class VoiceNavigationService {
  static const MethodChannel _channel = MethodChannel(
    'ysma_museum_app/voice_navigation',
  );

  static Future<void> warmUp() async {
    try {
      await _channel.invokeMethod<void>('warmUp');
    } catch (error) {
      debugPrint('Warming voice navigation failed: $error');
    }
  }

  static Future<bool> speak(BuildContext context, String text) async {
    final textDirection = Directionality.of(context);
    final view = View.of(context);

    unawaited(HapticFeedback.selectionClick());

    try {
      final spoken = await _channel.invokeMethod<bool>('speak', {'text': text});

      if (spoken == true) {
        return true;
      }
    } catch (error) {
      debugPrint('Native voice navigation failed: $error');
    }

    await SemanticsService.sendAnnouncement(view, text, textDirection);
    return false;
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (error) {
      debugPrint('Stopping voice navigation failed: $error');
    }
  }
}
