// lib/screens/pin_catalog_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'user_profile_page.dart'; 
import 'main_app_shell.dart'; 
// import 'my_wishlist_page.dart'; // Placeholder for your Wishlist page
// import 'marketplace_page.dart'; // Placeholder for Marketplace navigation

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
  Set<String> _ownedCatalogPinIds = {}; 
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
        await _fetchOwnedCatalogPinIds(); 
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

  Future<void> _fetchOwnedCatalogPinIds() async {
    if (_currentUserId == null || !mounted) return;
    try {
      final response = await supabase
          .from('pins') 
          .select('catalog_pin_ref_id') 
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
    }
  }


  Future<void> _toggleWishlist(CatalogPin pin) async {
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
    
    if (_ownedCatalogPinIds.contains(catalogPin.id)) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("'${catalogPin.name}' is already in your collection.")),
         );
         return;
    }

    print("Adding '${catalogPin.name}' to current user's collection (ID: $_currentUserId)");
    try {
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
        // 'custom_set_name': catalogPin.customSetName, // This is for the catalog entry, not directly for user's pin unless you have a column
        'catalog_pin_ref_id': catalogPin.id, 
        // <<--- NEW: Add catalog_series_name to user's pin entry --- >>
        'catalog_series_name': catalogPin.seriesNameFromSource, 
        // If your 'pins' table still uses 'set_id' for a user's personal sets table,
        // you might want to prompt the user to select one of their sets or create a new one here.
        // For now, we are just copying the series name as text.
      };
      insertData.removeWhere((key, value) => value == null);

      await supabase.from('pins').insert(insertData);

      if (mounted) {
        setState(() {
          _ownedCatalogPinIds.add(catalogPin.id); 
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
  
  void _navigateToMarketplaceForPin(CatalogPin pin) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Marketplace action for '${pin.name}' coming soon!")));
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
        padding: const EdgeInsets.all(8.0), 
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, 
          crossAxisSpacing: 6.0, 
          mainAxisSpacing: 6.0,  
          childAspectRatio: 0.62, 
        ),
        itemCount: pinsToDisplay.length,
        itemBuilder: (context, index) {
          final pin = pinsToDisplay[index];
          final bool isWishlisted = _wishlistedPinIds.contains(pin.id);
          final bool isOwned = _ownedCatalogPinIds.contains(pin.id); 
          return _buildPinCard(pin, isWishlisted, isOwned); 
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

  Widget _buildPinCard(CatalogPin pin, bool isWishlisted, bool isOwned) { 
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
          Container(
            color: Colors.grey[200], 
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, 
              children: [
                IconButton(
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.red.shade400 : Colors.grey[700],
                  ),
                  iconSize: 22, 
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: isWishlisted ? "Remove from Wishlist" : "Add to Wishlist",
                  onPressed: () => _toggleWishlist(pin),
                ),
                const SizedBox(width: 4),
                IconButton( 
                  icon: Icon(
                    isOwned ? Icons.library_add_check : Icons.library_add_outlined, 
                    color: isOwned ? theme.colorScheme.primary : Colors.grey[700],
                  ),
                  iconSize: 22, 
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: isOwned ? "In Your Collection" : "Add to My Collection",
                  onPressed: isOwned ? null : () => _addPinToMyCollection(pin), 
                ),
                 const SizedBox(width: 4),
                IconButton( 
                  icon: Icon(
                    Icons.storefront_outlined, 
                    color: Colors.grey[700],
                  ),
                  iconSize: 22, 
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: "Find on Marketplace",
                  onPressed: () => _navigateToMarketplaceForPin(pin),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5, 
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
                : Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6.0, 6.0, 6.0, 2.0), 
            child: Text(
              pin.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, height: 1.2), 
            ),
          ),
          if (pin.seriesNameFromSource != null && pin.seriesNameFromSource!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
              child: Text(
                "Series: ${pin.seriesNameFromSource!}",
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey[700], height: 1.1),
              ),
            ),
          if (pin.customSetName != null && 
              pin.customSetName!.isNotEmpty && 
              pin.customSetName != pin.seriesNameFromSource)
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
              child: Text(
                "Set: ${pin.customSetName!}",
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey[600], fontStyle: FontStyle.italic, height: 1.1),
              ),
            ),
          if (year.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
              child: Text(
                "Year: $year",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.5, color: Colors.grey[600], height: 1.1),
              ),
            ),
          const SizedBox(height: 4), 
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
  return DateFormat('MMM d, yyyy').format(dateTime); // Corrected DateFormat pattern
}
