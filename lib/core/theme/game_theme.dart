import 'package:flutter/material.dart';
import 'game_colors.dart';

class GameTheme {
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameColors.background,
        colorScheme: const ColorScheme.dark(
          primary: GameColors.lime,
          secondary: GameColors.emerald,
          surface: GameColors.surface,
          error: GameColors.wicket,
        ),
        cardTheme: CardThemeData(
          color: GameColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: GameColors.glassBorder, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.lime,
            foregroundColor: GameColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
