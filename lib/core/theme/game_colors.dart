import 'package:flutter/material.dart';

class GameColors {
  // Deep arcade royal indigo & purple atmosphere
  static const Color background = Color(0xFF0F081E);
  static const Color backgroundDeep = Color(0xFF090412);
  static const Color surface = Color(0xFF1B1033);
  static const Color surfaceElevated = Color(0xFF2B194F);
  static const Color glassSurface = Color(0x26FFFFFF);
  static const Color glassBorder = Color(0x33A855F7);
  static const Color cardBorder = Color(0x40C084FC);

  // Vibrant arcade sport palette
  static const Color royalPurple = Color(0xFF3B0764);
  static const Color deepIndigo = Color(0xFF1E1B4B);
  static const Color electricViolet = Color(0xFF8B5CF6);
  static const Color violetNeon = Color(0xFFA855F7);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanBright = Color(0xFF22D3EE);
  static const Color emerald = Color(0xFF10B981);
  static const Color mint = Color(0xFF34D399);
  static const Color lime = Color(0xFF84CC16);
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldBright = Color(0xFFFBBF24);
  static const Color goldMetallic = Color(0xFFFFD700);
  static const Color orange = Color(0xFFF97316);
  static const Color coral = Color(0xFFF43F5E);
  static const Color wicket = Color(0xFFEF4444);
  static const Color amber = Color(0xFFFBBF24);

  // Player identity
  static const Color player1 = Color(0xFF8B5CF6); // Electric Violet
  static const Color player1Light = Color(0xFFA78BFA);
  static const Color player2 = Color(0xFF06B6D4); // Neon Cyan
  static const Color player2Light = Color(0xFF67E8F9);

  // Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // Premium arcade gradients
  static const LinearGradient arcadeBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E0A3C), Color(0xFF0C0519), Color(0xFF07030E)],
  );

  static const LinearGradient cardGradientPassPlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF0D9488)],
  );

  static const LinearGradient cardGradientOnline = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF4F46E5)],
  );

  static const LinearGradient cardGradientQuickMatch = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFD97706)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF261545), Color(0xFF170C2E)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
  );

  static const LinearGradient violetCyanGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
  );

  static const LinearGradient wicketGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFF43F5E)],
  );
}
