// lib/screens/pin_catalog_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Required for Timer for debouncing

final supabase = Supabase.instance.client;

// Model for pins from the all_pins_catalog table
class CatalogPin {
  final String id; // This is a String representation of the bigint ID from the database
  final String name;
  final String imageUrl;
  final String? description;
  final String? origin;
  final String? releaseDate;
  final String? editionSize;
  final String? customSetName;
  final String? tags;
  final String? sourcePinId;
  final BigInt? catalogSetId; // ID from all_sets_catalog
  final String? seriesNameFromSource; // Name from all_sets_catalog.name

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
      seriesNameFromSource: map['series_name_from_source'] as String?, // This is populated by the join
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
  List<CatalogSet> _catalogSets = [];

  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  Set<String> _wishlistedPinIds = {};
  Set<String> _ownedCatalogPinIds = {}; // Stores string IDs of pins from all_pins_catalog that are owned
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Pagination variables
  int _currentPage = 0;
  final int _pageSize = 30; // Fetch 30 items per page
  bool _hasMorePins = true; // True if there might be more pins to load

  Timer? _debounce; // For debouncing search input

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _searchController.addListener(_onSearchChanged);
    _fetchData(); // Initial data fetch
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Handles search input changes with a debounce to prevent too many API calls
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Only trigger a new search if the view mode is pins
      if (_viewMode == CatalogViewMode.pins && mounted) {
        // Reset pagination and fetch pins based on the new search query
        setState(() {
          _currentPage = 0;
          _catalogPins.clear(); // Clear existing pins for new search results
          _hasMorePins = true; // Assume there might be more results
          _isLoading = true; // Show loading indicator
        });
        _fetchCatalogPins(searchQuery: _searchController.text);
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
        // When switching view mode or initial load, reset pagination and fetch first page
        _currentPage = 0;
        _catalogPins.clear();
        _hasMorePins = true;
        await _fetchCatalogPins(searchQuery: _searchController.text);
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

  Future<void> _fetchCatalogPins({String? searchQuery}) async {
    if (!mounted) return;
    setState(() {
      if (_currentPage == 0) {
        _isLoading = true; // Show loading on initial load or new search
      }
      _error = null;
    });

    try {
      // Start building the query by selecting columns.
      // This returns a PostgrestFilterBuilder.
      var query = supabase
          .from('all_pins_catalog')
          .select('*, all_sets_catalog:catalog_set_id(name)');

      // Apply search filter if query is provided and not empty
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final String searchPattern = '%${searchQuery.toLowerCase()}%';
        // Apply the 'or' filter. Removed 'all_sets_catalog.name.ilike'
        // from this OR clause to fix the 400 error, as directly filtering
        // on joined table columns within a single OR string isn't directly supported
        // in this manner by the Supabase client.
        query = query.or(
          'name.ilike.$searchPattern,'
          'tags.ilike.$searchPattern,'
          'origin.ilike.$searchPattern,'
          'custom_set_name.ilike.$searchPattern',
        );
      }

      // Now apply order and pagination.
      // These methods (`order` and `range`) return a PostgrestTransformBuilder.
      // We can chain them directly and then await the final builder.
      final int offset = _currentPage * _pageSize;
      final response = await query
          .order('name', ascending: true) // Returns PostgrestTransformBuilder
          .range(offset, offset + _pageSize - 1); // Returns PostgrestTransformBuilder

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;

      List<CatalogPin> fetchedPins = data.map((map) {
        final pinMap = map as Map<String, dynamic>;
        final setInfo = pinMap['all_sets_catalog'] as Map<String, dynamic>?;
        String? seriesName;

        if (setInfo != null) {
          seriesName = setInfo['name'] as String?;
        }
        pinMap['series_name_from_source'] = seriesName;
        return CatalogPin.fromMap(pinMap);
      }).toList();

      setState(() {
        if (_currentPage == 0) {
          _catalogPins = fetchedPins; // Replace for initial load or new search
        } else {
          _catalogPins.addAll(fetchedPins); // Append for pagination
        }
        _hasMorePins = fetchedPins.length == _pageSize; // If we got less than page size, no more pages
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load pins: ${e.toString()}";
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

  Future<void> _loadMorePins() async {
    if (_isLoading || !_hasMorePins) return;
    setState(() {
      _isLoading = true; // Indicate loading for next page
    });
    _currentPage++;
    await _fetchCatalogPins(searchQuery: _searchController.text);
  }

  Future<void> _fetchCatalogSets() async {
    final response = await supabase
        .from('all_sets_catalog')
        .select()
        .order('name', ascending: true)
        .limit(100); // Sets not paginated as per request focus

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
          .from('pins') // User's own pins table
          .select('catalog_pin_ref_id') // This links back to all_pins_catalog.id
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
      _showSnackBar(context, "You need to be logged in to manage your wishlist.");
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
      final catalogPinIdAsInt = int.tryParse(pin.id);
      if (catalogPinIdAsInt == null) {
        throw Exception("Invalid pin ID format for wishlist operation.");
      }

      if (isCurrentlyWishlisted) {
        await supabase.from('user_wishlist').delete().match({'user_id': _currentUserId!, 'pin_catalog_id': catalogPinIdAsInt});
        if (mounted) _showSnackBar(context, "'${pin.name}' removed from wishlist.");
      } else {
        await supabase.from('user_wishlist').insert({'user_id': _currentUserId!, 'pin_catalog_id': catalogPinIdAsInt});
        if (mounted) _showSnackBar(context, "'${pin.name}' added to wishlist!");
      }
    } catch (e) {
      print("Error toggling wishlist: $e");
      if (mounted) {
        setState(() { // Revert optimistic UI update on error
          if (isCurrentlyWishlisted) _wishlistedPinIds.add(pin.id);
          else _wishlistedPinIds.remove(pin.id);
        });
        _showSnackBar(context, "Error updating wishlist: ${e.toString()}", isError: true);
      }
    }
  }

  Future<void> _addPinToMyCollection(CatalogPin catalogPin) async {
    if (_currentUserId == null || !mounted) {
      _showSnackBar(context, "You need to be logged in to add pins.");
      return;
    }

    if (_ownedCatalogPinIds.contains(catalogPin.id)) {
      _showSnackBar(context, "'${catalogPin.name}' is already in your collection.");
      return;
    }

    print("--- Adding Pin to Collection ---");
    print("CatalogPin ID (String): ${catalogPin.id}");
    print("CatalogPin Name: ${catalogPin.name}");
    print("CatalogPin Series Name from Source (Set Name): ${catalogPin.seriesNameFromSource}");

    try {
      int? userSetIdForPinRecord; // Will hold the ID from the user's 'sets' table (type: int)
      final String? catalogSetName = catalogPin.seriesNameFromSource;

      // If the pin from the catalog has an associated set name
      if (catalogSetName != null && catalogSetName.isNotEmpty) {
        // Check if this set already exists in the user's 'sets' table
        final setLookupResponse = await supabase
            .from('sets')
            .select('id')
            .eq('user_id', _currentUserId!)
            .eq('name', catalogSetName)
            .maybeSingle();

        if (setLookupResponse != null && setLookupResponse['id'] != null) {
          // Set already exists for the user
          userSetIdForPinRecord = setLookupResponse['id'] as int?;
          print("Set '$catalogSetName' already exists for user with ID: $userSetIdForPinRecord");
        } else {
          // Set does not exist for the user, so insert it into their 'sets' table
          print("Set '$catalogSetName' does not exist for user. Adding it now...");
          final newSetResponse = await supabase
              .from('sets')
              .insert({
                'user_id': _currentUserId!,
                'name': catalogSetName,
              })
              .select('id')
              .single();

          userSetIdForPinRecord = newSetResponse['id'] as int?;
          print("New set '$catalogSetName' added for user with ID: $userSetIdForPinRecord");
        }
      }

      // Prepare data for inserting into the user's 'pins' table
      final insertPinData = {
        'user_id': _currentUserId,
        'name': catalogPin.name,
        'image_url': catalogPin.imageUrl,
        'notes': null,
        'quantity': 1,
        'trade_status': 'collection',
        'status': 'In Collection',
        'origin': catalogPin.origin,
        'release_date': catalogPin.releaseDate,
        'edition_size': catalogPin.editionSize,
        'tags': catalogPin.tags,
        'catalog_pin_ref_id': int.tryParse(catalogPin.id),
        'catalog_series_name': catalogPin.seriesNameFromSource,
        'set_id': userSetIdForPinRecord,
      };

      print("Data to be inserted into 'pins' table (before removing nulls): $insertPinData");
      insertPinData.removeWhere((key, value) => value == null);
      print("Data for 'pins' table after removing nulls: $insertPinData");

      await supabase.from('pins').insert(insertPinData);

      if (mounted) {
        setState(() {
          _ownedCatalogPinIds.add(catalogPin.id);
        });
        _showSnackBar(context, "'${catalogPin.name}' added to your collection!");
      }
    } catch (e) {
      print("Error adding pin to collection or handling set: $e");
      if (e is PostgrestException) {
          print("PostgrestException details: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}");
      }
      if (mounted) {
        _showSnackBar(context, "Failed to add pin: ${e.toString()}", isError: true);
      }
    }
  }

  // Custom SnackBar function to avoid direct ScaffoldMessenger calls repeatedly
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _showFilters() {
    _showSnackBar(context, "Filter functionality coming soon!");
  }

  void _navigateToWishlist() {
    _showSnackBar(context, "Wishlist page coming soon!");
    // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => MyWishlistPage()));
  }

  void _navigateToMarketplaceForPin(CatalogPin pin) {
    _showSnackBar(context, "Marketplace action for '${pin.name}' coming soon!");
    // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => MarketplacePage(pinId: pin.id)));
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
                  // When closing search, trigger a refresh to show all pins on the first page
                  _currentPage = 0;
                  _catalogPins.clear();
                  _hasMorePins = true;
                  _fetchCatalogPins();
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
                  _searchController.clear(); // Clear search on view mode switch
                  _isLoading = true; // Show loading when switching view
                  _fetchData(); // Refetch data for the new view mode
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              // Use Expanded to make buttons fill available width, or a flexible layout.
              // Here, I'm adjusting minWidth using media query, but let's try a more flexible approach.
              // Removed fixed constraints for better responsiveness on smaller screens.
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 2) - 16, // Half width minus padding
                  child: const Center(child: Text("All Pins")),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 2) - 16, // Half width minus padding
                  child: const Center(child: Text("Sets")),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContentView()),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    if (_isLoading && _catalogPins.isEmpty && _catalogSets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!, style: TextStyle(color: Colors.red[700]))));
    }

    if (_viewMode == CatalogViewMode.pins) {
      final pinsToDisplay = _catalogPins; // Now _catalogPins directly holds the filtered/paginated data
      if (pinsToDisplay.isEmpty) {
        return Center(child: Text(_searchController.text.isEmpty ? "No pins found in the catalog." : "No pins match your search."));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6.0,
          mainAxisSpacing: 6.0,
          childAspectRatio: 0.65, // Adjusted slightly to allow more vertical space
        ),
        itemCount: pinsToDisplay.length + (_hasMorePins ? 1 : 0), // Add one for the "Load More" button
        itemBuilder: (context, index) {
          if (index == pinsToDisplay.length) {
            // This is the "Load More" button
            return Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _hasMorePins ? _loadMorePins : null,
                      child: const Text("Load More"),
                    ),
            );
          }
          final pin = pinsToDisplay[index];
          final bool isWishlisted = _wishlistedPinIds.contains(pin.id);
          final bool isOwned = _ownedCatalogPinIds.contains(pin.id);
          return _buildPinCard(pin, isWishlisted, isOwned);
        },
      );
    } else { // CatalogViewMode.sets
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
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40))
                : const Icon(Icons.collections_bookmark, size: 40),
            title: Text(set.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(set.description ?? "No description", maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              _showSnackBar(context, "Tapped on catalog set: ${set.name}");
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
        print("Error parsing release date for pin ${pin.name}: ${pin.releaseDate}, Error: $e");
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
          Container( // Header for action buttons
            color: Colors.grey[200],
            // Reduced horizontal and vertical padding for tighter fit
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Adjusted iconSize and padding for all buttons
                IconButton(
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.red.shade400 : Colors.grey[700],
                  ),
                  iconSize: 20, // Slightly smaller icon size
                  padding: const EdgeInsets.all(2), // Reduced padding
                  constraints: const BoxConstraints(), // No default constraints
                  tooltip: isWishlisted ? "Remove from Wishlist" : "Add to Wishlist",
                  onPressed: () => _toggleWishlist(pin),
                ),
                const SizedBox(width: 2), // Reduced spacing between buttons
                IconButton(
                  icon: Icon(
                    isOwned ? Icons.library_add_check : Icons.library_add_outlined,
                    color: isOwned ? theme.colorScheme.primary : Colors.grey[700],
                  ),
                  iconSize: 20, // Slightly smaller icon size
                  padding: const EdgeInsets.all(2), // Reduced padding
                  constraints: const BoxConstraints(), // No default constraints
                  tooltip: isOwned ? "In Your Collection" : "Add to My Collection",
                  onPressed: isOwned ? null : () => _addPinToMyCollection(pin),
                ),
                const SizedBox(width: 2), // Reduced spacing between buttons
                IconButton(
                  icon: Icon(
                    Icons.storefront_outlined,
                    color: Colors.grey[700],
                  ),
                  iconSize: 20, // Slightly smaller icon size
                  padding: const EdgeInsets.all(2), // Reduced padding
                  constraints: const BoxConstraints(), // No default constraints
                  tooltip: "Find on Marketplace",
                  onPressed: () => _navigateToMarketplaceForPin(pin),
                ),
              ],
            ),
          ),
          Expanded( // For the image
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
          Padding( // For pin name
            padding: const EdgeInsets.fromLTRB(6.0, 6.0, 6.0, 2.0),
            child: Text(
              pin.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, height: 1.2),
            ),
          ),
          // Display Series/Set Name if available
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
          // Display Custom Set Name if available and different from series name
          if (pin.customSetName != null &&
              pin.customSetName!.isNotEmpty &&
              pin.customSetName != pin.seriesNameFromSource) // Avoid redundancy
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
          if (year.isNotEmpty) // Display year if parsed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
              child: Text(
                "Year: $year",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.5, color: Colors.grey[600], height: 1.1),
              ),
            ),
          const SizedBox(height: 4), // Bottom padding
        ],
      ),
    );
  }
}

// Helper function for formatting time (if needed elsewhere, otherwise can be local or removed)
String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inSeconds < 5) return 'just now';
  if (difference.inMinutes < 1) return '${difference.inSeconds}s ago';
  if (difference.inHours < 1) return '${difference.inHours}h ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat('MMM d,yyyy').format(dateTime);
}
