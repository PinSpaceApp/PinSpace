// lib/screens/community_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/profile.dart'; // Assuming your Profile model
import 'user_profile_page.dart' show UserProfilePage; // For navigation
import 'main_app_shell.dart'; // For MainAppShell.userProfileRouteName

final supabase = Supabase.instance.client;

// Re-defining ActivityPost and ActivityPostCard here for self-containment.
// Ideally, these would be in their own model/widget files if used in multiple places.

class ActivityPost {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? imageUrl; // Optional image for the post
  int likesCount;
  int commentsCount;
  bool isLikedByCurrentUser;

  // For displaying author info
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? authorFullName;


  ActivityPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByCurrentUser = false,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorFullName,
  });

  factory ActivityPost.fromMap(Map<String, dynamic> map, {
    String? authorUsername,
    String? authorAvatarUrl,
    String? authorFullName,
  }) {
    return ActivityPost(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      imageUrl: map['image_url'] as String?,
      likesCount: map['likes_count'] as int? ?? 0,
      commentsCount: map['comments_count'] as int? ?? 0,
      // TODO: isLikedByCurrentUser would need another query based on logged-in user
      isLikedByCurrentUser: false, 
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorFullName: authorFullName,
    );
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<ActivityPost> _feedPosts = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  // Map<String, Profile> _fetchedProfiles = {}; // Cache for author profiles - removed as we join now

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    if (_currentUserId != null) {
      _fetchCommunityFeed();
    } else {
      setState(() {
        _isLoading = false;
        _error = "You need to be logged in to see the community feed.";
      });
    }
  }

  Future<void> _fetchCommunityFeed() async {
    if (!mounted || _currentUserId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Get IDs of users the current user is following
      final followedUsersResponse = await supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', _currentUserId!);

      if (!mounted) return;
      
      final List<String> followedUserIds = (followedUsersResponse as List<dynamic>)
          .map((follow) => follow['following_id'] as String)
          .toList();

      if (followedUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _feedPosts = []; // No one followed, so empty feed
          });
        }
        return;
      }

      // 2. Fetch posts from these followed users (and the current user's own posts for a complete feel)
      final allUserIdsForFeed = List<String>.from(followedUserIds)..add(_currentUserId!);


      final postsResponse = await supabase
          .from('activity_posts')
          .select('*, profiles:user_id(username, avatar_url, full_name)') // Join with profiles table
          // <<--- FIX: Changed .in_ to .inFilter --- >>
          .inFilter('user_id', allUserIdsForFeed) 
          .order('created_at', ascending: false)
          .limit(50); // Limit the number of posts

      if (!mounted) return;

      final List<dynamic> postsData = postsResponse as List<dynamic>;
      final List<ActivityPost> fetchedPosts = [];

      for (var postMap in postsData) {
        final postData = postMap as Map<String, dynamic>;
        final profileData = postData['profiles'] as Map<String, dynamic>?; // Joined profile data

        fetchedPosts.add(ActivityPost.fromMap(
          postData,
          authorUsername: profileData?['username'] as String?,
          authorAvatarUrl: profileData?['avatar_url'] as String?,
          authorFullName: profileData?['full_name'] as String?,
        ));
      }
      
      if (mounted) {
        setState(() {
          _feedPosts = fetchedPosts;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error fetching community feed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load community feed. ${e.toString()}";
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }

    if (_feedPosts.isEmpty && _currentUserId != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dynamic_feed_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "Your feed is empty.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Follow other pin collectors to see their activity here or start posting your own!",
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text("Find Users to Follow"),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Use the search bar in the app header to find users!"))
                  );
                },
              )
            ],
          ),
        ),
      );
    }
    
    if (_currentUserId == null) {
         return const Center(child: Text("Please log in to view the community feed."));
    }

    return RefreshIndicator(
      onRefresh: _fetchCommunityFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _feedPosts.length,
        itemBuilder: (context, index) {
          final post = _feedPosts[index];
          return ActivityPostCard( 
            post: post,
            onLike: () { 
              print("Like tapped for post ${post.id}");
              setState(() {
                post.isLikedByCurrentUser = !post.isLikedByCurrentUser;
                post.isLikedByCurrentUser ? post.likesCount++ : post.likesCount--;
              });
            },
            onComment: () { 
              print("Comment tapped for post ${post.id}");
            },
            onShare: () { 
              print("Share tapped for post ${post.id}");
            },
          );
        },
      ),
    );
  }
}

class ActivityPostCard extends StatelessWidget {
  final ActivityPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ActivityPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = formatTimeAgo(post.createdAt);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row( 
              children: [
                GestureDetector(
                  onTap: () { 
                     if (post.userId.isNotEmpty) {
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(profileUserId: post.userId),
                            settings: const RouteSettings(name: MainAppShell.userProfileRouteName)
                          ),
                        );
                     }
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty)
                        ? NetworkImage(post.authorAvatarUrl!)
                        : null,
                    child: (post.authorAvatarUrl == null || post.authorAvatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 22, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorUsername ?? 'User', 
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (post.likesCount > 0 || post.commentsCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    if (post.likesCount > 0) ...[
                      Icon(Icons.thumb_up_alt_rounded, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text("${post.likesCount}", style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                    ],
                    if (post.commentsCount > 0) Text("${post.commentsCount} Comments", style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            Divider(height: 1, color: Colors.grey[300]),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _actionButton(context, icon: post.isLikedByCurrentUser ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, label: "Like", color: post.isLikedByCurrentUser ? theme.colorScheme.primary : Colors.grey[700], onPressed: onLike),
                  _actionButton(context, icon: Icons.chat_bubble_outline_rounded, label: "Comment", color: Colors.grey[700], onPressed: onComment),
                  _actionButton(context, icon: Icons.share_outlined, label: "Share", color: Colors.grey[700], onPressed: onShare),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, {required IconData icon, required String label, Color? color, required VoidCallback onPressed}) {
    return TextButton.icon(
      icon: Icon(icon, size: 20, color: color ?? Theme.of(context).iconTheme.color),
      label: Text(label, style: TextStyle(fontSize: 13, color: color ?? Theme.of(context).textTheme.bodyMedium?.color)),
      onPressed: onPressed,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }

  String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inSeconds < 5) return 'just now';
    if (difference.inMinutes < 1) return '${difference.inSeconds}s ago';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dateTime); // Corrected DateFormat pattern
  }
}
