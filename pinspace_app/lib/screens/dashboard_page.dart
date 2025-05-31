// lib/screens/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

import '../models/profile.dart'; 
// Assuming Pin and PinStatus are defined in user_profile_page.dart or a shared models file
import 'user_profile_page.dart' show UserProfilePage, Pin, PinStatus;


import 'my_pins_page.dart' hide Pin, PinStatus; // Hide if it also defines Pin to avoid conflict

import 'scanner_page.dart';
import 'marketplace_page.dart';
import 'main_app_shell.dart';
import 'pin_catalog_page.dart'; // ✨ IMPORTED for navigation

final supabase = Supabase.instance.client;

const String kMagicalFont = 'Poppins'; 

const Color kMainAppColor = Color(0xFF30479B);
const Color kSecondaryAppColor = Color(0xFFFFC107);

const List<Color> kSubtleAccents = [
  Color(0xFFFDB0C0), // Soft Pink
  Color(0xFFADC8FF), // Soft Blue
  Color(0xFFB2EBF2), // Light Cyan/Teal
  Color(0xFFFFE082), // Pale Yellow
];

class CatalogPin {
  final int id;
  final String name;
  final String? imageUrl;

  CatalogPin({required this.id, required this.name, this.imageUrl});

  factory CatalogPin.fromMap(Map<String, dynamic> map) {
    return CatalogPin(
      id: map['id'] as int,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String?,
    );
  }
}


class DashboardPage extends StatefulWidget {
  final void Function(int)? onNavigateRequest;

  const DashboardPage({super.key, this.onNavigateRequest});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin { 
  Profile? _userProfile;
  bool _isLoadingProfile = true;
  String? _profileError;

  int _myCollectionCount = 0;
  int _mySetCount = 0; 
  int _forTradeCount = 0;
  int _wishlistCount = 0;
  bool _isLoadingStats = true;

  List<CatalogPin> _newestPins = [];
  bool _isLoadingNewestPins = true;
  String? _newestPinsError;

  late AnimationController _greetingAnimationController;
  late Animation<double> _greetingFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _greetingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _greetingFadeAnimation = CurvedAnimation(
      parent: _greetingAnimationController,
      curve: Curves.easeIn,
    );
    _fetchAllDashboardData();
  }

