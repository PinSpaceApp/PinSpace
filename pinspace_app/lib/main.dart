// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // No longer needed
import 'auth_gate.dart';
import 'theme/app_theme.dart';

// --- Compile-time variables from --dart-define ---
// Use const String.fromEnvironment to read the values passed during build
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Check if variables were passed ---
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    // Handle error - variables weren't passed during build
    // This might happen during local development if you don't pass them
    print('ERROR: SUPABASE_URL or SUPABASE_ANON_KEY not passed via --dart-define.');
    print('Ensure they are set in your build environment (e.g., Netlify UI).');
    // Optionally, you could fall back to dotenv for local dev,
    // but it's better to pass them locally too via flutter run --dart-define=...
    // For now, we'll just initialize with empty strings which will likely fail later
    // await dotenv.load(fileName: ".env"); // Fallback removed for clarity
  }

  // Initialize Supabase using compile-time variables
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
   const MyApp({super.key});

   @override
   Widget build(BuildContext context) {
     return MaterialApp(
       title: 'PinSpace',
       theme: AppTheme.lightTheme,
       home: AuthGate(),
       debugShowCheckedModeBanner: false,
     );
   }
}
