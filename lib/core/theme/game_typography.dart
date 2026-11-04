import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game_colors.dart';

class GameTypography {
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: GameColors.textPrimary,
        letterSpacing: 1.2,
      );

  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: GameColors.textPrimary,
        letterSpacing: 0.8,
      );

  static TextStyle get headlineLarge => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: GameColors.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: GameColors.textPrimary,
      );

  static TextStyle get scoreNumber => GoogleFonts.spaceGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: GameColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: GameColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: GameColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: GameColors.textMuted,
        letterSpacing: 0.5,
      );
}
