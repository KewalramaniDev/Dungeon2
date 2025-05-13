import 'package:flutter/material.dart';

class DungeonColors {
  // Primary colors
  static const background = Color(0xFF0F0F23);
  static const surface = Color(0xFF1A1A2E);
  static const primary = Color(0xFF6A0DAD); // Purple
  static const secondary = Color(0xFFFFA500); // Amber/Orange

  // Text colors
  static const textPrimary = Color(0xFFFFD700); // Golden
  static const textSecondary = Color(0xFFDDDDFF); // Light blue-white

  // Accent colors
  static const torch = Color(0xFFFF9933); // Torch flame
  static const torchGlow = Color(0xFFFFAA33); // Torch glow
  static const dungeonWall = Color(0xFF232342); // Wall color
  static const dungeonFloor = Color(0xFF1A1A2E); // Floor color
}

class DungeonTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: DungeonColors.primary,
        secondary: DungeonColors.secondary,
        background: DungeonColors.background,
        surface: DungeonColors.surface,
      ),
      scaffoldBackgroundColor: DungeonColors.background,
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all(DungeonColors.textPrimary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DungeonColors.surface,
          foregroundColor: DungeonColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: DungeonColors.secondary, width: 2),
          ),
        ),
      ),
    );
  }
}