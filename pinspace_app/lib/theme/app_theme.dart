// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart'; // Import your custom colors

class AppTheme {
  // Define a light theme using the custom colors
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // Enable Material 3 features

      // Define the color scheme using your palette
      // You decide which color plays which role!
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sulleyBlue, // Base color for generating scheme
        primary: AppColors.sulleyBlue,
        secondary: AppColors.mikeLime,
        tertiary: AppColors.booPurple,
        // You can override other colors too:
        // background: AppColors.white,
        // error: Colors.red,
        // surface: AppColors.white,
        // onPrimary: AppColors.white,
        // onSecondary: AppColors.black,
        // ... etc.
        brightness: Brightness.light, // Specify light theme
      ),

      // You can customize other theme aspects too:
      scaffoldBackgroundColor: AppColors.white, // Example

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

      // Define text themes if needed
      // textTheme: const TextTheme(...)

      // Define input decoration themes, etc.
      // inputDecorationTheme: const InputDecorationTheme(...)
    );
  }

  // Optionally define a dark theme later
  // static ThemeData get darkTheme { ... }
}