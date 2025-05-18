// lib/screens/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart'; // Assuming your Profile model is here

import 'my_pins_page.dart' hide Pin, PinStatus; 
import 'user_profile_page.dart'; // Imports UserProfilePage, Pin, PinStatus

import 'scanner_page.dart'; 
import 'marketplace_page.dart'; 
import 'main_app_shell.dart'; 

final supabase = Supabase.instance.client;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Profile? _userProfile;
  bool _isLoadingProfile = true;
  String? _profileError;

  int _myCollectionCount = 0;
  int _forTradeCount = 0;
  int _wishlistCount = 0; 
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _isLoadingStats = true;
      _profileError = null;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingStats = false;
          _profileError = "Not logged in.";
        });
      }
      return;
    }

    try {
      final profileData = await supabase
          .from('profiles')
          .select() 
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData != null) {
        // IMPORTANT: Ensure your Profile.fromMap in lib/models/profile.dart
        // handles potentially null values for username, full_name, etc.,
        // by casting them as String? if the model fields are nullable.
        // e.g., username: map['username'] as String?,
        _userProfile = Profile.fromMap(profileData);
      } else {
        _profileError = "Profile not found.";
        _userProfile = null; 
      }
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }

      final pinsResponse = await supabase
          .from('pins')
          .select('id, status, user_id, name') // Ensure user_id and name are selected
          .eq('user_id', user.id);
      
      if (!mounted) return;

      final List<dynamic> pinsData = pinsResponse as List<dynamic>;
      _myCollectionCount = pinsData.length; 

      _forTradeCount = pinsData.where((pinMapDynamic) {
          if (pinMapDynamic is Map<String, dynamic>) {
            // Ensure Pin.fromMap handles potentially null 'name' or 'status' from DB
            final pin = Pin.fromMap(pinMapDynamic); 
            return pin.status == PinStatus.forTrade;
          }
          return false;
      }).length;

      _wishlistCount = 0; 
      try {
        final wishlistResponse = await supabase
            .from('wishlist') 
            .select() 
            .eq('user_id', user.id)
            .count(CountOption.exact); 

        if (mounted) {
          _wishlistCount = wishlistResponse.count ?? 0;
        }
      } catch (e) {
        print("Error fetching wishlist count: $e");
        // If 'wishlist' table doesn't exist, this will be caught.
        // _wishlistCount remains 0.
      }

      if (mounted) {
        setState(() => _isLoadingStats = false);
      }

    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingStats = false;
          _profileError = "Failed to load dashboard data. ${e.toString()}"; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: ListView( 
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            _buildGreetingSection(theme),
            const SizedBox(height: 24.0),

            Text("Your Pin Stats", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12.0),
            _isLoadingStats
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                : _buildStatsGrid(),
            const SizedBox(height: 24.0),

            Text("Quick Actions", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12.0),
            _buildQuickActionsGrid(context, theme),
            const SizedBox(height: 24.0),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection(ThemeData theme) {
    if (_isLoadingProfile) {
      return const SizedBox(height: 30); 
    }
    
    String usernameDisplay = "User"; // Default
    if (_userProfile != null) {
        if (_userProfile!.username != null && _userProfile!.username!.isNotEmpty) {
            usernameDisplay = _userProfile!.username!;
        } else if (_userProfile!.fullName != null && _userProfile!.fullName!.isNotEmpty) {
            // Fallback to full name if username is not available but full name is
            usernameDisplay = _userProfile!.fullName!;
        }
    }

    if (_profileError != null && _userProfile == null) {
      // If there was an error and profile is null, show a generic welcome.
      return Text("Welcome to PinSpace!", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600));
    }
    
    return Text(
      "Welcome back, $usernameDisplay!",
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2, 
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
      mainAxisSpacing: 12.0,
      crossAxisSpacing: 12.0,
      // <<--- FIX: Slightly increased childAspectRatio for _StatCard --- >>
      childAspectRatio: 2.3, // Was 2.2, making cards slightly taller
      children: <Widget>[
        _StatCard(title: "My Collection", value: _myCollectionCount.toString(), icon: Icons.inventory_2_outlined, color: Colors.blue.shade400),
        _StatCard(title: "For Trade", value: _forTradeCount.toString(), icon: Icons.swap_horiz_outlined, color: Colors.orange.shade400),
        _StatCard(title: "Wishlist", value: _wishlistCount.toString(), icon: Icons.favorite_border_outlined, color: Colors.pink.shade400),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.0,
      crossAxisSpacing: 12.0,
      childAspectRatio: 1.8, 
      children: <Widget>[
        _ActionCard(
          title: "Add New Pin",
          icon: Icons.add_circle_outline,
          color: theme.colorScheme.primaryContainer,
          iconColor: theme.colorScheme.onPrimaryContainer,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
          },
        ),
        _ActionCard(
          title: "My Collection",
          icon: Icons.style_outlined,
           color: theme.colorScheme.secondaryContainer,
           iconColor: theme.colorScheme.onSecondaryContainer,
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPinsPage()));
          },
        ),
        _ActionCard(
          title: "Pin Market",
          icon: Icons.storefront_outlined,
          color: theme.colorScheme.tertiaryContainer,
          iconColor: theme.colorScheme.onTertiaryContainer,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketplacePage()));
          },
        ),
        _ActionCard(
          title: "My Profile",
          icon: Icons.person_outline,
          color: theme.colorScheme.surfaceVariant,
          iconColor: theme.colorScheme.onSurfaceVariant,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserProfilePage(), 
                settings: const RouteSettings(name: MainAppShell.userProfileRouteName) 
              )
            );
          },
        ),
      ],
    );
  }
}

// Helper widget for Stat Cards
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Slightly reduced vertical padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, 
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Flexible( 
                  child: Text(
                    title, 
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), // Changed from labelLarge
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                Icon(icon, size: 18.0, color: color), 
              ],
            ),
            const SizedBox(height: 2), // Further reduced space
            FittedBox(
              fit: BoxFit.scaleDown, 
              child: Text(
                value, 
                style: theme.textTheme.headlineSmall?.copyWith( // Changed from headlineMedium
                  fontWeight: FontWeight.bold, 
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for Action Cards
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 36.0, color: iconColor),
              const SizedBox(height: 10.0),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
