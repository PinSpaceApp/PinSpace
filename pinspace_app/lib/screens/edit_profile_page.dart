// lib/screens/edit_profile_page.dart
import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart'; 

final supabase = Supabase.instance.client;

// Define ImageTarget enum here, at the top level of the file
enum ImageTarget { avatar, coverPhoto }

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true; 
  String? _fetchError;

  Profile? _currentProfile; 
  
  XFile? _newAvatarXFile; 
  Uint8List? _newAvatarBytes; 

  XFile? _newCoverPhotoXFile;
  Uint8List? _newCoverPhotoBytes;

  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;

  final ImagePicker _picker = ImagePicker();

  // Define avatar and cover photo dimensions
  static const double avatarRadius = 50.0; // Radius of the avatar
  static const double avatarBorderWidth = 4.0; // Width of the white border
  static const double coverPhotoHeight = 180.0;


  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
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
          .select('id, username, full_name, avatar_url, bio, cover_photo_url, is_collection_public, is_sets_public, created_at, updated_at') 
          .eq('id', userId)
          .maybeSingle(); 

      if (data != null) {
        _currentProfile = Profile.fromMap(data); 
        _usernameController.text = _currentProfile?.username ?? '';
        _fullNameController.text = _currentProfile?.fullName ?? '';
        _bioController.text = _currentProfile?.bio ?? '';
      } else {
        print("No profile found for user $userId. Initializing with defaults.");
        _currentProfile = Profile( 
            id: userId, 
            createdAt: DateTime.now(), 
            updatedAt: DateTime.now(),
            isCollectionPublic: true, 
            isSetsPublic: true     
        ); 
        _usernameController.text = ''; 
        _fullNameController.text = '';
        _bioController.text = '';
      }

    } catch (e) {
      print("Error loading profile: $e");
      if (mounted) {
        _fetchError = "Failed to load profile: ${e.toString()}";
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageTarget target) async { 
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: target == ImageTarget.avatar ? 70 : 80, 
        maxWidth: target == ImageTarget.avatar ? 800 : 1200, 
      );
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes(); 
        setState(() {
          if (target == ImageTarget.avatar) {
            _newAvatarXFile = pickedFile; 
            _newAvatarBytes = bytes; 
          } else { // target == ImageTarget.coverPhoto
            _newCoverPhotoXFile = pickedFile;
            _newCoverPhotoBytes = bytes;
          }
        });
      }
    } catch (e) {
      print("Error picking ${target.name} image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image for ${target.name}: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true; 
        _fetchError = null;
      });
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in.");

      String? newAvatarUrl = _currentProfile?.avatarUrl;
      String? newCoverPhotoUrl = _currentProfile?.coverPhotoUrl;

      if (_newAvatarBytes != null && _newAvatarXFile != null) { 
        final imageExtension = _newAvatarXFile!.name.split('.').last.toLowerCase();
        final safeImageExtension = (imageExtension.isNotEmpty) ? imageExtension : 'jpg';
        final imagePath = '$userId/avatar.$safeImageExtension'; 

        print("Attempting to upload avatar to: $imagePath");
        await supabase.storage.from('avatars').uploadBinary( 
              imagePath,
              _newAvatarBytes!, 
              fileOptions: FileOptions(cacheControl: '3600', upsert: true, contentType: 'image/$safeImageExtension'),
            );
        newAvatarUrl = supabase.storage.from('avatars').getPublicUrl(imagePath);
        print("New avatar URL: $newAvatarUrl");
      }

      if (_newCoverPhotoBytes != null && _newCoverPhotoXFile != null) {
        final imageExtension = _newCoverPhotoXFile!.name.split('.').last.toLowerCase();
        final safeImageExtension = (imageExtension.isNotEmpty) ? imageExtension : 'jpg';
        final imagePath = '$userId/cover_photo.$safeImageExtension'; 

        await supabase.storage.from('profile-assets').uploadBinary( 
              imagePath,
              _newCoverPhotoBytes!, 
              fileOptions: FileOptions(cacheControl: '3600', upsert: true, contentType: 'image/$safeImageExtension'),
            );
        newCoverPhotoUrl = supabase.storage.from('profile-assets').getPublicUrl(imagePath);
        print("New cover photo URL: $newCoverPhotoUrl");
      }


      final profileDataToSave = {
        'id': userId, 
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'avatar_url': newAvatarUrl,
        'cover_photo_url': newCoverPhotoUrl, 
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('profiles').upsert(profileDataToSave);

      if (mounted) {
        setState(() { 
          _currentProfile = _currentProfile?.copyWith(
            avatarUrl: newAvatarUrl,
            coverPhotoUrl: newCoverPhotoUrl,
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
            updatedAt: DateTime.now()
          );
          _newAvatarXFile = null; 
          _newAvatarBytes = null;
          _newCoverPhotoXFile = null;
          _newCoverPhotoBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save profile: ${e.toString()}"), backgroundColor: Colors.red),
        );
        _fetchError = "Failed to save profile: ${e.toString()}";
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

    ImageProvider? avatarImageProvider;
    if (_newAvatarBytes != null) {
      avatarImageProvider = MemoryImage(_newAvatarBytes!);
    } else if (_currentProfile?.avatarUrl != null && _currentProfile!.avatarUrl!.isNotEmpty) {
      avatarImageProvider = NetworkImage(_currentProfile!.avatarUrl!);
    }

    ImageProvider? coverImageProvider;
    if (_newCoverPhotoBytes != null) {
      coverImageProvider = MemoryImage(_newCoverPhotoBytes!);
    } else if (_currentProfile?.coverPhotoUrl != null && _currentProfile!.coverPhotoUrl!.isNotEmpty) {
      coverImageProvider = NetworkImage(_currentProfile!.coverPhotoUrl!);
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading && _currentProfile == null 
          ? const Center(child: CircularProgressIndicator())
          : _fetchError != null && _currentProfile == null 
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_fetchError!, style: TextStyle(color: Colors.red[700], fontSize: 16), textAlign: TextAlign.center),
                ))
              : Form(
                  key: _formKey,
                  child: ListView( // Using ListView to allow scrolling for all content
                    padding: EdgeInsets.zero, // Remove ListView's default padding
                    children: <Widget>[
                      // --- Cover Photo and Avatar Stack ---
                      SizedBox( // Constrain the height of the Stack area
                        height: coverPhotoHeight + avatarRadius, // Cover height + avatar radius for overlap
                        child: Stack(
                          clipBehavior: Clip.none, // Allow avatar to overflow visually
                          alignment: Alignment.topCenter,
                          children: [
                            // Cover Photo Area
                            Positioned.fill(
                              bottom: avatarRadius, // Make space for avatar to overlap from bottom
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      image: coverImageProvider != null
                                          ? DecorationImage(
                                              image: coverImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: coverImageProvider == null
                                        ? Icon(Icons.photo_size_select_actual_outlined, size: 60, color: Colors.grey[500])
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: FloatingActionButton.small(
                                      heroTag: 'coverPhotoPicker', // Unique heroTag
                                      onPressed: () => _pickImage(ImageTarget.coverPhoto),
                                      tooltip: 'Change Cover Photo',
                                      backgroundColor: accentColor.withOpacity(0.8),
                                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Avatar Area (Positioned to overlap)
                            Positioned(
                              bottom: 0, // Sits on the bottom edge of the SizedBox
                              left: 20.0, // Indent from the left
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container( // White border
                                    padding: const EdgeInsets.all(avatarBorderWidth),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).scaffoldBackgroundColor, // Or Colors.white
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 5,
                                          offset: const Offset(0,2)
                                        )
                                      ]
                                    ),
                                    child: CircleAvatar(
                                      radius: avatarRadius,
                                      backgroundColor: Colors.grey[400], // Fallback if no image
                                      backgroundImage: avatarImageProvider,
                                      child: (avatarImageProvider == null)
                                          ? Icon(Icons.person, size: avatarRadius, color: Colors.grey[700])
                                          : null,
                                    ),
                                  ),
                                  Material( // Edit button for avatar
                                    color: accentColor.withOpacity(0.9),
                                    shape: const CircleBorder(),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: () => _pickImage(ImageTarget.avatar),
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // --- End Cover Photo and Avatar Stack ---
                      
                      Padding( 
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0), // Padding for the form fields below
                        child: Column(
                          children: [
                            // SizedBox(height: avatarRadius + 16), // Space for the overlapping avatar if not using Stack height correctly
                            const SizedBox(height: 24), // General spacing after avatar
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: "Username",
                                hintText: "Choose a unique username",
                                prefixIcon: Icon(Icons.alternate_email, color: primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  if (_currentProfile != null && _currentProfile!.username == null) {
                                      return 'Username cannot be empty';
                                  }
                                }
                                if (value != null && (value.trim().length < 3 || value.trim().length > 25)) {
                                  return 'Username must be 3-25 characters';
                                }
                                if (value != null && !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                                  return 'Alphanumeric & underscores only';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: "Full Name (Optional)",
                                prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bioController,
                              decoration: InputDecoration(
                                labelText: "Bio (Optional)",
                                hintText: "Tell us a bit about your pin passion!",
                                prefixIcon: Icon(Icons.edit_note_outlined, color: primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 3,
                              maxLength: 150,
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              icon: _isLoading && _currentProfile != null 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_outlined),
                              label: Text(_isLoading && _currentProfile != null ? "Saving..." : "Save Changes"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (_isLoading && _currentProfile != null) ? null : _saveProfile,
                            ),
                             const SizedBox(height: 20), // Bottom padding inside ListView
                          ],
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}
