// lib/screens/main_app_shell.dart
import 'package:flutter/material.dart'; // Import material for kToolbarHeight
import 'dashboard_page.dart';
import 'my_pins_page.dart';
import 'scanner_page.dart';
import 'community_page.dart';
import 'marketplace_page.dart'; // Renamed to Pin Market Page later if needed
import '../theme/app_colors.dart';

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  // List of the pages for the main sections (excluding Scanner)
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardPage(),    // Corresponds to 'Dashboard' icon
    MyPinsPage(),       // Corresponds to 'My Pins' icon
    CommunityPage(),    // Corresponds to 'Community' icon
    MarketplacePage(),  // Corresponds to 'Pin Market' icon
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onScannerButtonPressed() {
    print('Scanner FAB tapped!');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
  }

  void _onTopIconPressed(String iconName) {
    print('$iconName icon pressed!');
    // TODO: Navigation
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTopPadding = MediaQuery.of(context).padding.top;

    // Define Heights
    const double standardAppBarHeight = kToolbarHeight;
    const double extraAppBarHeight = 24.0;
    const double totalAppBarAreaHeight = standardAppBarHeight + extraAppBarHeight;
    const double searchBarHeight = 48.0;

    // Define the custom color from hex
    const Color customAppBarColor = Color(0xFF62a3f7);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // --- Content Area ---
          Positioned.fill(
            top: safeAreaTopPadding + totalAppBarAreaHeight + (searchBarHeight / 2) + 8.0,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() { _selectedIndex = index; });
              },
              children: _widgetOptions, // Use the updated list
            ),
          ),

          // --- Manual AppBar Background ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: safeAreaTopPadding + totalAppBarAreaHeight,
            child: Container(
              color: customAppBarColor,
            ),
          ),

          // --- AppBar Content (Title and Actions) ---
          Positioned(
            top: safeAreaTopPadding,
            left: 0,
            right: 0,
            height: totalAppBarAreaHeight,
            child: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                 _getAppBarTitle(_selectedIndex), // Updated title lookup
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              actions: [
                 // --- Trophy Icon ---
                 IconButton(
                    icon: const Icon(Icons.emoji_events_outlined), // Trophy icon
                    tooltip: 'Achievements',
                    onPressed: () => _onTopIconPressed('Achievements'),
                 ),
                 // --- Notification Icon ---
                 IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => _onTopIconPressed('Notifications'),
                 ),
                 // --- Message Icon ---
                 IconButton(
                    icon: const Icon(Icons.message_outlined),
                    tooltip: 'Messages',
                    onPressed: () => _onTopIconPressed('Messages'),
                 ),
                 // --- Profile Icon ---
                 IconButton(
                    icon: const CircleAvatar(radius: 14, backgroundColor: AppColors.booPurple, child: Icon(Icons.person, size: 18, color: Colors.white)),
                    tooltip: 'Profile',
                    onPressed: () => _onTopIconPressed('Profile')
                 ),
                 const SizedBox(width: 8),
              ],
            ),
          ),

          // --- Overlapping Search Bar ---
          Positioned(
            top: safeAreaTopPadding + totalAppBarAreaHeight - (searchBarHeight / 2),
            left: 16.0,
            right: 16.0,
            height: searchBarHeight,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(searchBarHeight / 2),
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
                    onPressed: () { print("Filter tapped"); },
                    tooltip: 'Filter',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 5.0),
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
              ),
            ),
          ),
        ],
      ),

      // --- Floating Action Button (Scanner) ---
      floatingActionButton: FloatingActionButton(
        onPressed: _onScannerButtonPressed,
        tooltip: 'Scan Pin',
        backgroundColor: customAppBarColor, // Use the blue color
        foregroundColor: Colors.white,
        elevation: 4.0,
        // *** UPDATED SHAPE WITH BORDER ***
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 2.0), // Add white outline
        ),
        // *** UPDATED ICON WITH SIZE ***
        child: const Icon(
          Icons.camera,
          size: 30.0, // Increased icon size (adjust as needed)
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- Bottom App Bar ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8.0,
        // Optional: Explicitly set height if needed, otherwise it adjusts to padding
        // height: 50.0, // Example: Try setting a fixed height
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // *** UPDATED NAV ITEMS ***
            _buildBottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', index: 0),
            _buildBottomNavItem(icon: Icons.style_outlined, activeIcon: Icons.style, label: 'My Pins', index: 1),
            const SizedBox(width: 48), // Notch placeholder
            _buildBottomNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Community', index: 2),
            _buildBottomNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Pin Market', index: 3),
          ],
        ),
      ),
    );
  }

  // Helper method to build individual BottomAppBar items
  Widget _buildBottomNavItem({required IconData icon, IconData? activeIcon, required String label, required int index}) {
     final bool isSelected = (index == _selectedIndex);
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final selectedIcon = activeIcon ?? icon;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        customBorder: const CircleBorder(),
        child: Padding(
          // *** FURTHER REDUCED PADDING ***
          padding: const EdgeInsets.symmetric(vertical: 1.0), // Reduced vertical padding more
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(isSelected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 1), // Keep minimal space
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

 // Helper function to get AppBar title based on selected index
  String _getAppBarTitle(int index) {
    // *** UPDATED TITLES ***
     switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'My Pins';
      case 2: return 'Community';
      case 3: return 'Pin Market'; // Changed title
      default: return 'PinSpace';
    }
  }
}
