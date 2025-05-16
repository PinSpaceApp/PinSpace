// lib/screens/search_results_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart'; // Assuming your Profile model
import 'user_profile_page.dart'; // To navigate to user profiles
import 'main_app_shell.dart'; // Import MainAppShell for the route name

final supabase = Supabase.instance.client;

class SearchResultsPage extends StatefulWidget {
  final String searchQuery;

  const SearchResultsPage({super.key, required this.searchQuery});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<Profile> _searchResults = [];
  // Removed _followStatus map and related logic
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (_currentUserId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "You must be logged in to search users.";
        });
      }
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select() // Selects all columns, ensure 'username' and 'full_name' are populated in your DB
          .or('username.ilike.%${widget.searchQuery}%,full_name.ilike.%${widget.searchQuery}%')
          .not('id', 'eq', _currentUserId!) 
          .limit(20); 

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      _searchResults = data.map((map) => Profile.fromMap(map as Map<String, dynamic>)).toList();
      
      // Removed call to _fetchFollowStatuses as follow button is removed from this page

    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() {
          _error = "Failed to search users: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Removed _fetchFollowStatuses method
  // Removed _toggleFollow method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Results for "${widget.searchQuery}"'),
        elevation: 1.0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No users found matching your search.', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final profile = _searchResults[index];

        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundImage: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                ? const Icon(Icons.person, size: 25)
                : null,
          ),
          title: Text(
            profile.username ?? 'N/A', // Check your Profile model and Supabase data for 'username'
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: (profile.fullName != null && profile.fullName!.isNotEmpty)
              ? Text(
                  profile.fullName!, // Check your Profile model and Supabase data for 'fullName'
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          // Removed trailing ElevatedButton (Follow/Unfollow button)
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(profileUserId: profile.id),
                settings: const RouteSettings(name: MainAppShell.userProfileRouteName) 
              ),
            );
            // No need to call _fetchFollowStatuses here anymore
          },
        );
      },
    );
  }
}
