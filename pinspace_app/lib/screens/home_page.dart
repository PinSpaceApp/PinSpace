// lib/screens/home_page.dart
import 'package:flutter/material.dart';

// A simple placeholder widget for the main screen after login.
class HomePage extends StatelessWidget {
  // Constructor for the HomePage widget.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Builds the basic UI structure for the home page.
    return Scaffold(
      // AppBar at the top of the screen.
      appBar: AppBar(
        title: const Text('PinSpace Home'), // Title displayed in the AppBar.
        // TODO: Add actions like logout, profile button later.
      ),
      // Main content area of the screen.
      body: const Center(
        // Centers the content horizontally and vertically.
        child: Text('Welcome! You are logged in.'), // Placeholder text.
        // TODO: Replace this with the actual home screen content (dashboard, feed, etc.).
      ),
    );
  }
}