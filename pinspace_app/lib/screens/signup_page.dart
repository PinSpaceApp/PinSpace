// lib/screens/signup_page.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../widgets/animated_logo.dart';
import '../widgets/twinkling_background.dart';

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _birthdayController = TextEditingController();
  DateTime? _selectedDate;
  bool _agreedToTerms = false;
  bool _isLoading = false; // State variable for loading indicator

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // --- Sign Up Logic ---
  Future<void> _signUp() async {
    // Validate the form first
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isLoading) { // Also check if already loading
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    // If valid, proceed with sign-up attempt
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();
    // Use _selectedDate how needed (e.g., store, verify age)

    print('Sign Up attempt:');
    print('  First: $firstName, Last: $lastName, Username: $username');
    print('  Birthday: ${_selectedDate?.toIso8601String()}');
    print('  Email: $email, Pass: *****');
    print('  Agreed: $_agreedToTerms');

    // --- Implement Supabase Sign Up ---
    try {
      final result = await supabase.auth.signUp(
        email: email,
        password: password,
        // IMPORTANT: The keys here ('first_name', 'username' etc.) MUST match
        // how you want to store them in Supabase. By default, this goes into
        // the auth.users table's 'raw_user_meta_data' JSON column.
        // If you have a separate 'profiles' table, you'll need a trigger
        // or function in Supabase to copy this data over.
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          // Storing birthday directly might have privacy implications.
          // Often better to store only if necessary or calculate age server-side.
          // 'birthday': _selectedDate?.toIso8601String(),
        },
      );

      // Check if the widget is still mounted before showing SnackBar/Navigating
      if (mounted) {
        // Show success message (Supabase usually requires email verification by default)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Sign Up successful! Check your email for verification.'),
              backgroundColor: Colors.green),
        );
        // Navigate back to the previous screen (likely Login or Auth)
        _navigateToLogin(); // Use the existing navigation function
      }

    } on AuthException catch (e) {
      print('Sign Up Error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sign Up failed: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      print('Unexpected Sign Up Error: $e');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('An unexpected error occurred during sign up.'),
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
    // --- End Supabase Sign Up ---
  }

  // --- Date Picker Logic ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker( /* ... same as before ... */
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1920, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // --- Legal Link Tap Logic ---
  Future<void> _handleLinkTap(BuildContext context, String linkType) async {
    // ... (same as before, launches URL) ...
     final String urlString = linkType == 'Terms'
        ? 'https://YOUR_WEBSITE.com/terms' // Replace with your Terms URL
        : 'https://YOUR_WEBSITE.com/privacy'; // Replace with your Privacy URL
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

  // --- Navigation back to Login ---
   void _navigateToLogin() {
     if (Navigator.canPop(context)) {
        Navigator.pop(context);
     }
     // Or use pushReplacement if needed
  }

  // --- Input Field Decoration Helper ---
  InputDecoration _buildInputDecoration(String label, IconData icon) {
     // ... (same as before) ...
      return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      prefixIcon: Icon(icon, color: Colors.white70),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create PinSpace Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const TwinklingBackground(),
          Center(
            child: SingleChildScrollView(
               padding: const EdgeInsets.all(24.0),
               child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AnimatedLogo(size: 100), // Adjusted size
                      const SizedBox(height: 20),

                      // --- Form Fields (First Name -> Confirm Password) ---
                      // ... (All TextFormField widgets remain the same as before) ...
                       TextFormField( controller: _firstNameController, decoration: _buildInputDecoration('First Name', Icons.person_outline), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words, validator: (value) { if (value == null || value.trim().isEmpty) { return 'Please enter your first name'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _lastNameController, decoration: _buildInputDecoration('Last Name', Icons.person_outline), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words, validator: (value) { if (value == null || value.trim().isEmpty) { return 'Please enter your last name'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _usernameController, decoration: _buildInputDecoration('Username', Icons.account_circle_outlined), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.text, autocorrect: false, validator: (value) { if (value == null || value.trim().isEmpty) { return 'Please choose a username'; } if (value.length < 3) { return 'Username must be at least 3 characters'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _birthdayController, readOnly: true, decoration: _buildInputDecoration('Birthday', Icons.cake_outlined), style: const TextStyle(color: Colors.white), onTap: () { FocusScope.of(context).requestFocus(FocusNode()); _selectDate(context); }, validator: (value) { if (_selectedDate == null) { return 'Please select your birthday'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _emailController, decoration: _buildInputDecoration('Email', Icons.email_outlined), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress, autocorrect: false, validator: (value) { if (value == null || value.trim().isEmpty || !value.contains('@')) { return 'Please enter a valid email'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _passwordController, obscureText: true, decoration: _buildInputDecoration('Password', Icons.lock_outline), style: const TextStyle(color: Colors.white), validator: (value) { if (value == null || value.trim().isEmpty || value.length < 6) { return 'Password must be at least 6 characters'; } return null; },),
                       const SizedBox(height: 16),
                       TextFormField( controller: _confirmPasswordController, obscureText: true, decoration: _buildInputDecoration('Confirm Password', Icons.lock_outline), style: const TextStyle(color: Colors.white), validator: (value) { if (value != _passwordController.text) { return 'Passwords do not match'; } if (value == null || value.trim().isEmpty) { return 'Please confirm your password'; } return null; },),
                       const SizedBox(height: 16),

                      // --- Terms Agreement Checkbox ---
                       FormField<bool>(
                         builder: (state) { /* ... same as before ... */
                            return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ CheckboxListTile( value: _agreedToTerms, onChanged: (value) { setState(() { _agreedToTerms = value ?? false; }); }, title: RichText( text: TextSpan( text: 'I agree to the ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70), children: <TextSpan>[ TextSpan( text: 'Terms of Service', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer() ..onTap = () { _handleLinkTap(context, 'Terms'); } ), const TextSpan(text: ' and '), TextSpan( text: 'Privacy Policy', style: const TextStyle(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer() ..onTap = () { _handleLinkTap(context, 'Privacy'); } ), ], ), ), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: Theme.of(context).colorScheme.primary, checkColor: Colors.white, ), if (state.hasError) Padding( padding: const EdgeInsets.only(left: 12.0), child: Text( state.errorText ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12), ), ), ], );
                         },
                         validator: (value) {
                           if (!_agreedToTerms) {
                             return 'You must agree to the terms to continue.';
                           }
                           return null;
                         },
                       ),
                      const SizedBox(height: 24),

                      // --- Sign Up Button (Shows Loading Indicator) ---
                      _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.person_add),
                            label: const Text('Create Account'),
                            // Disable button if not agreed to terms
                            onPressed: _agreedToTerms ? _signUp : null,
                            // Style comes from theme
                          ),
                      const SizedBox(height: 20),

                      // --- Login Link ---
                      TextButton(
                        onPressed: _isLoading ? null : _navigateToLogin, // Disable if loading
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Already have an account? Login'),
                      ),
                    ],
                  ),
               ),
            ),
          ),
        ],
      ),
    );
  }
}
