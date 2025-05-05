// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../widgets/animated_logo.dart'; // Import the logo animation
import '../theme/app_colors.dart';     // Import theme colors for indicator

// This screen is shown briefly while the app initializes (e.g., checking auth state).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack( // Use Stack to layer background, overlay, and content
        children: [
          // --- Background Image --- (Same as AuthPage/LoginPage)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/LoginScreenBackground.jpg'), // Path to your background
                fit: BoxFit.cover,
              ),
            ),
          ),

          // --- Optional Darkening Overlay ---
          // Keep this consistent with AuthPage/LoginPage or remove if not needed
          Container(
             color: Colors.black.withOpacity(0.4),
          ),

          // --- Centered Content (Logo + Loading Indicator) ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Size column to its content
              children: [
                // --- Animated Logo ---
                const AnimatedLogo(size: 350), // Use a suitable size for splash
                const SizedBox(height: 40), // Space between logo and indicator

                // --- Optional Loading Indicator ---
                const CircularProgressIndicator(
                  color: AppColors.white, // Use a contrasting color
                  strokeWidth: 2.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}