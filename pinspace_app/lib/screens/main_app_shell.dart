// lib/screens/main_app_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import 'my_pins_page.dart';
import 'scanner_page.dart';
import 'community_page.dart';
import 'marketplace_page.dart';
import 'settings_page.dart';
import 'user_profile_page.dart'; // Ensure UserProfilePage is imported

final supabase = Supabase.instance.client;

const Color appPrimaryColor = Color(0xFF30479b); // Your chosen primary color

// Enum for Popup Menu Actions
enum ProfileMenuAction { myProfile, myMarket, settings, logout }


class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  // << --- NEW: Define a constant for the user profile route name --- >>
  static const String userProfileRouteName = '/user_profile_page';

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  String? _userAvatarUrl;
  bool _isLoadingAvatar = true;
  late final StreamSubscription<AuthState> _authStateSubscription;

  // Define your pages that are managed by the PageView and BottomAppBar
  static final List<Widget> _widgetOptions = <Widget>[
    DashboardPage(),
    MyPinsPage(),
    CommunityPage(),
    MarketplacePage(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfileAvatar(); // Renamed for clarity

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userUpdated) {
        _fetchUserProfileAvatar(); // Refresh avatar on auth changes
      }
    });
  }

  Future<void> _fetchUserProfileAvatar() async {
    if (mounted) {
      setState(() {
        _isLoadingAvatar = true;
      });
    }
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && data != null && data['avatar_url'] != null) {
          setState(() {
            _userAvatarUrl = data['avatar_url'] as String?;
            _isLoadingAvatar = false;
          });
        } else if (mounted) {
            setState(() {
            _userAvatarUrl = null;
            _isLoadingAvatar = false;
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _userAvatarUrl = null;
            _isLoadingAvatar = false;
          });
         }
      }
    } catch (e) {
      print('Error fetching user profile for avatar: $e');
      if (mounted) {
        setState(() {
          _userAvatarUrl = null;
          _isLoadingAvatar = false;
        });
      }
    }
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onScannerButtonPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    ).then((_) {
      if (_selectedIndex == 1 && _widgetOptions[1] is MyPinsPage) {
        // If MyPinsPage has a refresh method, you could call it here.
        // Example: (_widgetOptions[1] as MyPinsPage).refreshPins();
        // This requires MyPinsPage to expose such a method.
        // For simplicity, often a state management solution or passing a callback is used.
      }
    });
  }

  void _handleProfileMenuSelection(ProfileMenuAction action) {
    switch (action) {
      case ProfileMenuAction.myProfile:
        // << --- MODIFIED: Add RouteSettings when navigating --- >>
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const UserProfilePage(), // Assuming it takes no arguments for self-profile
                settings: const RouteSettings(name: MainAppShell.userProfileRouteName),
            )
        );
        break;
      case ProfileMenuAction.myMarket:
        if (_selectedIndex != 3) { // Assuming Marketplace is at index 3
          _onItemTapped(3);
        }
        break;
      case ProfileMenuAction.settings:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
        break;
      case ProfileMenuAction.logout:
        _handleLogout();
        break;
    }
  }

  Future<void> _handleLogout() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        // Ensure you have an '/authGate' route defined in your MaterialApp
        Navigator.of(context).pushNamedAndRemoveUntil('/authGate', (route) => false);
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to log out: $e"), backgroundColor: Colors.red),
          );
        }
    }
  }


  void _onTopIconPressed(String iconName) {
    print('$iconName icon pressed!');
    if (iconName == 'Notifications') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications page coming soon!")));
    } else if (iconName == 'Messages') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Messages page coming soon!")));
    } else if (iconName == 'Achievements') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Achievements page coming soon!")));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeAreaTopPadding = MediaQuery.of(context).padding.top;

    const double standardAppBarHeight = kToolbarHeight;
    const double extraAppBarHeight = 24.0; // For the title area below icons
    const double totalAppBarAreaHeight = standardAppBarHeight + extraAppBarHeight;
    const double searchBarHeight = 48.0;

    const Color customAppBarColor = appPrimaryColor;

    // << --- NEW LOGIC to determine if UserProfilePage is active --- >>
    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
    final bool isUserProfilePageActive = currentRoute?.settings.name == MainAppShell.userProfileRouteName;
    // The shell's custom AppBar and search bar should only be shown if UserProfilePage is NOT active.
    final bool shouldShowShellAppBarAndSearch = !isUserProfilePageActive;
    // << --- END NEW LOGIC --- >>

    // Adjust PageView top based on whether the shell's app bar is shown
    // When UserProfilePage is active, it will handle its own layout from the top.
    final double pageViewTopWhenShellAppBarVisible = safeAreaTopPadding + totalAppBarAreaHeight + (searchBarHeight / 2) + 8.0;
    final double pageViewTop = shouldShowShellAppBarAndSearch
        ? pageViewTopWhenShellAppBarVisible
        : 0; // If shell app bar is hidden, PageView is effectively behind UserProfilePage.

    return Scaffold(
      extendBodyBehindAppBar: true, // Allows body to draw behind the custom AppBar area
      body: Stack(
        children: [
          // PageView for main tab content
          Positioned.fill(
            top: pageViewTop,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() { _selectedIndex = index; });
              },
              children: _widgetOptions, // Use the static final list
            ),
          ),

          // Conditionally build the Shell's custom AppBar background
          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: safeAreaTopPadding + totalAppBarAreaHeight, // Covers status bar and custom app bar area
              child: Container(
                color: customAppBarColor,
              ),
            ),

          // Conditionally build the Shell's AppBar widget (title, actions)
          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: safeAreaTopPadding, // Position below status bar
              left: 0,
              right: 0,
              height: totalAppBarAreaHeight, // Height of the interactive AppBar part
              child: AppBar(
                backgroundColor: Colors.transparent, // Background is handled by the Container above
                foregroundColor: Colors.white, // Color for icons and text
                elevation: 0, // No shadow as it's part of a custom stack
                title: Text(
                  _getAppBarTitle(_selectedIndex),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.emoji_events_outlined),
                    tooltip: 'Achievements',
                    onPressed: () => _onTopIconPressed('Achievements'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => _onTopIconPressed('Notifications'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message_outlined),
                    tooltip: 'Messages',
                    onPressed: () => _onTopIconPressed('Messages'),
                  ),
                  PopupMenuButton<ProfileMenuAction>(
                    onSelected: _handleProfileMenuSelection,
                    offset: const Offset(0, kToolbarHeight - 10),
                    icon: _isLoadingAvatar
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                                ? NetworkImage(_userAvatarUrl!)
                                : null,
                            child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty)
                                ? const Icon(Icons.person_outline, size: 22, color: Colors.white)
                                : null,
                          ),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<ProfileMenuAction>>[
                      const PopupMenuItem<ProfileMenuAction>(
                        value: ProfileMenuAction.myProfile,
                        child: ListTile(leading: Icon(Icons.person_pin_circle_outlined), title: Text('My Profile')),
                      ),
                      const PopupMenuItem<ProfileMenuAction>(
                        value: ProfileMenuAction.myMarket,
                        child: ListTile(leading: Icon(Icons.store_mall_directory_outlined), title: Text('My Market')),
                      ),
                      const PopupMenuItem<ProfileMenuAction>(
                        value: ProfileMenuAction.settings,
                        child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings')),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<ProfileMenuAction>(
                        value: ProfileMenuAction.logout,
                        child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Log Out', style: TextStyle(color: Colors.red))),
                      ),
                    ],
                    tooltip: "Profile Options",
                  ),
                  const SizedBox(width: 8), // Padding for the last icon
                ],
              ),
            ),

          // Conditionally build the Shell's Search Bar
          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: safeAreaTopPadding + totalAppBarAreaHeight - (searchBarHeight / 2), // Overlaps bottom of AppBar area
              left: 16.0,
              right: 16.0,
              height: searchBarHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor, // Use theme's card color for search bar background
                  borderRadius: BorderRadius.circular(searchBarHeight / 2), // Fully rounded
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for something new...',
                    hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.8), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.filter_list, color: theme.iconTheme.color?.withOpacity(0.8), size: 20),
                      onPressed: () { print("Filter tapped"); }, // Placeholder action
                      tooltip: 'Filter',
                    ),
                    border: InputBorder.none, // Remove default border
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 5.0), // Adjust padding
                  ),
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onScannerButtonPressed,
        tooltip: 'Scan Pin',
        backgroundColor: customAppBarColor, // Match AppBar color
        foregroundColor: Colors.white,
        elevation: 4.0,
        shape: const CircleBorder(
          // side: BorderSide(color: Colors.white, width: 2.0), // Optional: white border
        ),
        child: const Icon(
          Icons.camera, // Changed from Icons.qr_code_scanner for a more general "scan" feel
          size: 30.0,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0, // Space for the FAB
        elevation: 8.0, // Standard elevation
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute items evenly
          children: <Widget>[
            _buildBottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', index: 0),
            _buildBottomNavItem(icon: Icons.style_outlined, activeIcon: Icons.style, label: 'My Pins', index: 1),
            const SizedBox(width: 48), // The space for the FAB notch
            _buildBottomNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Community', index: 2),
            _buildBottomNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Pin Market', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({required IconData icon, IconData? activeIcon, required String label, required int index}) {
    final bool isSelected = (index == _selectedIndex);
    final color = isSelected ? appPrimaryColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final selectedIcon = activeIcon ?? icon; // Use activeIcon if provided and selected

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        customBorder: const CircleBorder(), // Makes the ripple effect circular
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0), // Reduced vertical padding for a more compact look
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(isSelected ? selectedIcon : icon, color: color, size: 24), // Icon
              const SizedBox(height: 2), // Spacing between icon and label
              Text(
                label,
                style: TextStyle(
                  fontSize: 10, // Slightly smaller font for label
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis, // Prevent text overflow
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to get AppBar title based on selected index
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'My Collection'; // Changed from 'My Pins' for consistency with label
      case 2: return 'Community';
      case 3: return 'Pin Market';
      default: return 'PinSpace'; // Default title
    }
  }
}
