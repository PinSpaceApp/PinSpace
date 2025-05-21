// lib/screens/user_profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/achievement.dart'; 
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'main_app_shell.dart'; // For MainAppShell.userProfileRouteName

// Assuming Pin, PinStatus, ActivityPost, ActivityPostCard, PinsViewMode are defined
// or imported from their respective files. For this example, I'll keep placeholders
// to keep this file focused on the UserProfilePage structure itself.

final supabase = Supabase.instance.client;
const Color profileAccentColor = Color(0xFFFFC107);

// --- Placeholder Pin Model (Ensure this or your actual model is available) ---
enum PinStatus { inCollection, forTrade }
class Pin {
  final String id; 
  final String userId;
  final String? imageUrl;
  final String? title; 
  final PinStatus status; 

  Pin({
    required this.id,
    required this.userId,
    this.imageUrl,
    this.title,
    this.status = PinStatus.inCollection, 
  });

  factory Pin.fromMap(Map<String, dynamic> map) {
    String statusString = map['status'] as String? ?? "In Collection";
    PinStatus currentStatus = PinStatus.inCollection;
    if (statusString.toLowerCase() == "for trade") {
      currentStatus = PinStatus.forTrade;
    }
    return Pin(
      id: map['id'].toString(),
      userId: map['user_id'] as String,
      imageUrl: map['image_url'] as String?,
      title: map['name'] as String?, 
      status: currentStatus,
    );
  }
  String get statusDisplay { 
    switch (status) {
      case PinStatus.inCollection: return "In Collection";
      case PinStatus.forTrade: return "For Trade";
      default: return "In Collection";
    }
  }
}
// --- End Pin Model ---

// --- ActivityPost Model ---
class ActivityPost { 
  final String id; 
  final String userId; 
  final String? authorUsername; 
  final String? authorAvatarUrl; 
  final String? authorFullName; 
  final String content; 
  final DateTime createdAt; 
  final String? imageUrl; 
  int likesCount; 
  int commentsCount; 
  bool isLikedByCurrentUser;

  ActivityPost({ 
    required this.id, 
    required this.userId, 
    this.authorUsername, 
    this.authorAvatarUrl,
    this.authorFullName, 
    required this.content, 
    required this.createdAt, 
    this.imageUrl,
    this.likesCount = 0, 
    this.commentsCount = 0, 
    this.isLikedByCurrentUser = false
  });

  factory ActivityPost.fromMapWithAuthor(Map<String, dynamic> postMap, Map<String, dynamic>? authorProfileMap) {
    return ActivityPost(
      id: postMap['id'] as String,
      userId: postMap['user_id'] as String,
      content: postMap['content'] as String,
      createdAt: DateTime.parse(postMap['created_at'] as String),
      imageUrl: postMap['image_url'] as String?,
      likesCount: postMap['likes_count'] as int? ?? 0,
      commentsCount: postMap['comments_count'] as int? ?? 0,
      authorUsername: authorProfileMap?['username'] as String?,
      authorAvatarUrl: authorProfileMap?['avatar_url'] as String?,
      authorFullName: authorProfileMap?['full_name'] as String?,
    );
  }
}
// --- End ActivityPost Model ---

enum PinsViewMode { all, sets }

class UserProfilePage extends StatefulWidget {
  final String? profileUserId;
  // <<--- NEW: Added initialTabIndex parameter --- >>
  final int initialTabIndex; 

