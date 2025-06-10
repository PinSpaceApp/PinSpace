// lib/screens/set_details_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_sets_view.dart'; // To use DisplayPinInSet and PinSet

final supabase = Supabase.instance.client;

class SetDetailsPage extends StatefulWidget {
  final PinSet set;
  final bool isUncategorizedSet;

  const SetDetailsPage({
    super.key,
    required this.set,
    this.isUncategorizedSet = false,
  });

  @override
  State<SetDetailsPage> createState() => _SetDetailsPageState();
}

class _SetDetailsPageState extends State<SetDetailsPage> with SingleTickerProviderStateMixin {
  late List<DisplayPinInSet> _pinsInThisSet;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String? _currentUserId;
  Set<String> _wishlistedPinIds = {};


  @override
  void initState() {
    super.initState();
    _pinsInThisSet = List.from(widget.set.pinsToDisplay);
    _isLoading = false;
    _currentUserId = supabase.auth.currentUser?.id;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    if (widget.set.isComplete) {
      _animationController.forward();
    }
    
    if (_currentUserId != null) {
      _fetchUserWishlist();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchUserWishlist() async {
    if (_currentUserId == null || !mounted) return;
    try {
      final response = await supabase
          .from('user_wishlist')
          .select('pin_catalog_id')
          .eq('user_id', _currentUserId!);

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      setState(() {
        _wishlistedPinIds = data.map((item) => item['pin_catalog_id'].toString()).toSet();
      });
    } catch (e) {
      print("Error fetching wishlist on details page: $e");
    }
  }

  Future<void> _toggleWishlist(DisplayPinInSet pin) async {
    if (_currentUserId == null) {
      _showSnackBar("You need to be logged in to manage your wishlist.", isError: true);
      return;
    }
    
    final isCurrentlyWishlisted = _wishlistedPinIds.contains(pin.displayId);
    final catalogPinIdAsInt = int.tryParse(pin.displayId);
    
    if (catalogPinIdAsInt == null) {
      _showSnackBar("Invalid pin ID for wishlist.", isError: true);
      return;
    }

    // Optimistic UI update
    setState(() {
      if (isCurrentlyWishlisted) {
        _wishlistedPinIds.remove(pin.displayId);
      } else {
        _wishlistedPinIds.add(pin.displayId);
      }
    });

    try {
      if (isCurrentlyWishlisted) {
        await supabase.from('user_wishlist').delete().match({'user_id': _currentUserId!, 'pin_catalog_id': catalogPinIdAsInt});
        _showSnackBar("'${pin.name}' removed from wishlist.");
      } else {
        await supabase.from('user_wishlist').insert({'user_id': _currentUserId!, 'pin_catalog_id': catalogPinIdAsInt});
        _showSnackBar("'${pin.name}' added to wishlist!");
      }
    } catch (e) {
      print("Error toggling wishlist: $e");
      // Revert UI on error
      setState(() {
        if (isCurrentlyWishlisted) {
          _wishlistedPinIds.add(pin.displayId);
        } else {
          _wishlistedPinIds.remove(pin.displayId);
        }
      });
      _showSnackBar("Error updating wishlist: ${e.toString()}", isError: true);
    }
  }

  Future<void> _removePinFromCollection(DisplayPinInSet pin) async {
    if (_currentUserId == null) {
      _showSnackBar("You must be logged in to remove pins.", isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Removal'),
          content: Text('Are you sure you want to remove "${pin.name}" from your collection?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final userId = _currentUserId!;
      final catalogPinId = int.tryParse(pin.displayId);

      if (catalogPinId == null) {
        throw 'Invalid Pin ID';
      }

      await supabase
          .from('pins')
          .delete()
          .match({
            'user_id': userId,
            'catalog_pin_ref_id': catalogPinId,
          });

      if (mounted) {
        setState(() {
          pin.isOwned = false;
          if (widget.set.isComplete) {
            widget.set.isComplete = false;
            _animationController.reverse();
          }
        });
        _showSnackBar("'${pin.name}' removed from your collection.");
      }
    } catch (e) {
      print('Error removing pin: $e');
      _showSnackBar("Failed to remove pin: ${e.toString()}", isError: true);
    }
  }

  Future<void> _addPinToCollection(DisplayPinInSet pin) async {
    if (_currentUserId == null) {
      _showSnackBar("You must be logged in to add pins.", isError: true);
      return;
    }

    try {
      final userId = _currentUserId!;
      final catalogPinId = int.tryParse(pin.displayId);

      if (catalogPinId == null) {
        throw 'Invalid Pin ID';
      }

      final pinCatalogData = await supabase
          .from('all_pins_catalog')
          .select()
          .eq('id', catalogPinId)
          .single();

      await supabase.from('pins').insert({
        'user_id': userId,
        'name': pinCatalogData['name'],
        'image_url': pinCatalogData['image_url'],
        'catalog_pin_ref_id': catalogPinId,
        'set_id': widget.set.id,
      });

      if (mounted) {
        setState(() {
          pin.isOwned = true;
          final allOwned = _pinsInThisSet.every((p) => p.isOwned);
          if (allOwned) {
            widget.set.isComplete = true;
            _animationController.forward();
          }
        });
        _showSnackBar("${pin.name} added to your collection!", isError: false);
      }
    } catch (e) {
      print('Error adding pin: $e');
      _showSnackBar("Failed to add pin: ${e.toString()}", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Details"),
        backgroundColor: const Color(0xFF3d4895),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildContentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final int ownedPins = _pinsInThisSet.where((p) => p.isOwned).length;
    final int totalPins = _pinsInThisSet.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.set.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[850],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.set.isComplete)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Tooltip(
                    message: 'Set Complete!',
                    child: Container(
                      margin: const EdgeInsets.only(right: 8.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.6),
                            blurRadius: 8.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              if (widget.set.originalCatalogSetId != null)
                Text(
                  '$ownedPins/$totalPins Collected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.set.isComplete ? Colors.green[700] : Colors.grey[600],
                    fontWeight: widget.set.isComplete ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              else
                Text(
                  '$totalPins ${totalPins == 1 ? "Pin" : "Pins"}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Colors.red[700])));
    }
    if (_pinsInThisSet.isEmpty) {
      return Center(child: Text(widget.isUncategorizedSet ? "No uncategorized pins found." : "No pins in this set."));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7, 
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: _pinsInThisSet.length,
      itemBuilder: (context, index) {
        final pinDisplay = _pinsInThisSet[index];

        Widget imageWidget = Image.network(
          pinDisplay.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Image with conditional greyscale ---
                    pinDisplay.isOwned
                        ? imageWidget
                        : ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      1, 0,
                            ]),
                            child: Opacity(opacity: 0.6, child: imageWidget),
                          ),
                    // --- "COLLECTED" / "MISSING" Banner ---
                    if (widget.set.originalCatalogSetId != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: pinDisplay.isOwned
                              ? Colors.green.withOpacity(0.8)
                              : Colors.red.withOpacity(0.8),
                          child: Text(
                            pinDisplay.isOwned ? 'COLLECTED' : 'MISSING',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Text(
                  pinDisplay.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              if (widget.set.originalCatalogSetId != null)
                _buildPinStatus(pinDisplay),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinStatus(DisplayPinInSet pin) {
    final bool isWishlisted = _wishlistedPinIds.contains(pin.displayId);
    return SizedBox(
      height: 36, 
      child: Center(
        child: pin.isOwned
            ? Tooltip(
                message: 'Remove from Collection',
                child: IconButton(
                  icon: Icon(Icons.library_add_check, color: Theme.of(context).primaryColor),
                  iconSize: 24,
                  padding: EdgeInsets.zero,
                  onPressed: () => _removePinFromCollection(pin),
                ),
              )
            : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Tooltip(
                  message: isWishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
                  child: IconButton(
                    icon: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: isWishlisted ? Colors.red.shade400 : Colors.grey[700],
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    onPressed: () => _toggleWishlist(pin),
                  ),
                ),
                Tooltip(
                  message: 'Add to My Collection',
                  child: IconButton(
                    icon: Icon(
                      Icons.library_add_outlined,
                      color: Colors.grey[700],
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    onPressed: () => _addPinToCollection(pin),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
