// lib/screens/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

import '../models/profile.dart';
import 'user_profile_page.dart' show UserProfilePage, Pin, PinStatus;


import 'my_pins_page.dart' hide Pin, PinStatus;

import 'scanner_page.dart';
import 'marketplace_page.dart';
import 'main_app_shell.dart';
import 'pin_catalog_page.dart';

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

class CatalogSet {
  final int id;
  final String name;
  final List<String> pinImageUrls;

  CatalogSet({required this.id, required this.name, required this.pinImageUrls});

  factory CatalogSet.fromMap(Map<String, dynamic> map) {
    final imageUrlsData = map['pin_image_urls'] as List<dynamic>?;
    final imageUrls = imageUrlsData?.map((item) => item.toString()).toList() ?? [];

    return CatalogSet(
      id: map['id'] as int,
      name: map['name'] as String,
      pinImageUrls: imageUrls,
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
  int _myTrophiesCount = 0;
  bool _isLoadingStats = true;

  List<CatalogSet> _newestSets = [];
  bool _isLoadingNewestSets = true;
  String? _newestSetsError;

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
    await _fetchNewestSets();
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

      final setCountResponse = await supabase
          .from('sets')
          .select('id')
          .eq('user_id', user.id)
          .count(CountOption.exact);
      _mySetCount = setCountResponse.count ?? 0;

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

      _myTrophiesCount = 0;
      try {
        final trophiesResponse = await supabase
            .from('user_achievements') // Corrected table name
            .select()
            .eq('user_id', user.id)
            .count(CountOption.exact);
        if(mounted) {
          _myTrophiesCount = trophiesResponse.count ?? 0;
        }
      } catch (e) {
        print("Error fetching trophies count: $e");
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

  Future<void> _fetchNewestSets() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNewestSets = true;
      _newestSetsError = null;
    });

    try {
      final response = await supabase
          .rpc('get_newest_sets_with_pin_images');

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      _newestSets = data.map((map) => CatalogSet.fromMap(map as Map<String, dynamic>)).toList();

      setState(() => _isLoadingNewestSets = false);

    } catch (e, stackTrace) {
      print('Error fetching newest sets: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingNewestSets = false;
          _newestSetsError = "Failed to load newest sets.";
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
              padding: const EdgeInsets.only(
                top: 40.0,
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
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

                    _buildSectionHeader(
                      "Newest Sets in Catalog",
                      theme,
                      actionButton: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PinCatalogPage()));
                        },
                        child: Text(
                          "View All Sets",
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
                    _buildNewestSetsSection(theme),
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
      children: List.generate(4, (index) => Shimmer.fromColors(
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
      Colors.green.shade400,
      Colors.lightBlue.shade300,
      Colors.red.shade400,
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
      _StatCard(title: "My Trophies", value: _myTrophiesCount.toString(), icon: Icons.emoji_events_rounded, cardAccentColor: statCardColors[3], iconThemeColor: statCardColors[3]),
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

  Widget _buildNewestSetsSection(ThemeData theme) {
    if (_isLoadingNewestSets) {
      return _buildSetsShimmer();
    }

    if (_newestSetsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text(_newestSetsError!, style: TextStyle(fontFamily: kMagicalFont, color: Colors.red.shade700))),
      );
    }

    if (_newestSets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text("No new sets in the catalog yet!", style: TextStyle(fontFamily: kMagicalFont, color: Colors.grey))),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _newestSets.length,
        itemBuilder: (context, index) {
          final setData = _newestSets[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: _SetDisplayCard(
                  set: setData,
                  borderColor: Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetsShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 150,
              height: 200,
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

// ===============================================
// WIDGET CLASSES START HERE
// ===============================================

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

// ✅ FIX APPLIED HERE: This is the single, corrected version of _StatCard
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
            padding: const EdgeInsets.all(12.0), // Reduced padding slightly as well
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: kMagicalFont,
                            color: cardAccentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(icon, size: 22.0, color: iconThemeColor), // Reduced icon size
                    ],
                  ),
                ),
                const SizedBox(height: 2), // Reduced SizedBox height
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: kMagicalFont,
                        color: Colors.grey.shade700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.start,
                    ),
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

// ✅ FIX APPLIED HERE: This is the single, corrected version of _ActionCard
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
              Flexible(
                child: Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetDisplayCard extends StatefulWidget {
  final CatalogSet set;
  final Color borderColor;

  const _SetDisplayCard({required this.set, required this.borderColor});

  @override
  State<_SetDisplayCard> createState() => _SetDisplayCardState();
}

class _SetDisplayCardState extends State<_SetDisplayCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.set.pinImageUrls.length, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? kMainAppColor
                : Colors.grey.shade400,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double imageHeight = 100.0;
    const double imageWidth = 130.0;

    Widget imageCarousel;

    if (widget.set.pinImageUrls.isNotEmpty) {
      imageCarousel = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: imageHeight,
            width: imageWidth,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.set.pinImageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = widget.set.pinImageUrls[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey.shade400),
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: const AlwaysStoppedAnimation<Color>(kMainAppColor),
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_currentPage > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black54),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ),
          if (_currentPage < widget.set.pinImageUrls.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black54),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ),
        ],
      );
    } else {
      imageCarousel = Container(
        width: imageWidth,
        height: imageHeight,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Icon(Icons.collections_bookmark_rounded, size: 40, color: Colors.grey.shade400),
      );
    }

    return Container(
      width: 150,
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
        border: Border.all(color: widget.borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: imageCarousel,
            ),
            if (widget.set.pinImageUrls.length > 1) _buildPageIndicator(),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                widget.set.name,
                style: TextStyle(
                  fontFamily: kMagicalFont,
                  fontWeight: FontWeight.w600,
                  color: kMainAppColor.withOpacity(0.9),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
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
          print("Tapped on social item: ${data.title}");
        },
      ),
    );
  }
}