  const UserProfilePage({
    super.key, 
    this.profileUserId,
    this.initialTabIndex = 0 // Default to the first tab (Activity)
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  Profile? _userProfile;
  bool _isLoadingProfile = true;
  String? _profileError;

  List<Pin> _userPins = [];
  bool _isLoadingPins = true;
  String? _pinsError;
  PinsViewMode _pinsViewMode = PinsViewMode.all;

  List<ActivityPost> _userActivity = [];
  bool _isLoadingActivity = true;
  String? _activityError;

  List<UserAchievement> _unlockedAchievements = [];
  bool _isLoadingAchievements = true;
  String? _achievementsError;
  
  late TabController _tabController;
  String? _currentAuthUserId;
  bool _isFollowing = false;
  bool _isLoadingFollowStatus = false;

  static const double coverPhotoHeight = 150.0;
  static const double avatarRadius = 45.0;
  static const double avatarBorderWidth = 2.0;
  static const double avatarOverlap = avatarRadius * 0.3;
  static const double tabIconSize = 22.0;

  @override
  void initState() {
    super.initState();
    _currentAuthUserId = supabase.auth.currentUser?.id;
    // <<--- MODIFIED: Use widget.initialTabIndex for TabController --- >>
    _tabController = TabController(
        length: 5, 
        vsync: this, 
        initialIndex: widget.initialTabIndex // Use the passed initialTabIndex
    );
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _targetUserId => widget.profileUserId ?? _currentAuthUserId ?? '';
  bool get _isCurrentUserProfile => _targetUserId == _currentAuthUserId && _currentAuthUserId != null;

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;
    if (_targetUserId.isEmpty) {
        setState(() { _isLoadingProfile = false; _profileError = "Cannot load profile: User ID not available."; });
        return;
    }
    setState(() {
      _isLoadingProfile = true; _profileError = null;
      _isLoadingPins = true; _userPins = []; _pinsError = null;
      _isLoadingActivity = true; _userActivity = []; _activityError = null;
      _isLoadingFollowStatus = !_isCurrentUserProfile;
      _isLoadingAchievements = true; _unlockedAchievements = []; _achievementsError = null; 
    });

    try {
      final data = await supabase.from('profiles').select().eq('id', _targetUserId).maybeSingle();
      if (!mounted) return;
      if (data != null) {
        _userProfile = Profile.fromMap(data);
        if (_userProfile != null) {
          _fetchUserPins(_userProfile!.id);
          _fetchUserActivity(_userProfile!.id);
          _fetchUserAchievements(_userProfile!.id); 
          if (!_isCurrentUserProfile) _checkFollowStatus();
        }
      } else {
        _profileError = "Profile not found for ID: $_targetUserId.";
      }
    } catch (e) {
      if (!mounted) return;
      _profileError = "Failed to load profile: ${e.toString()}";
    } finally {
        if(mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _checkFollowStatus() async { 
    if (!mounted || _currentAuthUserId == null || _targetUserId.isEmpty || _isCurrentUserProfile) {
      if (mounted) setState(() => _isLoadingFollowStatus = false); return;
    }
    if (mounted) setState(() => _isLoadingFollowStatus = true);
    try {
      final response = await supabase.from('user_follows').select('id').eq('follower_id', _currentAuthUserId!).eq('following_id', _targetUserId).maybeSingle();
      if (mounted) setState(() { _isFollowing = response != null; _isLoadingFollowStatus = false; });
    } catch (e) {
      if (mounted) { print('Error checking follow status: $e'); setState(() => _isLoadingFollowStatus = false); }
    }
  }
  Future<void> _toggleFollow() async { 
     if (!mounted || _currentAuthUserId == null || _targetUserId.isEmpty || _isCurrentUserProfile || _isLoadingFollowStatus) return;
    if (mounted) setState(() => _isLoadingFollowStatus = true);
    final currentlyFollowing = _isFollowing;
    if (mounted) setState(() => _isFollowing = !currentlyFollowing);
    try {
      if (currentlyFollowing) await supabase.from('user_follows').delete().match({'follower_id': _currentAuthUserId!, 'following_id': _targetUserId});
      else await supabase.from('user_follows').insert({'follower_id': _currentAuthUserId!, 'following_id': _targetUserId});
      if(mounted) setState(() => _isLoadingFollowStatus = false);
    } catch (e) {
      if (mounted) {
        print('Error toggling follow: $e');
        setState(() { _isFollowing = currentlyFollowing; _isLoadingFollowStatus = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update follow status: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }
  Future<void> _fetchUserPins(String userId) async { 
    if (!mounted) return; setState(() { _isLoadingPins = true; _pinsError = null; });
    try {
      final response = await supabase.from('pins').select('id, user_id, image_url, name, status').eq('user_id', userId);
      if (!mounted) return;
      final List<dynamic> data = response as List<dynamic>;
      _userPins = data.map((map) => Pin.fromMap(map as Map<String, dynamic>)).toList();
    } catch (e) { if (!mounted) return; _pinsError = "Failed to load pins: ${e.toString()}";
    } finally { if (mounted) setState(() { _isLoadingPins = false; }); }
  }

  Future<void> _fetchUserActivity(String userId) async { 
    if (!mounted) return; setState(() { _isLoadingActivity = true; _activityError = null; });
    try {
      await Future.delayed(const Duration(milliseconds: 100)); 
      if (!mounted) return; 
      List<ActivityPost> fetchedActivities = [];
      if (_userProfile != null) { 
          fetchedActivities = [
            ActivityPost(id: '1', userId: _userProfile!.id, content: 'This is my first post on my own profile!', createdAt: DateTime.now().subtract(const Duration(hours: 2)), authorUsername: _userProfile!.username, authorAvatarUrl: _userProfile!.avatarUrl, imageUrl: 'https://placehold.co/600x400/E6E6FA/333333?text=Post+Image+1'),
            ActivityPost(id: '2', userId: _userProfile!.id, content: 'Another cool update from me!', createdAt: DateTime.now().subtract(const Duration(days: 1)), authorUsername: _userProfile!.username, authorAvatarUrl: _userProfile!.avatarUrl),
          ];
      }
      _userActivity = fetchedActivities;
    } catch (e) { if (!mounted) return; _activityError = "Failed to load activity: ${e.toString()}";
    } finally { if (mounted) setState(() { _isLoadingActivity = false; }); }
  }

  Future<void> _fetchUserAchievements(String userId) async {
    if (!mounted) return;
    setState(() { _isLoadingAchievements = true; _achievementsError = null; });
    try {
      final response = await supabase.from('user_achievements').select('achievement_id, unlocked_at').eq('user_id', userId);
      if (!mounted) return;
      final List<dynamic> data = response as List<dynamic>;
      _unlockedAchievements = data.map((map) => UserAchievement.fromMap({...map as Map<String, dynamic>, 'user_id': userId })).toList();
    } catch (e) {
      if (!mounted) return;
      _achievementsError = "Failed to load trophies: ${e.toString()}";
    } finally {
      if (mounted) setState(() => _isLoadingAchievements = false);
    }
  }

  @override
  Widget build(BuildContext context) { 
    final theme = Theme.of(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: <Widget>[
        _buildFixedHeader(context, theme, statusBarHeight),
        Container(decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.8))),
          child: TabBar(controller: _tabController, labelColor: theme.colorScheme.primary, unselectedLabelColor: Colors.grey[600], indicatorColor: profileAccentColor, indicatorWeight: 3.0, isScrollable: false, tabAlignment: TabAlignment.fill, labelPadding: EdgeInsets.symmetric(horizontal: 4.0),
            tabs: const [
              Tab(icon: Icon(Icons.timeline_outlined, size: tabIconSize), text: "Activity"), Tab(icon: Icon(Icons.push_pin_outlined, size: tabIconSize), text: "Pins"),
              Tab(icon: Icon(Icons.swap_horiz_outlined, size: tabIconSize), text: "For Trade"), Tab(icon: Icon(Icons.favorite_border_outlined, size: tabIconSize), text: "Wishlist"),
              Tab(icon: Icon(Icons.emoji_events_outlined, size: tabIconSize), text: "Trophies"), 
            ],
          ),
        ),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _buildActivityTab(context, theme), _buildPinsTab(context, theme),
          _buildContentPlaceholder("For Trade - Coming Soon!", Icons.swap_horiz, theme),
          _buildContentPlaceholder("My Wishlist - Coming Soon!", Icons.favorite_border_outlined, theme),
          _buildTrophiesTab(context, theme), 
        ])),
      ]),
    );
  }

  Widget _buildFixedHeader(BuildContext context, ThemeData theme, double statusBarHeight) { 
    final double approxHeaderContentHeight = coverPhotoHeight + (avatarRadius * 2 * (1 - avatarOverlap/avatarRadius)) + 30;
    final double loadingErrorStateHeight = statusBarHeight + approxHeaderContentHeight;
    if (_isLoadingProfile && _userProfile == null) return SizedBox(height: loadingErrorStateHeight, child: const Center(child: CircularProgressIndicator()));
    if (_profileError != null && _userProfile == null) return Container(padding: EdgeInsets.only(top: statusBarHeight + 20, left: 16, right: 16, bottom: 20), height: loadingErrorStateHeight, alignment: Alignment.center, child: Text(_profileError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center));
    if (_userProfile == null) return Container(padding: EdgeInsets.only(top: statusBarHeight + 20, left: 16, right: 16, bottom: 20), height: loadingErrorStateHeight, alignment: Alignment.center, child: Text("Profile not available.", style: TextStyle(color: Colors.grey[700], fontSize: 16), textAlign: TextAlign.center));
    ImageProvider? coverImgProvider = (_userProfile!.coverPhotoUrl != null && _userProfile!.coverPhotoUrl!.isNotEmpty) ? NetworkImage(_userProfile!.coverPhotoUrl!) : null;
    ImageProvider? avatarImgProvider = (_userProfile!.avatarUrl != null && _userProfile!.avatarUrl!.isNotEmpty) ? NetworkImage(_userProfile!.avatarUrl!) : null;
    double usernameLeftOffset = 16.0 + (avatarRadius + avatarBorderWidth) * 2 + 12.0;
    return Container(padding: EdgeInsets.only(top: statusBarHeight), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: coverPhotoHeight + avatarRadius - avatarOverlap, child: Stack(clipBehavior: Clip.none, children: <Widget>[
        Positioned(top: 0, left: 0, right: 0, height: coverPhotoHeight, child: Container(decoration: BoxDecoration(color: Colors.grey[300], image: coverImgProvider != null ? DecorationImage(image: coverImgProvider, fit: BoxFit.cover) : null), child: coverImgProvider == null ? Icon(Icons.landscape_outlined, size: 70, color: Colors.grey[400]) : null)),
        Positioned(top: 8.0, left: 8.0, child: InkWell(onTap: () { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }, customBorder: const CircleBorder(), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 3.0, offset: const Offset(0,1))]), child: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.primary, size: 18)))),
        if (_isCurrentUserProfile) Positioned(top: 8.0, right: 8.0, child: InkWell(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => _fetchUserProfile()); }, customBorder: const CircleBorder(), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle), child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20)))),
        Positioned(top: coverPhotoHeight - avatarRadius - avatarOverlap, left: 16.0, child: Container(padding: const EdgeInsets.all(avatarBorderWidth), decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6.0, offset: const Offset(0, 3))]), child: CircleAvatar(radius: avatarRadius, backgroundColor: Colors.grey[400], backgroundImage: avatarImgProvider, child: avatarImgProvider == null ? Icon(Icons.person_outline, size: avatarRadius * 0.8, color: Colors.white70) : null))),
        Positioned(top: coverPhotoHeight - avatarOverlap - (avatarRadius * 0.45), left: usernameLeftOffset, right: 0, height: (avatarRadius + avatarBorderWidth) * 2, child: Row(children: [
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_userProfile!.username ?? 'N/A', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_userProfile!.fullName != null && _userProfile!.fullName!.isNotEmpty) ...[const SizedBox(height: 1.0), Text(_userProfile!.fullName!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)],
          ])),
          Container(padding: const EdgeInsets.only(right: 12.0, left: 8.0), alignment: Alignment.centerRight, child: _isCurrentUserProfile ? IconButton(icon: Icon(Icons.edit_outlined, color: profileAccentColor, size: 22), tooltip: "Edit Profile", constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())).then((_) => _fetchUserProfile())) : _isLoadingFollowStatus ? Container(width: 80, height: 30, alignment: Alignment.center, child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(profileAccentColor)))) : _isFollowing ? OutlinedButton(onPressed: _toggleFollow, style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[400]!), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Following')) : ElevatedButton(onPressed: _toggleFollow, style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Follow'))),
        ])),
      ])),
      Container(padding: EdgeInsets.only(top: avatarOverlap + 2.0, left: 16.0, right: 16.0, bottom: 8.0), alignment: Alignment.centerLeft, child: Text((_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty) ? _userProfile!.bio! : (_isCurrentUserProfile ? "No bio yet. Tap the edit icon above to add one!" : "No bio available."), style: theme.textTheme.bodyMedium?.copyWith(height: 1.3, color: (_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty) ? Colors.grey[800] : Colors.grey[500], fontStyle: (_userProfile!.bio != null && _userProfile!.bio!.isNotEmpty) ? FontStyle.normal : FontStyle.italic, fontSize: 13.5))),
    ]));
  }

  Widget _buildActivityTab(BuildContext context, ThemeData theme) { 
    if (_isLoadingActivity) return const Center(child: CircularProgressIndicator());
    if (_activityError != null) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_activityError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)));
    return Column(children: [
      if (_isCurrentUserProfile) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: ElevatedButton.icon(icon: const Icon(Icons.add_comment_outlined, size: 20), label: const Text("Create Post"), style: ElevatedButton.styleFrom(backgroundColor: profileAccentColor, foregroundColor: Colors.black87, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create post functionality coming soon!"))))),
      if (_userActivity.isEmpty) Expanded(child: _buildContentPlaceholder("No activity yet.", Icons.history_toggle_off_outlined, theme, message: _isCurrentUserProfile ? "Your posts will appear here." : "This user hasn't posted anything yet."))
      else Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0), itemCount: _userActivity.length, itemBuilder: (context, index) {
        final post = _userActivity[index];
        return ActivityPostCard(post: post, onLike: () => setState(() { post.isLikedByCurrentUser = !post.isLikedByCurrentUser; post.isLikedByCurrentUser ? post.likesCount++ : post.likesCount--; }), onComment: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comment action coming soon!"))), onShare: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Share action coming soon!"))));
      })),
    ]);
  }
  Widget _buildPinsTab(BuildContext context, ThemeData theme) { 
    if (_isLoadingPins) return const Center(child: CircularProgressIndicator());
    if (_pinsError != null) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_pinsError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)));
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: ToggleButtons(isSelected: [_pinsViewMode == PinsViewMode.all, _pinsViewMode == PinsViewMode.sets], onPressed: (int index) => setState(() => _pinsViewMode = index == 0 ? PinsViewMode.all : PinsViewMode.sets), borderRadius: BorderRadius.circular(8.0), selectedColor: Colors.white, color: theme.colorScheme.primary, fillColor: theme.colorScheme.primary, constraints: BoxConstraints(minHeight: 36.0, minWidth: (MediaQuery.of(context).size.width - 48) / 2), children: const <Widget>[Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('All Pins')), Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('Sets'))])),
      if (_pinsViewMode == PinsViewMode.all) ...[
        if (_userPins.isEmpty) Expanded(child: _buildContentPlaceholder("No pins yet!", Icons.push_pin_outlined, theme, message: _isCurrentUserProfile ? "You haven't added any pins yet." : "This user has no pins."))
        else Expanded(child: GridView.builder(padding: const EdgeInsets.all(12.0), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.75), itemCount: _userPins.length, itemBuilder: (context, index) {
          final pin = _userPins[index];
          return Card(elevation: 2.0, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 5, child: Stack(fit: StackFit.expand, children: [
              (pin.imageUrl != null && pin.imageUrl!.isNotEmpty) ? Image.network(pin.imageUrl!, fit: BoxFit.cover, loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null, strokeWidth: 2.0)), errorBuilder: (ctx, err, st) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image_outlined, size: 30, color: Colors.grey[400]))) : Container(color: Colors.grey[200], child: Icon(Icons.image_not_supported_outlined, size: 30, color: Colors.grey[400])),
              if (pin.status == PinStatus.forTrade) Positioned(top: 4.0, right: 4.0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0), decoration: BoxDecoration(color: Colors.orange.shade700.withOpacity(0.85), borderRadius: BorderRadius.circular(4.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: Offset(0,1))]), child: Text(pin.statusDisplay, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 5.0), child: Text(pin.title ?? 'Unnamed Pin', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.2))),
          ]));
        })),
      ] else ...[Expanded(child: _buildContentPlaceholder("Sets - Coming Soon!", Icons.collections_bookmark_outlined, theme, message: "Organize your pins into sets here."))]
    ]);
  }

  Widget _buildTrophiesTab(BuildContext context, ThemeData theme) {
    if (_isLoadingAchievements) return const Center(child: CircularProgressIndicator());
    if (_achievementsError != null) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_achievementsError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)));
    final Set<String> unlockedIds = _unlockedAchievements.map((ua) => ua.achievementId).toSet();
    if (allAchievements.isEmpty) return _buildContentPlaceholder("No Trophies Defined", Icons.emoji_events_outlined, theme, message: "Check back later for new challenges!");
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 0.85),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final achievement = allAchievements[index];
        final bool isUnlocked = unlockedIds.contains(achievement.id);
        return _buildAchievementCard(context, theme, achievement, isUnlocked);
      },
    );
  }

  Widget _buildAchievementCard(BuildContext context, ThemeData theme, Achievement achievement, bool isUnlocked) {
    final Color iconColor = isUnlocked ? achievement.iconColor : Colors.grey.shade400;
    final Color cardBackgroundColor = isUnlocked ? achievement.backgroundColor : Colors.grey.shade200;
    final Color textColor = isUnlocked ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87) : Colors.grey.shade600; 

    return Card(
      elevation: isUnlocked ? 3.0 : 1.0,
      color: cardBackgroundColor.withOpacity(isUnlocked ? 1.0 : 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(achievement.iconData, size: 36, color: iconColor),
            const SizedBox(height: 8.0),
            Text(
              achievement.name, textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: textColor, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 4.0),
              Text(
                achievement.description, textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, color: Colors.grey.shade500),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildContentPlaceholder(String text, IconData icon, ThemeData theme, {String? message}) { 
     return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 52, color: Colors.grey[400]), const SizedBox(height: 18),
        Text(text, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
        if (message != null) ...[const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]))]
    ])));
  }
}

