// lib/screens/pin_catalog_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'user_profile_page.dart'; 
import 'main_app_shell.dart'; 
// import 'my_wishlist_page.dart'; // Placeholder for your Wishlist page

final supabase = Supabase.instance.client;

// Model for pins from the all_pins_catalog table
class CatalogPin {
  final String id; 
  final String name;
  final String imageUrl;
  final String? description;
  final String? origin;
  final String? releaseDate;
  final String? editionSize;
  final String? customSetName; 
  final String? tags;
  final String? sourcePinId; 
  final BigInt? catalogSetId; 
  final String? seriesNameFromSource; 

  CatalogPin({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.description,
    this.origin,
    this.releaseDate,
    this.editionSize,
    this.customSetName,
    this.tags,
    this.sourcePinId,
    this.catalogSetId,
    this.seriesNameFromSource, 
  });

  factory CatalogPin.fromMap(Map<String, dynamic> map) {
    return CatalogPin(
      id: map['id'].toString(), 
      name: map['name'] as String? ?? 'Unnamed Pin',
      imageUrl: map['image_url'] as String? ?? 'https://placehold.co/300x300/E6E6FA/333333?text=No+Image',
      description: map['description'] as String?,
      origin: map['origin'] as String?,
      releaseDate: map['release_date'] as String?, 
      editionSize: map['edition_size'] as String?,
      customSetName: map['custom_set_name'] as String?,
      tags: map['tags'] as String?,
      sourcePinId: map['source_pin_id'] as String?,
      catalogSetId: map['catalog_set_id'] != null ? BigInt.tryParse(map['catalog_set_id'].toString()) : null,
      seriesNameFromSource: map['series_name_from_source'] as String?, 
    );
  }
}

// Model for sets from the all_sets_catalog table
class CatalogSet {
  final String id; 
  final String name;
  final String? imageUrl;
  final String? description;

  CatalogSet({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });

  factory CatalogSet.fromMap(Map<String, dynamic> map) {
    return CatalogSet(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Unnamed Set',
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String?,
    );
  }
}

enum CatalogViewMode { pins, sets }

class PinCatalogPage extends StatefulWidget {
  const PinCatalogPage({super.key});

  @override
  State<PinCatalogPage> createState() => _PinCatalogPageState();
}

