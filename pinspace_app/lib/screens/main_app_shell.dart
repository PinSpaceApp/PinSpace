// lib/screens/main_app_shell.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'my_pins_page.dart';
import 'scanner_page.dart';
import 'community_page.dart';
import 'marketplace_page.dart';
import '../theme/app_colors.dart'; // Import theme colors

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0; // Index for the currently selected tab (excluding FAB)
  final PageController _pageController = PageController(); // Controller for page view

  // List of the pages for the main sections (excluding Scanner)
  // Order matches the BottomAppBar icons
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardPage(),
    MyPinsPage(),
    // Index 2 is now handled by the FAB
    CommunityPage(),
    MarketplacePage(),
  ];

  // Handler for when a BottomAppBar item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Animate page transition
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
  }

  // Handler for the Floating Action Button (Scanner)
  void _onScannerButtonPressed() {
    print('Scanner FAB tapped!');
    // Option 1: Navigate to a dedicated Scanner Page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
    // Option 2: Show a Modal Bottom Sheet for scanning
    // showModalBottomSheet(...);
    // Option 3: Directly trigger camera if ScannerPage is simple enough
  }

  // Placeholder action for top bar icons
  void _onTopIconPressed(String iconName) {
    print('$iconName icon pressed!');
    // TODO: Navigate to Profile, Messages, or Notifications screen
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // --- Updated AppBar with Search Bar ---
      appBar: AppBar(
        elevation: 1,
        // Custom title widget containing the search bar
        title: Container(
          height: 40, // Adjust height as needed
          decoration: BoxDecoration(
            color: theme.colorScheme.surface, // Or slightly different color
            borderRadius: BorderRadius.circular(20), // Rounded corners
          ),
          child: TextField(
            // controller: _searchController, // Add controller later
            // onChanged: _handleSearch, // Add search logic later
            decoration: InputDecoration(
              hintText: 'Search pins, sets, traders...',
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.8)),
              // Optionally add a filter icon button at the end
              // suffixIcon: IconButton(
              //   icon: Icon(Icons.filter_list, color: theme.iconTheme.color?.withOpacity(0.8)),
              //   onPressed: () { /* TODO: Open filter options */ },
              // ),
              border: InputBorder.none, // Remove default border
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0), // Adjust padding
            ),
            style: TextStyle(color: theme.textTheme.bodyLarge?.color), // Use theme text color
          ),
        ),
        actions: [
          // PinPoints Display
          Padding( /* ... same as before ... */
             padding: const EdgeInsets.only(right: 8.0), child: Chip( avatar: Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 18), label: const Text( '1,234', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), ), backgroundColor: colorScheme.primaryContainer.withOpacity(0.5), labelPadding: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact, ),
          ),
          // Notification Icon
          IconButton( /* ... same as before ... */
            icon: const Icon(Icons.notifications_none), tooltip: 'Notifications', onPressed: () => _onTopIconPressed('Notifications'),
          ),
          // Message Icon
          IconButton( /* ... same as before ... */
             icon: const Icon(Icons.message_outlined), tooltip: 'Messages', onPressed: () => _onTopIconPressed('Messages'),
          ),
          // Profile Icon
          IconButton( /* ... same as before ... */
             icon: const CircleAvatar( radius: 16, backgroundColor: AppColors.booPurple, child: Icon(Icons.person, size: 18, color: Colors.white), ), tooltip: 'Profile', onPressed: () => _onTopIconPressed('Profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // --- Body Content using PageView ---
      // Allows smooth swiping between pages (optional)
      body: PageView(
        controller: _pageController,
        // Important: Update index when page is swiped
        onPageChanged: (index) {
          // Don't update state if swiping over where the FAB would be
          // This logic assumes FAB represents index 2 conceptually
          if (index < 2) { // Indices before FAB
             setState(() { _selectedIndex = index; });
          } else if (index >= 2) { // Indices after FAB
             setState(() { _selectedIndex = index + 1; }); // Adjust index because FAB isn't a page
          }
        },
        children: _widgetOptions, // Use the list WITHOUT the ScannerPage
      ),

      // --- Floating Action Button (Scanner) ---
      floatingActionButton: FloatingActionButton(
        onPressed: _onScannerButtonPressed,
        tooltip: 'Scan Pin',
        backgroundColor: AppColors.mikeLime, // Use a distinct theme color
        foregroundColor: Colors.black,      // Contrasting icon color
        elevation: 2.0,
        child: const Icon(Icons.qr_code_scanner), // Scanner icon
        // shape: const CircleBorder(), // Default is circular
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Docks FAB in the center

      // --- Bottom App Bar ---
      // Holds the other navigation items around the FAB
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Creates the notch for the FAB
        notchMargin: 6.0, // Space around the FAB notch
        // color: theme.colorScheme.surface, // Use theme surface color
        // elevation: 8.0, // Optional elevation
        child: Row(
          // Align icons around the center notch
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Distributes space
          children: <Widget>[
            _buildBottomNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
            _buildBottomNavItem(icon: Icons.style_outlined, label: 'My Pins', index: 1),
            const SizedBox(width: 40), // Placeholder for the FAB notch area
            _buildBottomNavItem(icon: Icons.people_outline, label: 'Community', index: 2), // Note index is now 2
            _buildBottomNavItem(icon: Icons.storefront_outlined, label: 'Marketplace', index: 3), // Note index is now 3
          ],
        ),
      ),
    );
  }

  // Helper method to build individual BottomAppBar items
  Widget _buildBottomNavItem({required IconData icon, required String label, required int index}) {
    // Adjust index mapping because FAB isn't in the PageView
    int pageIndex = index;
    // Calculate the actual selected index for highlighting, accounting for the FAB gap
    int currentDisplayIndex = _selectedIndex;
    if (_selectedIndex >= 2) {
      currentDisplayIndex = _selectedIndex -1; // Adjust index shown in PageView
    }

    final bool isSelected = (pageIndex == currentDisplayIndex);
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Expanded( // Ensure items take up space
      child: InkWell( // Make the whole area tappable
        onTap: () => _onItemTapped(pageIndex), // Use the original index for tapping logic
        customBorder: const CircleBorder(), // Nice ripple effect
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0), // Vertical padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take minimum vertical space
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(height: 2), // Space between icon and label
              Text(
                label,
                style: TextStyle(
                  fontSize: 10, // Smaller font size for labels
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
    // Adjust index for title lookup
    int adjustedIndex = index;
     if (index >= 2) {
      adjustedIndex = index -1; // Use PageView index
    }
    switch (adjustedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'My Pins';
      // Case 2 is now Community
      case 2: return 'Community';
      // Case 3 is now Marketplace
      case 3: return 'Marketplace';
      default: return 'PinSpace';
    }
  }
}
