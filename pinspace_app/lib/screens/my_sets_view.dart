// lib/screens/my_sets_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting in the card
import 'package:supabase_flutter/supabase_flutter.dart';
import 'set_details_page.dart'; // Import the new details page

final supabase = Supabase.instance.client;

// --- Data Models ---
// Represents a pin to be displayed within a set card, including ownership status.
class DisplayPinInSet {
  final String displayId; // Unique ID for display purposes (can be catalogPinId or custom pin ID)
  final String name;
  final String imageUrl;
  bool isOwned; // True if the user owns this pin (always true for custom set displays)
                // For catalog sets, true if owned AND linked to the user's version of this set.

  DisplayPinInSet({
    required this.displayId,
    required this.name,
    required this.imageUrl,
    this.isOwned = false,
  });
}

// Represents a user's set, now augmented with pins to display.
class PinSet {
  final int id; // User's set ID from their 'sets' table. Will be -1 for the virtual "Uncategorized" set.
  final String name;
  final DateTime createdAt; // Will be DateTime.now() for "Uncategorized" set.
  List<DisplayPinInSet> pinsToDisplay; 
  int? originalCatalogSetId; 
  bool isVirtual; // Flag to identify the "Uncategorized Pins" set

  PinSet({
    required this.id,
    required this.name,
    required this.createdAt,
    this.pinsToDisplay = const [],
    this.originalCatalogSetId,
    this.isVirtual = false,
  });

  factory PinSet.fromMap(Map<String, dynamic> map) {
    return PinSet(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      pinsToDisplay: [], 
    );
  }
}
// --- End Data Models ---

class MySetsView extends StatefulWidget {
  const MySetsView({super.key});

  @override
  State<MySetsView> createState() => _MySetsViewState();
}

class _MySetsViewState extends State<MySetsView> {
  List<PinSet> _mySets = [];
  bool _isLoadingSets = true;
  String? _setsError;

  @override
  void initState() {
    super.initState();
    _fetchMySetsAndTheirPins();
  }

