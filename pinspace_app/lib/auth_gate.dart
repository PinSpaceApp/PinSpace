    // lib/auth_gate.dart
    import 'package:flutter/material.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';
    import 'screens/auth_page.dart';
    // import 'screens/home_page.dart'; // REMOVE THIS IMPORT
    import 'screens/splash_screen.dart';
    import 'screens/main_app_shell.dart'; // <-- IMPORT THE NEW SHELL

    class AuthGate extends StatefulWidget {
      const AuthGate({super.key});
      @override
      State<AuthGate> createState() => _AuthGateState();
    }

    class _AuthGateState extends State<AuthGate> {
      // --- REMOVED TEMPORARY DELAY ---
      // If you still have the FutureBuilder delay here, remove it
      // so the app navigates immediately after auth check.

      @override
      Widget build(BuildContext context) {
        return StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(); // Show splash while waiting
            }

            final session = snapshot.data?.session;

            if (session != null) {
              // User is logged in, show the MainAppShell
              return const MainAppShell(); // <-- USE MAIN APP SHELL
            } else {
              // User is not logged in, show AuthPage
              return const AuthPage();
            }
          },
        );
      }
    }
    