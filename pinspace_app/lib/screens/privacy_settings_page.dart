// lib/screens/privacy_settings_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart'; // Assuming your profile model is here

final supabase = Supabase.instance.client;

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _isLoading = true;
  String? _fetchError;
  Profile? _currentProfile; // To hold the full profile data

  // Specific privacy settings state
  bool _isProfileCompletelyHidden = false; // New setting
  bool _isCollectionPublic = true;
  bool _isSetsPublic = true;
  bool _areTrophiesPublic = true; // New setting

  // You might want enums for more granular control later e.g., 'public', 'followers_only', 'private'
  // For now, using booleans for simplicity matching the 'profiles' table proposal

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _fetchError = null;
      });
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User not logged in.");
      }
      
      final data = await supabase
          .from('profiles')
          .select('is_collection_public, is_sets_public, is_profile_completely_hidden, trophies_visibility') // Add new fields
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        // Store the full profile if needed elsewhere, or just the settings
        // For now, just updating the local state for switches
        setState(() {
          _isCollectionPublic = data['is_collection_public'] as bool? ?? true;
          _isSetsPublic = data['is_sets_public'] as bool? ?? true;
          _isProfileCompletelyHidden = data['is_profile_completely_hidden'] as bool? ?? false;
          // Assuming trophies_visibility is stored as text 'public', 'private', 'followers_only'
          // For simplicity, let's map it to a boolean for now, or you'd use a dropdown.
          _areTrophiesPublic = (data['trophies_visibility'] as String? ?? 'public') == 'public';
        });
      } else {
        // No profile found, use default values (user will save to create/update)
        print("No profile found for privacy settings. Using defaults.");
         // This case should ideally not happen if EditProfilePage ensures a profile row exists
      }
    } catch (e) {
      print("Error loading privacy settings: $e");
      if (mounted) {
        _fetchError = "Failed to load privacy settings: ${e.toString()}";
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true; // Show loading indicator during save
        _fetchError = null;
      });
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in.");

      final updates = {
        'is_collection_public': _isCollectionPublic,
        'is_sets_public': _isSetsPublic,
        'is_profile_completely_hidden': _isProfileCompletelyHidden,
        'trophies_visibility': _areTrophiesPublic ? 'public' : 'private', // Example mapping
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').update(updates).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Privacy settings updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error saving privacy settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save settings: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color accentColor = theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Settings"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fetchError != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_fetchError!, style: TextStyle(color: Colors.red[700], fontSize: 16), textAlign: TextAlign.center),
                ))
              : ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Control what others can see about your PinSpace activity and collection.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: SwitchListTile(
                        title: const Text("Hide My Profile Completely"),
                        subtitle: Text(_isProfileCompletelyHidden 
                            ? "Your profile, pins, and sets are hidden. Trading/selling is disabled." 
                            : "Your profile is visible based on other settings."),
                        value: _isProfileCompletelyHidden,
                        onChanged: (bool value) {
                          setState(() {
                            _isProfileCompletelyHidden = value;
                            // If profile is completely hidden, other settings might be implicitly private
                            if (value) {
                              _isCollectionPublic = false;
                              _isSetsPublic = false;
                              _areTrophiesPublic = false;
                            }
                          });
                        },
                        activeColor: accentColor,
                        secondary: Icon(Icons.visibility_off_outlined, color: _isProfileCompletelyHidden ? accentColor : primaryColor),
                      ),
                    ),

                    // Other settings are only relevant if profile is not completely hidden
                    if (!_isProfileCompletelyHidden) ...[
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: SwitchListTile(
                          title: const Text("Make My Pin Collection Public"),
                          subtitle: Text(_isCollectionPublic ? "Visible to everyone" : "Only you can see it"),
                          value: _isCollectionPublic,
                          onChanged: (bool value) {
                            setState(() {
                              _isCollectionPublic = value;
                            });
                          },
                          activeColor: accentColor,
                          secondary: Icon(Icons.style_outlined, color: primaryColor),
                        ),
                      ),
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: SwitchListTile(
                          title: const Text("Make My Sets Public"),
                          subtitle: Text(_isSetsPublic ? "Visible to everyone" : "Only you can see them"),
                          value: _isSetsPublic,
                          onChanged: (bool value) {
                            setState(() {
                              _isSetsPublic = value;
                            });
                          },
                          activeColor: accentColor,
                          secondary: Icon(Icons.collections_bookmark_outlined, color: primaryColor),
                        ),
                      ),
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: SwitchListTile(
                          title: const Text("Make My Trophies/Achievements Public"),
                          subtitle: Text(_areTrophiesPublic ? "Visible on your profile" : "Only you can see them"),
                          value: _areTrophiesPublic,
                          onChanged: (bool value) {
                            setState(() {
                              _areTrophiesPublic = value;
                            });
                          },
                          activeColor: accentColor,
                          secondary: Icon(Icons.emoji_events_outlined, color: primaryColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton(
                        child: _isLoading 
                               ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                               : const Text("Save Privacy Settings"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _savePrivacySettings,
                      ),
                    ),
                  ],
                ),
    );
  }
}
