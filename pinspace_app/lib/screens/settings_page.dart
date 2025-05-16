// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'edit_profile_page.dart'; 
import 'privacy_settings_page.dart'; // << IMPORT NEW PAGE
import 'package:supabase_flutter/supabase_flutter.dart'; // For Log Out

final supabase = Supabase.instance.client;


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primarySettingColor = theme.colorScheme.primary; 
    final Color iconColor = theme.colorScheme.secondary; 

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: primarySettingColor, 
        foregroundColor: Colors.white, 
        elevation: 2,
      ),
      body: ListView(
        children: <Widget>[
          _buildSectionHeader(context, "Account"),
          ListTile(
            leading: Icon(Icons.person_outline, color: iconColor),
            title: const Text("Edit Profile"),
            subtitle: const Text("Username, name, bio, avatar"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          ),
          
          const Divider(),
          _buildSectionHeader(context, "Privacy"),
          ListTile(
            leading: Icon(Icons.lock_outline, color: iconColor),
            title: const Text("Privacy Settings"),
            subtitle: const Text("Profile, collection, and set visibility"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // *** MODIFIED: Navigate to PrivacySettingsPage ***
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacySettingsPage()),
              );
            },
          ),
           ListTile(
            leading: Icon(Icons.shield_outlined, color: iconColor),
            title: const Text("Trophy/Achievement Visibility"),
            subtitle: const Text("Control who sees your accomplishments"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // This could also be part of PrivacySettingsPage or its own page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Trophy privacy settings coming soon!")),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader(context, "Notifications"),
          ListTile(
            leading: Icon(Icons.notifications_none_outlined, color: iconColor),
            title: const Text("Notification Settings"),
            subtitle: const Text("Manage email and push notifications"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notification Settings page coming soon!")),
              );
            },
          ),
          
          const Divider(),
          _buildSectionHeader(context, "General"),
           ListTile(
            leading: Icon(Icons.palette_outlined, color: iconColor),
            title: const Text("Appearance"),
            subtitle: const Text("Theme (Light/Dark)"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Appearance settings coming soon!")),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader(context, "About"),
          ListTile(
            leading: Icon(Icons.info_outline, color: iconColor),
            title: const Text("About PinSpace"),
            onTap: () {
               showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("About PinSpace"),
                  content: const Text("Version 1.0.0\nYour magical pin trading companion!"), 
                  actions: [
                    TextButton(
                      child: const Text("OK"),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ));
            },
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: iconColor),
            title: const Text("Terms of Service"),
            onTap: () {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Link to Terms of Service coming soon!")),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: iconColor),
            title: const Text("Privacy Policy"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Link to Privacy Policy coming soon!")),
              );
            },
          ),
          const Divider(),
            ListTile(
            leading: Icon(Icons.logout, color: Colors.red[400]),
            title: Text("Log Out", style: TextStyle(color: Colors.red[700])),
            onTap: () async {
              try {
                await supabase.auth.signOut();
                // Ensure you have a named route '/authGate' or similar that handles auth state
                if (context.mounted) { // Check if widget is still in tree
                    Navigator.of(context).pushNamedAndRemoveUntil('/authGate', (route) => false); 
                }
              } catch (e) {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to log out: $e"), backgroundColor: Colors.red),
                    );
                 }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7), 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
