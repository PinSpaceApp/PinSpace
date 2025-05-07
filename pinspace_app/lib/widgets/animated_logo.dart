// lib/widgets/animated_logo.dart
import 'package:flutter/material.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;
  // Constructor allows specifying size, defaults to 150
  const AnimatedLogo({super.key, this.size = 150.0});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

// Uses SingleTickerProviderStateMixin for the AnimationController
class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Animation controller setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // How long the animation takes
    );

    // Define the scale animation (grows from 0 to 1 with a bounce)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut, // Creates a nice overshoot/bounce effect
      ),
    );

    // Define the fade animation (fades from 0 to 1)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        // Fade in during the first 60% of the animation duration
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Start the animation automatically when the widget is first built
    _controller.forward();
  }

  @override
  void dispose() {
    // Important: dispose the controller when the widget is removed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Combine Scale and Fade transitions for a smooth effect
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SizedBox(
          height: widget.size, // Use the size passed to the widget
          width: widget.size,
          child: Image.asset(
            // Make sure this path matches your pubspec.yaml and file location
            'assets/images/Logo.png',
            // Optional: Add semantic label for accessibility
            semanticLabel: 'PinSpace Logo',
            // Optional: Add error builder if image fails to load
            errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.error, size: widget.size),
          ),
        ),
      ),
    );
  }
}