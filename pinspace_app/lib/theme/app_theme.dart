// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart'; // Import your custom colors

class AppTheme {
  // Define a light theme using the custom colors
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // Enable Material 3 features

      // Define the color scheme using your palette
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sulleyBlue, // Base color for generating scheme
        primary: AppColors.sulleyBlue,
        secondary: AppColors.mikeLime,
        tertiary: AppColors.sulleyBlue,
        brightness: Brightness.light, // Specify light theme
      ),

      scaffoldBackgroundColor: AppColors.white,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sulleyBlue, // Example AppBar color
        foregroundColor: AppColors.white, // Example AppBar text/icon color
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sulleyBlue, // Example Button color
          foregroundColor: AppColors.black, // Example Button text color
          minimumSize: const Size(350, 50), // width, height
        ),
      ),

      // ✅ DEFINE A CONSISTENT TEXT THEME
      textTheme: const TextTheme(
        // For "Welcome back, Palmetto_Cole!"
        headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.black87),
        // For card titles like "My Collection"
        titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        // For card subtitles like "11 Pins | 4 Sets"
        bodyMedium: TextStyle(fontSize: 14.0),
        // For labels on quick action buttons
        labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
      ),

      // Define input decoration themes, etc.
      // inputDecorationTheme: const InputDecorationTheme(...)
    );
  }

  // Optionally define a dark theme later
  // static ThemeData get darkTheme { ... }
}