class ActivityPostCard extends StatelessWidget { 
  final ActivityPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ActivityPostCard({super.key, required this.post, required this.onLike, required this.onComment, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = formatTimeAgo(post.createdAt);
    return Card(elevation: 2.0, margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [GestureDetector(onTap: () { if (post.userId.isNotEmpty) {Navigator.push(context,MaterialPageRoute(builder: (context) => UserProfilePage(profileUserId: post.userId), settings: const RouteSettings(name: MainAppShell.userProfileRouteName)));}}, child: CircleAvatar(radius: 20, backgroundColor: Colors.grey[300], backgroundImage: (post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty) ? NetworkImage(post.authorAvatarUrl!) : null, child: (post.authorAvatarUrl == null || post.authorAvatarUrl!.isEmpty) ? const Icon(Icons.person, size: 22, color: Colors.white) : null)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post.authorUsername ?? 'User', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)), Text(timeAgo, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]))]))]),
      const SizedBox(height: 12), Text(post.content, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4)), 
      if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(post.imageUrl!, width: double.infinity, fit: BoxFit.cover))],
      const SizedBox(height: 12),
      if (post.likesCount > 0 || post.commentsCount > 0) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [if (post.likesCount > 0) ...[Icon(Icons.thumb_up_alt_rounded, size: 14, color: theme.colorScheme.primary), const SizedBox(width: 4), Text("${post.likesCount}", style: theme.textTheme.bodySmall), const SizedBox(width: 12)], if (post.commentsCount > 0) Text("${post.commentsCount} Comments", style: theme.textTheme.bodySmall)])),
      Divider(height: 1, color: Colors.grey[300]), Padding(padding: const EdgeInsets.only(top: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_actionButton(context, icon: post.isLikedByCurrentUser ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, label: "Like", color: post.isLikedByCurrentUser ? theme.colorScheme.primary : Colors.grey[700], onPressed: onLike), _actionButton(context, icon: Icons.chat_bubble_outline_rounded, label: "Comment", color: Colors.grey[700], onPressed: onComment), _actionButton(context, icon: Icons.share_outlined, label: "Share", color: Colors.grey[700], onPressed: onShare)]))
    ])));
  }

  Widget _actionButton(BuildContext context, {required IconData icon, required String label, Color? color, required VoidCallback onPressed}) { return TextButton.icon(icon: Icon(icon, size: 20, color: color ?? Theme.of(context).iconTheme.color), label: Text(label, style: TextStyle(fontSize: 13, color: color ?? Theme.of(context).textTheme.bodyMedium?.color)), onPressed: onPressed, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap)); }
  String formatTimeAgo(DateTime dateTime) { final now = DateTime.now(); final difference = now.difference(dateTime); if (difference.inSeconds < 5) return 'just now'; if (difference.inMinutes < 1) return '${difference.inSeconds}s ago'; if (difference.inHours < 1) return '${difference.inMinutes}m ago'; if (difference.inHours < 24) return '${difference.inHours}h ago'; if (difference.inDays < 7) return '${difference.inDays}d ago'; return DateFormat('MMM d, yyyy').format(dateTime); } 
}

