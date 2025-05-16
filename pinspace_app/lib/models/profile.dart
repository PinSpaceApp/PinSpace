// lib/models/profile.dart

class Profile {
  final String id; // Corresponds to auth.users.id
  String? username;
  String? fullName;
  String? avatarUrl;
  String? coverPhotoUrl; // << NEW FIELD
  String? bio;
  bool isCollectionPublic;
  bool isSetsPublic;
  // Add other privacy settings as needed, e.g.:
  // bool isProfileCompletelyHidden;
  // String trophiesVisibility; // e.g., 'public', 'private', 'followers_only'
  final DateTime createdAt;
  DateTime updatedAt;

  Profile({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.coverPhotoUrl, // << NEW PARAMETER
    this.bio,
    this.isCollectionPublic = true,
    this.isSetsPublic = true,
    // this.isProfileCompletelyHidden = false,
    // this.trophiesVisibility = 'public',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      username: map['username'] as String?,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      coverPhotoUrl: map['cover_photo_url'] as String?, // << READ FROM MAP
      bio: map['bio'] as String?,
      isCollectionPublic: map['is_collection_public'] as bool? ?? true,
      isSetsPublic: map['is_sets_public'] as bool? ?? true,
      // isProfileCompletelyHidden: map['is_profile_completely_hidden'] as bool? ?? false,
      // trophiesVisibility: map['trophies_visibility'] as String? ?? 'public',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    // Only include fields that are meant to be updated by the user directly from EditProfilePage
    // or that need to be set on creation.
    return {
      'id': id, // Important for upsert
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl, // This will be the new URL after upload
      'cover_photo_url': coverPhotoUrl, // << ADD TO MAP (this will be new URL after upload)
      'bio': bio,
      // Privacy settings are typically updated on their own page
      // 'is_collection_public': isCollectionPublic, 
      // 'is_sets_public': isSetsPublic,
      // 'is_profile_completely_hidden': isProfileCompletelyHidden,
      // 'trophies_visibility': trophiesVisibility,
      'updated_at': DateTime.now().toIso8601String(), 
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? coverPhotoUrl, // << NEW PARAMETER
    String? bio,
    bool? isCollectionPublic,
    bool? isSetsPublic,
    // bool? isProfileCompletelyHidden,
    // String? trophiesVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl, // << ASSIGN
      bio: bio ?? this.bio,
      isCollectionPublic: isCollectionPublic ?? this.isCollectionPublic,
      isSetsPublic: isSetsPublic ?? this.isSetsPublic,
      // isProfileCompletelyHidden: isProfileCompletelyHidden ?? this.isProfileCompletelyHidden,
      // trophiesVisibility: trophiesVisibility ?? this.trophiesVisibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
