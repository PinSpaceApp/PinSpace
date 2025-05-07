// lib/screens/auth_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'login_page.dart';                       // Import the LoginPage
import 'signup_page.dart';                      // Import the SignUpPage
import '../widgets/animated_logo.dart';
import '../widgets/twinkling_background.dart'; // Import the animated background
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Uncomment if using font_awesome icons later

// Screen shown when the user is not logged in.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  // Function to handle social login attempts (placeholder)
  Future<void> _handleSocialLogin(BuildContext context, String provider) async {
    print('Attempting login with $provider');
    // TODO: Implement Supabase OAuth login
    // try {
    //   await supabase.auth.signInWithOAuth(
    //     provider == 'google' ? OAuthProvider.google : OAuthProvider.apple,
    //   );
    // } catch (e) {
    //   print('Social login error: $e');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Social login failed: $e')),
    //   );
    // }
  }

  // Function to handle legal link taps using url_launcher
  Future<void> _handleLinkTap(BuildContext context, String linkType) async {
    // IMPORTANT: Replace placeholders with your ACTUAL policy URLs
    final String urlString = linkType == 'Terms'
        ? 'https://YOUR_WEBSITE.com/terms' // Replace with your Terms URL
        : 'https://YOUR_WEBSITE.com/privacy'; // Replace with your Privacy URL
    final Uri url = Uri.parse(urlString);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
      // Show an error message if the URL can't be launched
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not open $linkType page.')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar here for a cleaner look, navigation handled by Navigator stack
      body: Stack( // Use Stack to layer background and UI
        children: [
          // --- Twinkling Background (Includes image) ---
          const TwinklingBackground(),

          // --- Centered Main Content ---
          Center(
            child: SingleChildScrollView( // Allow scrolling if content overflows
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Size column to content width
                children: [
                  // --- Animated Logo ---
                  const AnimatedLogo(size: 350), // Adjusted size
                  const SizedBox(height: 20),

                  // --- Intro Text ---
                  const Text(
                    'Discover, collect, and trade thousands of collector pins with fellow enthusiasts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, // Ensure text is visible
                      fontSize: 16,
                      shadows: [ // Add shadow for better readability
                        Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(1,1))
                      ]
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Login Button ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.door_front_door_outlined),
                    label: const Text('Login'),
                    onPressed: () {
                      // Navigate to the LoginPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                     // Style comes from theme
                     // Example override: style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  ),
                  const SizedBox(height: 15),

                  // --- Sign Up Button ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Sign Up'),
                    onPressed: () {
                      // Navigate to the SignUpPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                      );
                      print('Navigating to Sign Up page...');
                    },
                     // Style comes from theme
                     // Example override: style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  ),
                  const SizedBox(height: 30),

                  // --- Social Login Separator ---
                   const Text(
                     'Or continue with',
                     style: TextStyle(color: Colors.white70),
                   ),
                  const SizedBox(height: 15),

                  // --- Social Login Buttons ---
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       // Google Button Placeholder
                       IconButton(
                         icon: const Icon(Icons.android_rounded), // Placeholder
                         iconSize: 40,
                         color: Colors.white,
                         tooltip: 'Sign in with Google',
                         onPressed: () => _handleSocialLogin(context, 'google'),
                       ),
                       const SizedBox(width: 20),
                       // Apple Button Placeholder
                       IconButton(
                         icon: const Icon(Icons.apple), // Placeholder
                         iconSize: 40,
                         color: Colors.white,
                         tooltip: 'Sign in with Apple',
                         onPressed: () => _handleSocialLogin(context, 'apple'),
                       ),
                     ],
                   ),
                ],
              ),
            ),
          ),

          // --- Legal Links at Bottom ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _handleLinkTap(context, 'Terms'),
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white70),
                    ),
                  ),
                  const Text('  |  ', style: TextStyle(color: Colors.white70, fontSize: 12)), // Separator
                  TextButton(
                     onPressed: () => _handleLinkTap(context, 'Privacy'),
                     child: const Text(
                       'Privacy Policy',
                       style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
