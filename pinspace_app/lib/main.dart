// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:flutter_dotenv/flutter_dotenv.dart';   // Import dotenv
import 'auth_gate.dart';                                // Import your AuthGate widget
import 'theme/app_theme.dart';                          // Import your AppTheme class

// --- Asynchronous main function ---
Future<void> main() async {
  // Ensure Flutter bindings are initialized before using plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the .env file
  // Make sure '.env' is declared in pubspec.yaml assets
  await dotenv.load(fileName: ".env");

  // Initialize Supabase client
  // Reads URL and anon key from the loaded .env variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Run the Flutter application
  runApp(const MyApp()); // MyApp itself can be const
}

// --- Global Supabase client instance (optional convenience) ---
// You can access the client anywhere using Supabase.instance.client
// This global variable is just another way to access it if preferred.
final supabase = Supabase.instance.client;

// --- Root Application Widget ---
class MyApp extends StatelessWidget {
  // Constructor for MyApp
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp is the root of your UI
    return MaterialApp(
      title: 'PinSpace', // The title of your app

      // Apply the custom light theme defined in theme/app_theme.dart
      theme: AppTheme.lightTheme,

      // Optionally define dark theme and theme mode later
      // darkTheme: AppTheme.darkTheme,
      // themeMode: ThemeMode.system,

      // The initial route/widget for the app is AuthGate,
      // which handles routing based on login status.
      // REMOVED 'const' because AuthGate is a StatefulWidget
      home: AuthGate(),

      // Hide the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,
    );
  }
}

// Note: The default MyHomePage counter widget has been removed,
// as AuthGate now controls the initial screen.