// lib/widgets/twinkling_background.dart
import 'package:flutter/material.dart';
import 'dart:math'; // For random positions

class TwinklingBackground extends StatefulWidget {
  const TwinklingBackground({super.key});

  @override
  State<TwinklingBackground> createState() => _TwinklingBackgroundState();
}

class _TwinklingBackgroundState extends State<TwinklingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // List to hold properties for each twinkle
  final List<_Twinkle> _twinkles = [];
  final int _numberOfTwinkles = 30; // Adjust for density
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Long duration for slow twinkle
    )..repeat(); // Loop indefinitely

    // Create random properties for each twinkle
    for (int i = 0; i < _numberOfTwinkles; i++) {
      _twinkles.add(_Twinkle(
        // Random position within the screen (normalized 0.0-1.0)
        left: _random.nextDouble(),
        top: _random.nextDouble(),
        // Random size
        size: _random.nextDouble() * 3.0 + 1.0, // Size between 1.0 and 4.0
        // Random start/end points within the animation duration for fading
        fadeInStart: _random.nextDouble() * 0.4, // Start fading in somewhere in first 40%
        fadeInEnd: 0.5 + _random.nextDouble() * 0.5, // Finish fading in somewhere in last 50%
        // Random max opacity
        maxOpacity: _random.nextDouble() * 0.5 + 0.2, // Opacity between 0.2 and 0.7
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- Original Background Image ---
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('images/LoginScreenBackground.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // --- Optional Darkening Overlay ---
        // Keep or remove based on your preference
        Container(
           color: Colors.black.withOpacity(0.4),
        ),

        // --- Twinkles Layer ---
        // Use LayoutBuilder to get screen dimensions for positioning
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: _twinkles.map((twinkle) {
                // Create a fade animation for each twinkle based on its random intervals
                final fadeAnimation = TweenSequence<double>([
                  TweenSequenceItem(tween: Tween(begin: 0.0, end: twinkle.maxOpacity), weight: (twinkle.fadeInEnd - twinkle.fadeInStart) * 100), // Fade In
                  TweenSequenceItem(tween: Tween(begin: twinkle.maxOpacity, end: twinkle.maxOpacity), weight: (1.0 - twinkle.fadeInEnd) * 100), // Hold
                  TweenSequenceItem(tween: Tween(begin: twinkle.maxOpacity, end: 0.0), weight: 10), // Quick Fade Out (adjust weight)
                   TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: (twinkle.fadeInStart) * 100 + 80 ), // Hold invisible + fade out time
                ]).animate(CurvedAnimation(parent: _controller, curve: Curves.linear)); // Linear curve for continuous loop


                return Positioned(
                  left: twinkle.left * constraints.maxWidth, // Position based on screen width
                  top: twinkle.top * constraints.maxHeight, // Position based on screen height
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: Container(
                      width: twinkle.size,
                      height: twinkle.size,
                      decoration: const BoxDecoration(
                        color: Colors.white, // Twinkle color
                        shape: BoxShape.circle,
                        boxShadow: [ // Add a subtle glow
                          BoxShadow(
                            color: Colors.white54,
                            blurRadius: 4.0,
                            spreadRadius: 1.0,
                          )
                        ]
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }
}

// Helper class to store properties for each twinkle
class _Twinkle {
  final double left;
  final double top;
  final double size;
  final double fadeInStart;
  final double fadeInEnd;
  final double maxOpacity;

  _Twinkle({
    required this.left,
    required this.top,
    required this.size,
    required this.fadeInStart,
    required this.fadeInEnd,
    required this.maxOpacity,
  });
}