  @override
  void dispose() {
    _greetingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllDashboardData() async {
    await _fetchUserProfileAndStats();
    await _fetchNewestPins(); 
  }

  Future<void> _fetchUserProfileAndStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _isLoadingStats = true;
      _profileError = null;
    });

    _greetingAnimationController.reset();

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingStats = false;
          _profileError = "Not logged in.";
        });
        _greetingAnimationController.forward(); 
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
        _userProfile = Profile.fromMap(profileData);
      } else {
        _profileError = "Profile not found.";
        _userProfile = null;
      }
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        _greetingAnimationController.forward(); 
      }

      final pinCountResponse = await supabase
          .from('pins')
          .select('id') 
          .eq('user_id', user.id)
          .count(CountOption.exact);
      _myCollectionCount = pinCountResponse.count ?? 0;
      print('Fetched pin count for user ${user.id}: $_myCollectionCount');

      final setCountResponse = await supabase
          .from('sets') 
          .select('id') 
          .eq('user_id', user.id)
          .count(CountOption.exact);
      _mySetCount = setCountResponse.count ?? 0;
      print('Fetched set count for user ${user.id}: $_mySetCount');
      
      final pinsForTradeResponse = await supabase
          .from('pins')
          .select('id, status, user_id, name') 
          .eq('user_id', user.id);
      
      final List<dynamic> pinsDataForTrade = pinsForTradeResponse as List<dynamic>;
      _forTradeCount = pinsDataForTrade.where((pinMapDynamic) {
        if (pinMapDynamic is Map<String, dynamic>) {
          try { 
            final pin = Pin.fromMap(pinMapDynamic); 
            return pin.status == PinStatus.forTrade;
          } catch (e) {
            print("Error parsing pin for trade count: $e, Pin data: $pinMapDynamic");
            return false;
          }
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
      }

      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      print('Error fetching user profile and stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingStats = false;
          _profileError = "Failed to load dashboard data. ${e.toString()}";
        });
         _greetingAnimationController.forward(); 
      }
    }
  }

  Future<void> _fetchNewestPins() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNewestPins = true;
      _newestPinsError = null;
    });

    try {
      final response = await supabase
          .from('all_pins_catalog')
          .select('id, name, image_url')
          .order('created_at', ascending: false)
          .limit(5); 

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      _newestPins = data.map((map) => CatalogPin.fromMap(map as Map<String, dynamic>)).toList();
      
      setState(() => _isLoadingNewestPins = false);

    } catch (e) {
      print('Error fetching newest pins: $e');
      if (mounted) {
        setState(() {
          _isLoadingNewestPins = false;
          _newestPinsError = "Failed to load newest pins.";
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = kMainAppColor;
    final accentColor = kSecondaryAppColor;
    final scaffoldBgColor = Colors.white; 

    return Scaffold(
      backgroundColor: scaffoldBgColor, 
      body: RefreshIndicator(
          onRefresh: _fetchAllDashboardData, 
          color: accentColor, 
          backgroundColor: primaryColor.withOpacity(0.8),
          child: CustomScrollView( 
            slivers: <Widget>[
              SliverPadding( 
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 24.0, 
                  left: 16.0, 
                  right: 16.0, 
                  bottom: 16.0
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildGreetingSection(theme, primaryColor),
                      const SizedBox(height: 30.0),

                      _buildSectionHeader("Your Pin Stats", theme),
                      const SizedBox(height: 16.0),
                      _isLoadingStats
                          ? _buildStatsShimmer()
                          : _buildStatsGrid(context, theme), 
                      const SizedBox(height: 30.0),

                      _buildSectionHeader("Quick Actions", theme),
                      const SizedBox(height: 16.0),
                      _buildQuickActionsGrid(context, theme),
                      const SizedBox(height: 30.0),

                      // ✨ UPDATED: Section header for Newest Pins
                      _buildSectionHeader(
                        "Newest Pins in Catalog", 
                        theme,
                        actionButton: TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const PinCatalogPage()));
                          },
                          child: Text(
                            "View Catalog",
                            style: TextStyle(
                              fontFamily: kMagicalFont,
                              fontWeight: FontWeight.w600,
                              color: kMainAppColor,
                              fontSize: theme.textTheme.bodyMedium?.fontSize,
                            ),
                          ),
                        ),
                      ), 
                      const SizedBox(height: 16.0),
                      _buildNewestPinsSection(theme), 
                      const SizedBox(height: 30.0),

                      _buildSectionHeader("Community Buzz", theme),
                      const SizedBox(height: 16.0),
                      _buildSocialHubSection(theme),
                      const SizedBox(height: 30.0), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  // ✨ UPDATED: _buildSectionHeader to optionally include an action button
  Widget _buildSectionHeader(String title, ThemeData theme, {Widget? actionButton}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith( 
            fontWeight: FontWeight.w600, 
            fontFamily: kMagicalFont,
            color: Colors.grey.shade600, 
          ),
        ),
        if (actionButton != null) actionButton,
      ],
    );
  }
  
  Widget _buildGreetingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, 
      highlightColor: Colors.grey.shade100, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 28.0,
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(8)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingSection(ThemeData theme, Color greetingAccentColor) {
    if (_isLoadingProfile) {
      return _buildGreetingShimmer();
    }

    String usernameDisplay = "Pin Collector"; 
    if (_userProfile != null) {
      if (_userProfile!.username != null && _userProfile!.username!.isNotEmpty) {
        usernameDisplay = _userProfile!.username!;
      } else if (_userProfile!.fullName != null && _userProfile!.fullName!.isNotEmpty) {
        usernameDisplay = _userProfile!.fullName!;
      }
    }

    String greetingText = _profileError != null && _userProfile == null
        ? "Welcome to PinSpace!"
        : "Welcome back, $usernameDisplay!";

    return FadeTransition(
      opacity: _greetingFadeAnimation,
      child: Text(
        greetingText,
        style: theme.textTheme.headlineMedium?.copyWith( 
          fontWeight: FontWeight.w600,
          fontFamily: kMagicalFont,
          color: kMainAppColor, 
           shadows: [
            Shadow(
              blurRadius: 1.0, 
              color: Colors.grey.withOpacity(0.3),
              offset: const Offset(1.0, 1.5),
            ),
          ]
        ),
      ),
    );
  }

  Widget _buildStatsShimmer() {
    return GridView.count(
      crossAxisCount: 2, 
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16.0,
      crossAxisSpacing: 16.0,
      childAspectRatio: 2.3, 
      children: List.generate(3, (index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300, 
        highlightColor: Colors.grey.shade100, 
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16.0)
            ),
          ),
        ),
      )),
    );
  }


  Widget _buildStatsGrid(BuildContext context, ThemeData theme) { 
    final statCardColors = [
      Colors.pink.shade300, 
      Colors.lightBlue.shade300, 
      kSecondaryAppColor, 
    ];

    String myCollectionValue = "$_myCollectionCount Pins | $_mySetCount Sets";

    final statItems = <Widget>[
      _StatCard(
        title: "My Collection", 
        value: myCollectionValue, 
        icon: Icons.inventory_2_rounded, 
        cardAccentColor: statCardColors[0], 
        iconThemeColor: statCardColors[0],
        onTap: () { 
          widget.onNavigateRequest?.call(1); 
        },
      ),
      _StatCard(title: "For Trade", value: _forTradeCount.toString(), icon: Icons.swap_horiz_rounded, cardAccentColor: statCardColors[1], iconThemeColor: statCardColors[1]),
      _StatCard(title: "Wishlist", value: _wishlistCount.toString(), icon: Icons.favorite_rounded, cardAccentColor: statCardColors[2], iconThemeColor: statCardColors[2]),
    ];

    return AnimationLimiter(
      child: GridView.count(
        crossAxisCount: 2, 
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16.0, 
        crossAxisSpacing: 16.0, 
        childAspectRatio: 2.3, 
        children: List.generate(
          statItems.length,
          (index) {
            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 500),
              columnCount: 2,
              child: ScaleAnimation(
                delay: Duration(milliseconds: index * 100),
                child: FadeInAnimation(
                  child: statItems[index],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, ThemeData theme) {
     final actionItems = [
      _ActionCardData(
        title: "Add New Pin",
        icon: Icons.add_photo_alternate_rounded, 
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage())),
      ),
      _ActionCardData(
        title: "My Collection",
        icon: Icons.collections_bookmark_rounded, 
        onTap: () => widget.onNavigateRequest?.call(1), 
      ),
      _ActionCardData(
        title: "Pin Market",
        icon: Icons.store_mall_directory_rounded, 
        onTap: () => widget.onNavigateRequest?.call(3), 
      ),
      _ActionCardData(
        title: "My Profile",
        icon: Icons.face_retouching_natural_rounded, 
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserProfilePage(),
            settings: const RouteSettings(name: MainAppShell.userProfileRouteName),
          ),
        ),
      ),
    ];
    
    return AnimationLimiter(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12.0, 
        crossAxisSpacing: 12.0, 
        childAspectRatio: 2.5, 
        children: List.generate(
          actionItems.length,
          (index) {
            final item = actionItems[index];
            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 500),
              columnCount: 2,
              child: SlideAnimation(
                delay: Duration(milliseconds: index * 100 + 200), 
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _ActionCard( 
                    title: item.title,
                    icon: item.icon,
                    onTap: item.onTap,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewestPinsSection(ThemeData theme) {
    if (_isLoadingNewestPins) {
      return _buildPinsShimmer();
    }

    if (_newestPinsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text(_newestPinsError!, style: TextStyle(fontFamily: kMagicalFont, color: Colors.red.shade700))),
      );
    }

    if (_newestPins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text("No new pins in the catalog yet!", style: TextStyle(fontFamily: kMagicalFont, color: Colors.grey))),
      );
    }

    return SizedBox(
      height: 200, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _newestPins.length,
        itemBuilder: (context, index) {
          final pinData = _newestPins[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: _PinDisplayCard(
                  pin: pinData, 
                  borderColor: Colors.grey.shade300, 
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinsShimmer() {
    return SizedBox(
      height: 200, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3, 
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 140, 
              height: 180, 
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialHubSection(ThemeData theme) {
    final socialActivities = [
      _SocialActivityData(title: "New Trade Alert!", description: "User 'PinFanatic22' just posted a new trade for a rare Figment pin.", icon: Icons.swap_horiz_sharp, color: kSubtleAccents[0]),
      _SocialActivityData(title: "Hot Pin Listed", description: "'DisneyDreamer' listed a 'Haunted Mansion Holiday 2023' pin.", icon: Icons.local_fire_department_rounded, color: kSubtleAccents[1]),
      _SocialActivityData(title: "Community Goal Reached", description: "We've hit 10,000 trades on PinSpace!", icon: Icons.celebration_rounded, color: kSubtleAccents[2]),
    ];
     if (socialActivities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text("No community buzz right now.", style: TextStyle(fontFamily: kMagicalFont, color: Colors.grey))),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: socialActivities.length,
        itemBuilder: (context, index) {
          final activity = socialActivities[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _SocialActivityCard(data: activity),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionCardData {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _ActionCardData({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value; 
  final IconData icon;
  final Color cardAccentColor; 
  final Color iconThemeColor; 
  final VoidCallback? onTap; 

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.cardAccentColor,
    required this.iconThemeColor,
    this.onTap, 
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container( 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [ 
          BoxShadow(
            color: Colors.grey.withOpacity(0.25), 
            blurRadius: 10.0, 
            spreadRadius: 1.5, 
            offset: const Offset(3.0, 4.0), 
          ),
        ],
        border: Border.all(color: cardAccentColor.withOpacity(0.9), width: 2.0) 
      ),
      child: Material( 
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: onTap, 
          borderRadius: BorderRadius.circular(16.0),
          splashColor: iconThemeColor.withOpacity(0.2),
          highlightColor: iconThemeColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0), 
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: kMagicalFont,
                          color: kMainAppColor, 
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(icon, size: 24.0, color: iconThemeColor), 
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox( 
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith( 
                      fontWeight: FontWeight.bold,
                      fontFamily: kMagicalFont,
                      color: cardAccentColor, 
                       letterSpacing: -0.2, 
                    ),
                    maxLines: 2, 
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2.0, 
      shadowColor: Colors.grey.withOpacity(0.5), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), 
        side: BorderSide(color: Colors.grey.shade300, width: 1), 
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        splashColor: kMainAppColor.withOpacity(0.05),
        highlightColor: kMainAppColor.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 28.0, color: kMainAppColor), 
              const SizedBox(height: 8.0), 
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith( 
                  fontWeight: FontWeight.w600,
                  fontFamily: kMagicalFont,
                  color: kMainAppColor, 
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _PinDisplayCard extends StatelessWidget {
  final CatalogPin pin;
  final Color borderColor; 

  const _PinDisplayCard({required this.pin, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    const double imageHeight = 100.0; 
    const double imageWidth = 120.0; 


    if (pin.imageUrl != null && pin.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        pin.imageUrl!,
        width: imageWidth,
        height: imageHeight,
        fit: BoxFit.contain, 
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: imageWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey.shade400),
          );
        },
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: imageWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(kMainAppColor),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = Container(
        width: imageWidth,
        height: imageHeight,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Icon(Icons.push_pin_rounded, size: 40, color: Colors.grey.shade400),
      );
    }

    return Container(
      width: 140, 
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [ 
          BoxShadow(
            color: Colors.grey.withOpacity(0.3), 
            blurRadius: 8.0, 
            spreadRadius: 1.0, 
            offset: const Offset(2.0, 3.0), 
          ),
        ],
        border: Border.all(color: borderColor, width: 1.5) 
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect( 
                borderRadius: BorderRadius.circular(8.0),
                child: imageWidget,
            ),
            const SizedBox(height: 8),
            Expanded( 
              child: Text(
                pin.name,
                style: TextStyle(
                  fontFamily: kMagicalFont,
                  fontWeight: FontWeight.w600,
                  color: kMainAppColor.withOpacity(0.9), 
                  fontSize: 13, 
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialActivityData {
  final String title;
  final String description;
  final IconData icon;
  final Color color; 

  _SocialActivityData({required this.title, required this.description, required this.icon, required this.color});
}

class _SocialActivityCard extends StatelessWidget {
  final _SocialActivityData data;
  const _SocialActivityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0, 
      shadowColor: Colors.grey.withOpacity(0.4), 
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: data.color.withOpacity(0.3), width: 1) 
      ),
      color: Colors.white, 
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: data.color.withOpacity(0.15), 
          child: Icon(data.icon, color: data.color, size: 22),
        ),
        title: Text(
          data.title,
          style: TextStyle(
            fontFamily: kMagicalFont,
            fontWeight: FontWeight.bold,
            color: kMainAppColor,
          ),
        ),
        subtitle: Text(
          data.description,
          style: TextStyle(
            fontFamily: kMagicalFont,
            color: kMainAppColor.withOpacity(0.7), 
            fontSize: 13,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: data.color.withOpacity(0.6)),
        onTap: () {
          // TODO: Navigate to relevant social item or trade details
          print("Tapped on social item: ${data.title}");
        },
      ),
    );
  }
}

