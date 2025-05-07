// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../widgets/animated_logo.dart';
import '../widgets/twinkling_background.dart'; // Import the animated background
import 'signup_page.dart'; // Import SignUpPage for navigation

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // State variable for loading indicator

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Sign In Logic ---
  Future<void> _signIn() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isLoading) {
      return;
    }

    setState(() { _isLoading = true; });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    print('Login attempt with Email: $email, Pass: *****');

    try {
      // Attempt to sign in the user with email and password
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // If sign-in is successful and the widget is still mounted,
      // remove the LoginPage from the navigation stack to reveal HomePage.
      if (mounted) {
         // Using popUntil ensures we go back to the root screen managed by AuthGate
         Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } on AuthException catch (e) {
      print('Login failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login failed: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      print('Unexpected error during login: $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('An unexpected error occurred during login.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
       // Ensure loading state is turned off regardless of success/failure
       if (mounted) {
         setState(() {
           _isLoading = false;
         });
       }
    }
  }

  // --- Navigation to Sign Up ---
  void _navigateToSignUp() {
     print('Navigate to Sign Up Tapped!');
     Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignUpPage()),
      );
  }

  // --- Social Login Placeholder ---
  Future<void> _handleSocialLogin(BuildContext context, String provider) async {
    print('Attempting login with $provider');
    // TODO: Implement Supabase OAuth login
  }

  // --- Legal Link Tap Logic ---
  Future<void> _handleLinkTap(BuildContext context, String linkType) async {
    // IMPORTANT: Replace placeholders with your ACTUAL policy URLs
     final String urlString = linkType == 'Terms'
        ? 'https://YOUR_WEBSITE.com/terms' // Replace
        : 'https://YOUR_WEBSITE.com/privacy'; // Replace
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not open $linkType page.')),
         );
      }
    }
  }

  // --- Input Field Decoration Helper ---
  InputDecoration _buildInputDecoration(String label, IconData icon) {
      return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withOpacity(0.5), // Semi-transparent background
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // No visible border
      ),
      prefixIcon: Icon(icon, color: Colors.white70),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Body goes behind AppBar
      appBar: AppBar(
        // Title kept for clarity on this specific page
        title: const Text('Login to PinSpace'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white, // Make back arrow/title visible
      ),
      body: Stack( // Layer background and UI
        children: [
          // --- Twinkling Background ---
          const TwinklingBackground(), // Use the animated background

          // --- Login Form UI (Scrollable) ---
          Center(
            child: SingleChildScrollView(
               padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0), // Adjusted padding
               child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // Size column to content
                    children: [
                      // --- Animated Logo ---
                      // Adjusted size, slightly larger than original but smaller than AuthPage
                      const AnimatedLogo(size: 150),
                      const SizedBox(height: 20),

                      // --- Welcome Text ---
                      const Text(
                        'Welcome Back Pin Trader! Sign In Below:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                           shadows: [
                             Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(1,1))
                           ]
                        ),
                      ),
                      const SizedBox(height: 25),

                      // --- Email Field ---
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration('Email', Icons.email_outlined),
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Password Field ---
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _buildInputDecoration('Password', Icons.lock_outline),
                         style: const TextStyle(color: Colors.white),
                         validator: (value) {
                          if (value == null || value.trim().isEmpty || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                         },
                      ),
                       // TODO: Add 'Forgot Password?' link here if desired
                      const SizedBox(height: 24),

                      // --- Login Button (Shows Loading Indicator) ---
                      _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Login'),
                            onPressed: _signIn, // Calls the updated sign-in function
                            // Style comes from theme
                          ),
                       const SizedBox(height: 20),

                       // --- Social Login Separator ---
                       const Text( 'Or sign in with', style: TextStyle(color: Colors.white70),),
                       const SizedBox(height: 10),

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
                             onPressed: _isLoading ? null : () => _handleSocialLogin(context, 'google'), // Disable if loading
                           ),
                           const SizedBox(width: 20),
                           // Apple Button Placeholder
                           IconButton(
                             icon: const Icon(Icons.apple), // Placeholder
                             iconSize: 40,
                             color: Colors.white,
                             tooltip: 'Sign in with Apple',
                             onPressed: _isLoading ? null : () => _handleSocialLogin(context, 'apple'), // Disable if loading
                           ),
                         ],
                       ),
                      const SizedBox(height: 20),

                      // --- "Sign Up" Link ---
                      TextButton(
                        onPressed: _isLoading ? null : _navigateToSignUp, // Disable if loading
                        style: TextButton.styleFrom( foregroundColor: Colors.white,),
                        child: const Text('Not a PinSpace Trader? Sign Up!'),
                      ),
                    ],
                  ),
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
