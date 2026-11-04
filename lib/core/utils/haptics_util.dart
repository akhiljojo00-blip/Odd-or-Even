import 'package:flutter/services.dart';

class HapticsUtil {
  static bool enabled = true;

  static void lightTap() {
    if (!enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void mediumTap() {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void heavyWicket() {
    if (!enabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static void heavyImpact() {
    heavyWicket();
  }

  static void victoryVibrate() {
    if (!enabled) return;
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
