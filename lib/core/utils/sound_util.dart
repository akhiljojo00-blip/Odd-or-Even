import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundUtil {
  static bool enabled = true;

  static void playTap() {
    if (!enabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Sound playTap error: $e');
    }
  }

  static void playSubmit() {
    if (!enabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  static void playScore() {
    if (!enabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  static void playWicket() {
    if (!enabled) return;
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