class _PinCatalogPageState extends State<PinCatalogPage> {
  CatalogViewMode _viewMode = CatalogViewMode.pins;
  List<CatalogPin> _catalogPins = [];
  List<CatalogPin> _filteredCatalogPins = []; 
  List<CatalogSet> _catalogSets = [];

  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  Set<String> _wishlistedPinIds = {}; 
  Set<String> _ownedCatalogPinIds = {}; // <<--- NEW: To track owned catalog pins
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _searchController.addListener(_onSearchChanged);
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCatalogPins = List.from(_catalogPins); 
      } else {
        _filteredCatalogPins = _catalogPins.where((pin) {
          return (pin.name.toLowerCase().contains(query)) ||
                 (pin.tags?.toLowerCase().contains(query) ?? false) ||
                 (pin.origin?.toLowerCase().contains(query) ?? false) ||
                 (pin.customSetName?.toLowerCase().contains(query) ?? false) ||
                 (pin.seriesNameFromSource?.toLowerCase().contains(query) ?? false); 
        }).toList();
      }
    });
  }


  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_currentUserId != null) {
        await _fetchUserWishlist(); 
        await _fetchOwnedCatalogPinIds(); // <<--- NEW: Fetch owned pins
      }
      if (_viewMode == CatalogViewMode.pins) {
        await _fetchCatalogPins();
      } else {
        await _fetchCatalogSets();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load data: ${e.toString()}";
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

  Future<void> _fetchCatalogPins() async {
    final response = await supabase
        .from('all_pins_catalog')
        .select('*, all_sets_catalog:catalog_set_id (name)') 
        .order('name', ascending: true) 
        .limit(200); 

    if (!mounted) return;
    
    final List<dynamic> data = response as List<dynamic>; 
    setState(() {
      _catalogPins = data.map((map) {
        final pinMap = map as Map<String, dynamic>;
        final setInfo = pinMap['all_sets_catalog'] as Map<String, dynamic>?;
        final seriesName = setInfo?['name'] as String?;
        pinMap['series_name_from_source'] = seriesName;
        return CatalogPin.fromMap(pinMap);
      }).toList();
      _filteredCatalogPins = List.from(_catalogPins); 
      _onSearchChanged(); 
    });
  }

  Future<void> _fetchCatalogSets() async {
    final response = await supabase
        .from('all_sets_catalog')
        .select()
        .order('name', ascending: true)
        .limit(100);
    if (!mounted) return;
    final List<dynamic> data = response as List<dynamic>; 
    setState(() {
      _catalogSets = data.map((map) => CatalogSet.fromMap(map as Map<String, dynamic>)).toList();
    });
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
      print("Error fetching wishlist: $e");
    }
  }

  // <<--- NEW: Method to fetch IDs of catalog pins already in user's collection --- >>
  Future<void> _fetchOwnedCatalogPinIds() async {
    if (_currentUserId == null || !mounted) return;
    try {
      // This query assumes your 'pins' table (user's collection) has a
      // column like 'source_pin_id' that matches 'all_pins_catalog.source_pin_id'
      // OR a 'catalog_ref_id' that matches 'all_pins_catalog.id'.
      // Adjust the column name ('source_pin_id' or 'catalog_ref_id') as per your 'pins' table structure.
      // For this example, I'll assume you might store 'all_pins_catalog.id' in your 'pins' table
      // as 'catalog_pin_ref_id' when a user "owns" a catalog pin.
      
      // If you don't have a direct link from your 'pins' table back to 'all_pins_catalog.id',
      // this becomes harder. You might have to match by name/series, which is less reliable.
      // For now, let's assume a 'catalog_pin_ref_id' column exists in your 'pins' table.
      // If not, this will return empty and all pins will appear as "not owned".

      final response = await supabase
          .from('pins') // User's personal collection table
          .select('catalog_pin_ref_id') // Column in 'pins' that links to 'all_pins_catalog.id'
          .eq('user_id', _currentUserId!);
      
      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      setState(() {
        _ownedCatalogPinIds = data
            .where((item) => item['catalog_pin_ref_id'] != null)
            .map((item) => item['catalog_pin_ref_id'].toString())
            .toSet();
      });
      print("Owned catalog pin IDs: $_ownedCatalogPinIds");
    } catch (e) {
      print("Error fetching owned catalog pin IDs: $e");
      // If this fails, all pins will appear as not owned.
    }
  }


  Future<void> _toggleWishlist(CatalogPin pin) async {
    // ... (same as before)
    if (_currentUserId == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You need to be logged in to manage your wishlist.")),
      );
      return;
    }
    final isCurrentlyWishlisted = _wishlistedPinIds.contains(pin.id);
    if (mounted) {
      setState(() {
        if (isCurrentlyWishlisted) _wishlistedPinIds.remove(pin.id);
        else _wishlistedPinIds.add(pin.id);
      });
    }
    try {
      if (isCurrentlyWishlisted) {
        await supabase.from('user_wishlist').delete().match({'user_id': _currentUserId!, 'pin_catalog_id': pin.id}); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${pin.name}' removed from wishlist.")));
      } else {
        await supabase.from('user_wishlist').insert({'user_id': _currentUserId!, 'pin_catalog_id': pin.id}); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${pin.name}' added to wishlist!")));
      }
    } catch (e) {
      print("Error toggling wishlist: $e");
      if (mounted) {
        setState(() {
          if (isCurrentlyWishlisted) _wishlistedPinIds.add(pin.id);
          else _wishlistedPinIds.remove(pin.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating wishlist: ${e.toString()}"), backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> _addPinToMyCollection(CatalogPin catalogPin) async {
    if (_currentUserId == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You need to be logged in to add pins.")));
      return;
    }
    
    // Check if already owned to prevent duplicates, or handle quantity update
    if (_ownedCatalogPinIds.contains(catalogPin.id)) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("'${catalogPin.name}' is already in your collection.")),
         );
         return;
    }

    print("Adding '${catalogPin.name}' to current user's collection (ID: $_currentUserId)");
    try {
      // IMPORTANT: Add a 'catalog_pin_ref_id' column (or similar) to your 'pins' table
      // that stores 'catalogPin.id' from 'all_pins_catalog'.
      final  insertData = {
        'user_id': _currentUserId, 
        'name': catalogPin.name, 
        'image_url': catalogPin.imageUrl, 
        'notes': 'Added from catalog: ${catalogPin.name}', 
        'quantity': 1, 
        'trade_status': 'collection', 
        'status': 'In Collection', 
        'origin': catalogPin.origin,
        'release_date': catalogPin.releaseDate,
        'edition_size': catalogPin.editionSize,
        'tags': catalogPin.tags,
        'custom_set_name': catalogPin.customSetName,
        // 'catalog_pin_ref_id': catalogPin.id, // <<--- ADD THIS TO YOUR 'pins' TABLE SCHEMA
        // 'set_id': catalogPin.catalogSetId?.toInt(), // If linking to user's personal sets based on master set
      };
      // Remove null values to avoid DB errors if columns don't allow nulls
      insertData.removeWhere((key, value) => value == null);


      await supabase.from('pins').insert(insertData);

      if (mounted) {
        setState(() {
          _ownedCatalogPinIds.add(catalogPin.id); // Update local state
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'${catalogPin.name}' added to your collection!")));
      }
    } catch (e) {
      print("Error adding pin to collection: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add pin: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  void _showFilters() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Filter functionality coming soon!")));
  }
  
  void _navigateToWishlist() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wishlist page coming soon!")));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search catalog...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70)
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            : const Text("Pin Catalog"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? "Close Search" : "Search Catalog",
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear(); 
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter Pins",
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline), 
            tooltip: "My Wishlist",
            onPressed: _navigateToWishlist,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ToggleButtons(
              isSelected: [_viewMode == CatalogViewMode.pins, _viewMode == CatalogViewMode.sets],
              onPressed: (index) {
                setState(() {
                  _viewMode = index == 0 ? CatalogViewMode.pins : CatalogViewMode.sets;
                   _searchController.clear(); 
                  _fetchData(); 
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              constraints: BoxConstraints(minHeight: 38, minWidth: (MediaQuery.of(context).size.width - 48) / 2),
              children: const <Widget>[
                Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text("All Pins")),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text("Sets")),
              ],
            ),
          ),
          Expanded(child: _buildContentView()),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!, style: TextStyle(color: Colors.red[700]))));
    }

    if (_viewMode == CatalogViewMode.pins) {
      final pinsToDisplay = _filteredCatalogPins; 
      if (pinsToDisplay.isEmpty) {
        return Center(child: Text(_searchController.text.isEmpty ? "No pins found in the catalog." : "No pins match your search."));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(10.0), 
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // <<--- MODIFIED: 3 columns --- >>
          crossAxisSpacing: 8.0, 
          mainAxisSpacing: 8.0,  
          childAspectRatio: 0.62, // <<--- MODIFIED: Adjusted for 3 columns & more text --- >>
        ),
        itemCount: pinsToDisplay.length,
        itemBuilder: (context, index) {
          final pin = pinsToDisplay[index];
          final bool isWishlisted = _wishlistedPinIds.contains(pin.id);
          final bool isOwned = _ownedCatalogPinIds.contains(pin.id); // <<--- NEW
          return _buildPinCard(pin, isWishlisted, isOwned); // <<--- NEW
        },
      );
    } else { 
      if (_catalogSets.isEmpty) {
        return const Center(child: Text("No sets found in the catalog."));
      }
      return ListView.builder(
        itemCount: _catalogSets.length,
        itemBuilder: (context, index) {
          final set = _catalogSets[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            leading: set.imageUrl != null && set.imageUrl!.isNotEmpty
              ? Image.network(set.imageUrl!, width: 50, height: 50, fit: BoxFit.cover, 
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image)) 
              : const Icon(Icons.collections_bookmark, size: 40),
            title: Text(set.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(set.description ?? "No description", maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tapped on set: ${set.name}")));
            },
          );
        },
      );
    }
  }

  Widget _buildPinCard(CatalogPin pin, bool isWishlisted, bool isOwned) { // <<--- MODIFIED: Added isOwned
    String year = ""; 
    if (pin.releaseDate != null && pin.releaseDate!.isNotEmpty) {
      try {
        final date = DateTime.parse(pin.releaseDate!);
        year = date.year.toString();
      } catch (e) {
        print("Error parsing release date for pin ${pin.name}: ${pin.releaseDate}");
      }
    }
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6, // Give image a bit more space
            child: Stack(
              children: [
                Positioned.fill(
                  child: (pin.imageUrl.isNotEmpty && pin.imageUrl != 'https://placehold.co/300x300/E6E6FA/333333?text=No+Image')
                      ? Image.network(
                          pin.imageUrl,
                          fit: BoxFit.contain, 
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
                          },
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                        )
                      : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey)),
                ),
                // <<--- MODIFIED: Wishlist and Own Icons in a Row --- >>
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                     decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05), // Very subtle background for icons
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? Colors.red.shade400 : Colors.black54,
                          ),
                          iconSize: 18, // Adjusted size
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(),
                          tooltip: isWishlisted ? "Remove from Wishlist" : "Add to Wishlist",
                          onPressed: () => _toggleWishlist(pin),
                        ),
                        IconButton( // <<--- NEW "Own" Icon Button --- >>
                          icon: Icon(
                            isOwned ? Icons.library_add_check : Icons.library_add_outlined, // Option 3 (library_add)
                            color: isOwned ? theme.colorScheme.primary : Colors.black54,
                          ),
                          iconSize: 18, // Adjusted size
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(),
                          tooltip: isOwned ? "In Your Collection" : "Add to My Collection",
                          onPressed: isOwned ? null : () => _addPinToMyCollection(pin), // Disable if owned, or implement remove
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6.0, 4.0, 6.0, 2.0),
            child: Text(
              pin.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, height: 1.1), 
            ),
          ),
          // Display Series Name (from PinAndPop)
          if (pin.seriesNameFromSource != null && pin.seriesNameFromSource!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.5),
              child: Text(
                "Series: ${pin.seriesNameFromSource!}",
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.0, color: Colors.grey[700], height: 1.1),
              ),
            ),
          // Display Custom Set Name if different from Series Name
          if (pin.customSetName != null && 
              pin.customSetName!.isNotEmpty && 
              pin.customSetName != pin.seriesNameFromSource)
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0.5),
              child: Text(
                "Set: ${pin.customSetName!}",
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.0, color: Colors.grey[600], fontStyle: FontStyle.italic, height: 1.1),
              ),
            ),
          if (year.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
              child: Text(
                "Year: $year",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.0, color: Colors.grey[600], height: 1.1),
              ),
            ),
          // Removed the "Own" button from here as it's now an icon
          const SizedBox(height: 4), // Add a little bottom padding
        ],
      ),
    );
  }
}

String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inSeconds < 5) return 'just now';
  if (difference.inMinutes < 1) return '${difference.inSeconds}s ago';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat('MMM d, yyyy').format(dateTime); 
}
