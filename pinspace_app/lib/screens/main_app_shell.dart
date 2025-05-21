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
import 'user_profile_page.dart'; 
import 'search_results_page.dart'; 
import 'pin_catalog_page.dart'; // <<--- UNCOMMENTED and assuming this file exists

final supabase = Supabase.instance.client;

const Color appPrimaryColor = Color(0xFF30479b); 

// Enum for Popup Menu Actions
enum ProfileMenuAction { myProfile, myMarket, myTrophies, settings, logout }


class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});
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

  static final List<Widget> _widgetOptions = <Widget>[
    DashboardPage(),
    MyPinsPage(),
    CommunityPage(),
    MarketplacePage(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfileAvatar();

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userUpdated) {
        _fetchUserProfileAvatar();
      }
    });

    _searchController.addListener(() {
      if (mounted) {
        setState(() {}); 
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
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleProfileMenuSelection(ProfileMenuAction action) {
    switch (action) {
      case ProfileMenuAction.myProfile:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const UserProfilePage(initialTabIndex: 0), 
                settings: const RouteSettings(name: MainAppShell.userProfileRouteName),
            )
        ).then((_) {
          if (mounted) {
            setState(() {});
          }
        });
        break;
      case ProfileMenuAction.myMarket:
        if (_selectedIndex != 3) { 
          _onItemTapped(3);
        }
        break;
      case ProfileMenuAction.myTrophies:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserProfilePage(initialTabIndex: 4), 
            settings: const RouteSettings(name: MainAppShell.userProfileRouteName),
          )
        ).then((_){
           if (mounted) {
            setState(() {});
          }
        });
        break;
      case ProfileMenuAction.settings:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()))
        .then((_){
           if (mounted) {
            _fetchUserProfileAvatar(); 
            setState(() {}); 
          }
        });
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
    if (iconName == 'Catalog') {
        // <<--- MODIFIED: Navigate to PinCatalogPage --- >>
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PinCatalogPage()));
    } else if (iconName == 'Notifications') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications page coming soon!")));
    } else if (iconName == 'Messages') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Messages page coming soon!")));
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsPage(searchQuery: query.trim()),
        ),
      ).then((_) {
          if (mounted) {
            setState(() {}); 
          }
        });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter something to search.")),
      );
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    _searchController.removeListener(() { if (mounted) setState(() {}); }); 
    _searchController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeAreaTopPadding = MediaQuery.of(context).padding.top;

    const double standardAppBarHeight = kToolbarHeight;
    const double extraAppBarHeight = 24.0; 
    const double totalAppBarAreaHeight = standardAppBarHeight + extraAppBarHeight;
    const double searchBarHeight = 48.0;

    const Color customAppBarColor = appPrimaryColor;

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
    final bool isUserProfilePageActive = currentRoute?.settings.name == MainAppShell.userProfileRouteName;
    
    bool isSearchResultsPageActive = false;
    if (currentRoute is MaterialPageRoute) {
        try {
           final widget = currentRoute.builder(context);
           if (widget is SearchResultsPage) {
             isSearchResultsPageActive = true;
           }
        } catch (e) {
          print("Error checking route type for SearchResultsPage: $e");
        }
    }
    
    // <<--- NEW: Check if PinCatalogPage is active --- >>
    bool isPinCatalogPageActive = false;
    if (currentRoute is MaterialPageRoute) {
      try {
        final widget = currentRoute.builder(context);
        if (widget is PinCatalogPage) { // Assuming PinCatalogPage is the class name
          isPinCatalogPageActive = true;
        }
      } catch (e) {
        print("Error checking route type for PinCatalogPage: $e");
      }
    }

    // <<--- MODIFIED: Shell AppBar hidden if UserProfilePage OR PinCatalogPage is active --- >>
    final bool shouldShowShellAppBarAndSearch = !isUserProfilePageActive && !isSearchResultsPageActive && !isPinCatalogPageActive;
    
    final double pageViewTopWhenShellAppBarVisible = safeAreaTopPadding + totalAppBarAreaHeight + (searchBarHeight / 2) + 8.0;
    final double pageViewTop = shouldShowShellAppBarAndSearch
        ? pageViewTopWhenShellAppBarVisible
        : 0; 

    return Scaffold(
      extendBodyBehindAppBar: true, 
      body: Stack(
        children: [
          Positioned.fill(
            top: pageViewTop,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() { _selectedIndex = index; });
              },
              children: _widgetOptions,
            ),
          ),

          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: 0, left: 0, right: 0,
              height: safeAreaTopPadding + totalAppBarAreaHeight, 
              child: Container(color: customAppBarColor),
            ),

          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: safeAreaTopPadding, left: 0, right: 0,
              height: totalAppBarAreaHeight, 
              child: AppBar(
                backgroundColor: Colors.transparent, 
                foregroundColor: Colors.white, 
                elevation: 0, 
                title: Text(_getAppBarTitle(_selectedIndex), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.auto_stories_outlined), 
                    tooltip: 'Pin Catalog',
                    onPressed: () => _onTopIconPressed('Catalog'),
                  ),
                  IconButton(icon: const Icon(Icons.notifications_none_outlined), tooltip: 'Notifications', onPressed: () => _onTopIconPressed('Notifications')),
                  IconButton(icon: const Icon(Icons.message_outlined), tooltip: 'Messages', onPressed: () => _onTopIconPressed('Messages')),
                  PopupMenuButton<ProfileMenuAction>(
                    onSelected: _handleProfileMenuSelection,
                    offset: const Offset(0, kToolbarHeight - 10), 
                    icon: _isLoadingAvatar 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : CircleAvatar(
                            radius: 16, 
                            backgroundColor: Colors.white.withOpacity(0.3), 
                            backgroundImage: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty ? NetworkImage(_userAvatarUrl!) : null,
                            child: (_userAvatarUrl == null || _userAvatarUrl!.isEmpty) ? const Icon(Icons.person_outline, size: 22, color: Colors.white) : null,
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
                        value: ProfileMenuAction.myTrophies,
                        child: ListTile(leading: Icon(Icons.emoji_events_outlined), title: Text('My Trophies')),
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
                  const SizedBox(width: 8),
                ],
              ),
            ),
          
          if (shouldShowShellAppBarAndSearch)
            Positioned(
              top: safeAreaTopPadding + totalAppBarAreaHeight - (searchBarHeight / 2), 
              left: 16.0, right: 16.0, height: searchBarHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor, 
                  borderRadius: BorderRadius.circular(searchBarHeight / 2), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users, pins, etc...',
                    hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.8), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: Icon(Icons.clear, color: theme.iconTheme.color?.withOpacity(0.8), size: 20), onPressed: () => _searchController.clear(), tooltip: 'Clear search')
                        : IconButton(icon: Icon(Icons.filter_list, color: theme.iconTheme.color?.withOpacity(0.8), size: 20), onPressed: () { print("Filter tapped"); }, tooltip: 'Filter'),
                    border: InputBorder.none, 
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 5.0), 
                  ),
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                  onSubmitted: _onSearchSubmitted,
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onScannerButtonPressed, tooltip: 'Scan Pin', backgroundColor: customAppBarColor, 
        foregroundColor: Colors.white, elevation: 4.0, shape: const CircleBorder(),
        child: const Icon(Icons.camera, size: 30.0),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), notchMargin: 8.0, elevation: 8.0,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <Widget>[
          _buildBottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', index: 0),
          _buildBottomNavItem(icon: Icons.style_outlined, activeIcon: Icons.style, label: 'My Pins', index: 1),
          const SizedBox(width: 48), 
          _buildBottomNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Community', index: 2),
          _buildBottomNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Pin Market', index: 3),
        ]),
      ),
    );
  }

  Widget _buildBottomNavItem({required IconData icon, IconData? activeIcon, required String label, required int index}) {
    final bool isSelected = (index == _selectedIndex);
    final color = isSelected ? appPrimaryColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final selectedIcon = activeIcon ?? icon;
    return Expanded(child: InkWell(onTap: () => _onItemTapped(index), customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[ Icon(isSelected ? selectedIcon : icon, color: color, size: 24), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)]))));
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'My Collection'; 
      case 2: return 'Community';
      case 3: return 'Pin Market';
      default: return 'PinSpace';
    }
  }
}