  Future<void> _fetchMySetsAndTheirPins() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() {
          _setsError = "Please log in to see your sets.";
          _isLoadingSets = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingSets = true;
        _setsError = null;
      });
    }

    try {
      final userId = supabase.auth.currentUser!.id;

      // 1. Fetch user's actual sets
      final userSetsResponse = await supabase
          .from('sets')
          .select('id, name, created_at')
          .eq('user_id', userId)
          .order('name', ascending: true);

      final List<PinSet> fetchedUserSets = (userSetsResponse as List<dynamic>)
          .map((data) => PinSet.fromMap(data as Map<String, dynamic>))
          .toList();

      // 2. Get owned catalog pins linked to user sets
      final ownedPinsResponse = await supabase
          .from('pins')
          .select('catalog_pin_ref_id, set_id')
          .eq('user_id', userId)
          .not('catalog_pin_ref_id', 'is', null)
          .not('set_id', 'is', null);

      final List<Map<String,dynamic>> ownedUserPinsData = (ownedPinsResponse as List<dynamic>).cast<Map<String,dynamic>>();
      final Map<int, Set<int>> ownedCatalogPinRefsByUsersSetId = {};
      for (var ownedPinData in ownedUserPinsData) {
          final userSetId = ownedPinData['set_id'] as int?;
          final catalogPinRefId = ownedPinData['catalog_pin_ref_id'] as int?;
          if (userSetId != null && catalogPinRefId != null) {
              ownedCatalogPinRefsByUsersSetId.putIfAbsent(userSetId, () => {}).add(catalogPinRefId);
          }
      }

      List<PinSet> setsWithPinDetails = [];

      for (PinSet userSet in fetchedUserSets) {
        List<DisplayPinInSet> pinsForThisSetDisplay = [];
        final catalogSetInfoResponse = await supabase
            .from('all_sets_catalog')
            .select('id')
            .eq('name', userSet.name)
            .maybeSingle();

        int? originalCatalogSetId;
        if (catalogSetInfoResponse != null && catalogSetInfoResponse['id'] != null) {
          originalCatalogSetId = catalogSetInfoResponse['id'] as int;
        }
        userSet.originalCatalogSetId = originalCatalogSetId;

        if (originalCatalogSetId != null) {
          // Matched with a catalog set: Fetch all pins from catalog for this set
          final allCatalogPinsInSetResponse = await supabase
              .from('all_pins_catalog')
              .select('id, name, image_url')
              .eq('catalog_set_id', originalCatalogSetId);

          final List<dynamic> allCatalogPinsData = allCatalogPinsInSetResponse as List<dynamic>;
          final Set<int> ownedCatalogPinIdsForThisUserSet = ownedCatalogPinRefsByUsersSetId[userSet.id] ?? {};

          for (var catalogPinData in allCatalogPinsData) {
            final catalogPinMap = catalogPinData as Map<String, dynamic>;
            final catalogPinIdFromDb = catalogPinMap['id'] as int;
            pinsForThisSetDisplay.add(DisplayPinInSet(
              displayId: catalogPinIdFromDb.toString(),
              name: catalogPinMap['name'] as String,
              imageUrl: catalogPinMap['image_url'] as String? ?? 'https://placehold.co/70x70/E6E6FA/333333?text=N/A',
              isOwned: ownedCatalogPinIdsForThisUserSet.contains(catalogPinIdFromDb),
            ));
          }
          // Sort pins: owned first, then by name (or ID if names are not unique enough)
          pinsForThisSetDisplay.sort((a, b) {
            if (a.isOwned && !b.isOwned) return -1; // a (owned) comes before b (not owned)
            if (!a.isOwned && b.isOwned) return 1;  // b (owned) comes before a (not owned)
            return a.name.compareTo(b.name); // Optional: sort by name within owned/unowned groups
          });

        } else {
          // User-created set not matched in catalog: Fetch user's pins directly linked to this set
          print("User set '${userSet.name}' (ID: ${userSet.id}) not found in catalog. Fetching user's pins for this set.");
          final userOwnedPinsInThisSetResponse = await supabase
              .from('pins') // User's collection
              .select('id, name, image_url, catalog_pin_ref_id') // Select 'id' from 'pins' table for fallback displayId
              .eq('user_id', userId)
              .eq('set_id', userSet.id)
              .order('name', ascending: true); // Order custom set pins by name

          final List<dynamic> userOwnedPinsDataForCustomSet = userOwnedPinsInThisSetResponse as List<dynamic>;
          for (var ownedPinData in userOwnedPinsDataForCustomSet) {
              final ownedPinMap = ownedPinData as Map<String, dynamic>;
              final String displayId = (ownedPinMap['catalog_pin_ref_id']?.toString()) ?? "custom_${ownedPinMap['id']}";
              pinsForThisSetDisplay.add(DisplayPinInSet(
                  displayId: displayId,
                  name: ownedPinMap['name'] as String,
                  imageUrl: ownedPinMap['image_url'] as String? ?? 'https://placehold.co/70x70/E6E6FA/333333?text=N/A',
                  isOwned: true, 
              ));
          }
        }
        userSet.pinsToDisplay = pinsForThisSetDisplay;
        setsWithPinDetails.add(userSet);
      }
      
      // 4. Fetch uncategorized pins and add as a virtual set
      final uncategorizedPinsResponse = await supabase
          .from('pins')
          .select('id, name, image_url, catalog_pin_ref_id')
          .eq('user_id', userId)
          .filter('set_id', 'is', null) 
          .order('name', ascending: true); // Order uncategorized pins by name

      List<DisplayPinInSet> uncategorizedDisplayPins = [];
      for (var pinData in (uncategorizedPinsResponse as List<dynamic>)) {
          final pinMap = pinData as Map<String, dynamic>;
          final String displayId = (pinMap['catalog_pin_ref_id']?.toString()) ?? "custom_${pinMap['id']}";
          uncategorizedDisplayPins.add(DisplayPinInSet(
              displayId: displayId,
              name: pinMap['name'] as String,
              imageUrl: pinMap['image_url'] as String? ?? 'https://placehold.co/70x70/E6E6FA/333333?text=N/A',
              isOwned: true, // All are owned
          ));
      }

      if (uncategorizedDisplayPins.isNotEmpty) {
          setsWithPinDetails.add(PinSet(
              id: -1, // Special ID for virtual set
              name: "Uncategorized Pins",
              createdAt: DateTime.now(), // Not relevant but required by model
              pinsToDisplay: uncategorizedDisplayPins,
              isVirtual: true,
          ));
      }


      if (mounted) {
        setState(() {
          _mySets = setsWithPinDetails;
          _isLoadingSets = false;
        });
      }
    } catch (e) {
      print("Error fetching sets and their pins: $e");
      if (e is PostgrestException) {
        print("PostgrestException details: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}");
      }
      if (mounted) {
        setState(() {
          _setsError = "Failed to fetch sets: ${e.toString()}";
          _isLoadingSets = false;
        });
      }
    }
  }

  Future<void> _deleteSet(PinSet setToDelete) async {
    if (setToDelete.isVirtual || supabase.auth.currentUser == null) return; // Cannot delete virtual set

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete the set "${setToDelete.name}"? Pins in this set will become uncategorized.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await supabase.from('sets').delete().match({'id': setToDelete.id, 'user_id': supabase.auth.currentUser!.id});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Set "${setToDelete.name}" deleted successfully.')),
          );
          _fetchMySetsAndTheirPins();
        }
      } catch (e) {
        print("Error deleting set: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete set: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }


  Widget _buildPinsDisplaySection(PinSet set, ThemeData theme) {
    if (set.pinsToDisplay.isEmpty) {
      String message = set.isVirtual 
          ? "No uncategorized pins found." 
          : (set.originalCatalogSetId != null
            ? "No pins found in the main catalog for this set."
            : "No pins added to this custom set yet.");
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(message, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700])),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: set.pinsToDisplay.length,
            itemBuilder: (context, index) {
              final pinDisplay = set.pinsToDisplay[index];
              Widget imageWidget = ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: Image.network(
                  pinDisplay.imageUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                        width: 70, height: 70,
                        color: Colors.grey[200],
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(width: 70, height: 70, color: Colors.grey[200], child: Icon(Icons.broken_image, size: 30, color: Colors.grey[400])),
                ),
              );

              if (set.originalCatalogSetId != null && !pinDisplay.isOwned) {
                imageWidget = ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ]),
                  child: Opacity(opacity: 0.6, child: imageWidget),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Tooltip(
                  message: set.originalCatalogSetId != null 
                           ? "${pinDisplay.name}${pinDisplay.isOwned ? ' (Owned)' : ' (Missing)'}"
                           : pinDisplay.name,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (set.originalCatalogSetId != null && !pinDisplay.isOwned)
                               ? Colors.red.withOpacity(0.7)
                               : Colors.transparent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6.0),
                      color: (set.originalCatalogSetId != null && pinDisplay.isOwned) 
                             ? Colors.green.withOpacity(0.1) 
                             : Colors.transparent,
                    ),
                    child: imageWidget,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildSetCard(PinSet set) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SetDetailsPage(set: set, isUncategorizedSet: set.isVirtual),
          ),
        );
      },
      child: Card(
        elevation: 2.0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      set.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: const Color(0xFF3d4895),
                        fontSize: 16, 
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!set.isVirtual && set.originalCatalogSetId == null) 
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Delete Set",
                      onPressed: () => _deleteSet(set),
                    ),
                ],
              ),
              const SizedBox(height: 6), 
              _buildPinsDisplaySection(set, theme), 
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_setsError != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_setsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_mySets.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("You haven't created any sets yet or have no uncategorized pins. Add pins from the catalog or create custom sets!", textAlign: TextAlign.center),
      ));
    }
    return RefreshIndicator(
      onRefresh: _fetchMySetsAndTheirPins, 
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0), 
        itemCount: _mySets.length,
        itemBuilder: (context, index) {
          return _buildSetCard(_mySets[index]);
        },
      ),
    );
  }
}
