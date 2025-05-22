// lib/screens/my_pins_page.dart
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math; // For the flip animation
import 'package:image_picker/image_picker.dart'; // For picking images
import 'dart:typed_data'; // For Uint8List
import 'package:http/http.dart' as http; // For API calls

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

// --- CONFIGURATION (from scanner_page, ensure it's accessible or defined here too) ---
const String pythonApiUrl = 'https://colejunck1.pythonanywhere.com/remove-background';


// --- Data Models ---
enum ImageTarget { front, back }

class Pin {
  final int id;
  String name; // Make mutable if editing directly on this object
  String imageUrl; // Front image - Make mutable
  String? imageBackUrl;
  String? setName; // This will hold the resolved set name for display
  int? setId; // Foreign key to the user's 'sets' table
  int quantity; // Make mutable
  final DateTime addedAt;

  // Additional fields from the 'pins' table that might be useful for display or editing in the modal
  String? notes;
  String? tradeStatus;
  String? status;
  int? catalogPinRefId; // Reference to the original catalog pin
  String? editionSize;
  String? origin;
  String? releaseDate; // Stored as date in DB, might need formatting for display
  String? tags;
  String? customSetNameFromPinTable; // If user manually types a set name directly on the pin record
  String? catalogSeriesNameFromPinTable; // The series/set name from all_pins_catalog, stored in pins table

  Pin({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.imageBackUrl,
    this.setName,
    this.setId,
    required this.quantity,
    required this.addedAt,
    this.notes,
    this.tradeStatus,
    this.status,
    this.catalogPinRefId,
    this.editionSize,
    this.origin,
    this.releaseDate,
    this.tags,
    this.customSetNameFromPinTable,
    this.catalogSeriesNameFromPinTable,
  });

  factory Pin.fromMap(Map<String, dynamic> map) {
    String? resolvedSetName;

    // Priority for resolving setName:
    // 1. If linked to a user's custom set (via set_id and join with 'sets' table).
    //    The Supabase query 'sets!pins_set_id_fkey(name)' populates map['sets'].
    if (map['sets'] != null && map['sets'] is Map && map['sets']['name'] != null) {
      resolvedSetName = map['sets']['name'] as String?;
    }

    // 2. If not in a user's custom set, use the 'catalog_series_name' from the 'pins' table.
    //    This field is populated when a pin is added from 'all_pins_catalog'.
    if (resolvedSetName == null && map['catalog_series_name'] != null) {
      resolvedSetName = map['catalog_series_name'] as String?;
    }

    // 3. Fallback: If still no set name, use 'custom_set_name' from the 'pins' table.
    //    This could be a user-entered value if they didn't link to a formal set.
    if (resolvedSetName == null && map['custom_set_name'] != null) {
        resolvedSetName = map['custom_set_name'] as String?;
    }

    return Pin(
      id: map['id'] as int,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String,
      imageBackUrl: map['image_back_url'] as String?,
      setId: map['set_id'] as int?, // FK to user's 'sets' table
      setName: resolvedSetName,     // The resolved set name for display
      quantity: map['quantity'] as int? ?? 1, // Default to 1 if null
      addedAt: DateTime.parse(map['added_at'] as String),
      // Populate other fields from the map
      notes: map['notes'] as String?,
      tradeStatus: map['trade_status'] as String?,
      status: map['status'] as String?,
      catalogPinRefId: map['catalog_pin_ref_id'] as int?,
      editionSize: map['edition_size'] as String?,
      origin: map['origin'] as String?,
      releaseDate: map['release_date'] as String?, // Assuming it's string; parse if DateTime
      tags: map['tags'] as String?,
      customSetNameFromPinTable: map['custom_set_name'] as String?, // From 'pins' table
      catalogSeriesNameFromPinTable: map['catalog_series_name'] as String?, // From 'pins' table
    );
  }

  // Method to create a copy with updated values, useful for immutable state updates
    Pin copyWith({
    String? name,
    String? imageUrl,
    String? imageBackUrl,
    // Allow explicitly setting setName to null to "unset" it if needed by the logic
    // However, setName is usually derived, so direct update might be less common here.
    String? setName,
    int? setId,     // Allow clearing by passing null
    int? quantity,
    String? notes,
    String? tradeStatus,
    String? status,
    int? catalogPinRefId,
    String? editionSize,
    String? origin,
    String? releaseDate,
    String? tags,
    String? customSetNameFromPinTable,
    String? catalogSeriesNameFromPinTable,
  }) {
    return Pin(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBackUrl: imageBackUrl ?? this.imageBackUrl,
      setName: setName ?? this.setName,
      setId: setId ?? this.setId,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt,
      notes: notes ?? this.notes,
      tradeStatus: tradeStatus ?? this.tradeStatus,
      status: status ?? this.status,
      catalogPinRefId: catalogPinRefId ?? this.catalogPinRefId,
      editionSize: editionSize ?? this.editionSize,
      origin: origin ?? this.origin,
      releaseDate: releaseDate ?? this.releaseDate,
      tags: tags ?? this.tags,
      customSetNameFromPinTable: customSetNameFromPinTable ?? this.customSetNameFromPinTable,
      catalogSeriesNameFromPinTable: catalogSeriesNameFromPinTable ?? this.catalogSeriesNameFromPinTable,
    );
  }
}

class PinSet {
  final int id;
  final String name;
  final DateTime createdAt; // Assuming 'created_at' is always present

  PinSet({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory PinSet.fromMap(Map<String, dynamic> map) {
    return PinSet(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
// --- End Data Models ---

class MyPinsPage extends StatefulWidget {
  const MyPinsPage({super.key});

  @override
  State<MyPinsPage> createState() => _MyPinsPageState();
}

class _MyPinsPageState extends State<MyPinsPage> {
  int _selectedViewIndex = 0; // 0 for "My Sets", 1 for "My Collection" (pins)
  List<Pin> _myPins = [];
  bool _isLoadingPins = false;
  String? _pinsError;
  List<PinSet> _mySets = [];
  bool _isLoadingSets = false;
  String? _setsError;

  @override
  void initState() {
    super.initState();
    _fetchMyData(); // Initial data fetch based on the default view
  }

  void _fetchMyData() {
    if (_selectedViewIndex == 0) { // "My Sets" view is active
      _fetchMySets(); // Prioritize fetching sets
      // Optionally fetch pins if they are needed for context (e.g., pin counts per set)
      // or if the user might quickly switch views.
      if (_myPins.isEmpty && !_isLoadingPins) _fetchMyPins();
    } else { // "My Collection" (pins) view is active
      _fetchMyPins(); // Prioritize fetching pins
      // Fetch sets as well, as they are needed for the pin editing modal (dropdown)
      if (_mySets.isEmpty && !_isLoadingSets) _fetchMySets();
    }
  }

  // Callback function for the modal to trigger a refresh of pin data
  Future<void> _refreshPinData() async {
    await _fetchMyPins();
    // If set information on the pin card might change due to pin edit,
    // you might also need to refresh sets if that data is directly displayed or used.
    // However, typically, editing a pin's set link doesn't change the set list itself.
  }


  Future<void> _fetchMyPins() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() { _pinsError = "Please log in to see your pins."; _isLoadingPins = false; });
      }
      return;
    }
    if (mounted) {
      setState(() { _isLoadingPins = true; _pinsError = null; });
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      // Select all columns from 'pins' table.
      // Join with 'sets' table using the foreign key 'pins_set_id_fkey' to get the name of the user's custom set.
      // 'catalog_series_name' and 'custom_set_name' are directly selected from the 'pins' table.
      final response = await supabase
          .from('pins')
          .select('*, image_back_url, sets!pins_set_id_fkey(name)') // Joins with user's 'sets' table
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      // Supabase client returns List<dynamic> which needs to be cast.
      final List<dynamic> pinsDataDynamic = response;
      final List<Map<String, dynamic>> pinsData = pinsDataDynamic.cast<Map<String, dynamic>>();

      // The Pin.fromMap factory will now use the logic to determine 'setName'
      final pins = pinsData.map((item) => Pin.fromMap(item)).toList();

      if (mounted) {
        setState(() {
          _myPins = pins;
          _isLoadingPins = false;
        });
      }
    } catch (e) {
      print("Error fetching pins: $e");
      if (mounted) {
        setState(() {
          _pinsError = "Failed to fetch pins: ${e.toString()}";
          _isLoadingPins = false;
        });
      }
    }
  }

  Future<void> _fetchMySets() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() { _setsError = "Please log in to see your sets."; _isLoadingSets = false; });
      }
      return;
    }
    if (mounted) {
      setState(() { _isLoadingSets = true; _setsError = null; });
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      // Fetches sets created by the current user.
      final response = await supabase
          .from('sets')
          .select('id, name, created_at') // Ensure all fields needed by PinSet.fromMap are here
          .eq('user_id', userId)
          .order('created_at', ascending: false); // Or 'name', ascending: true

      final List<dynamic> setsDataDynamic = response;
      final List<Map<String, dynamic>> setsData = setsDataDynamic.cast<Map<String, dynamic>>();

      final sets = setsData.map((item) => PinSet.fromMap(item)).toList();

      if (mounted) {
        setState(() {
          _mySets = sets;
          _isLoadingSets = false;
        });
      }
    } catch (e) {
      print("Error fetching sets: $e");
      if (mounted) {
        setState(() {
          _setsError = "Failed to fetch sets: ${e.toString()}";
          _isLoadingSets = false;
        });
      }
    }
  }

  // Shows the detailed modal for a specific pin.
  void _showPinDetailsModal(BuildContext context, Pin pin) {
    showDialog(
      context: context,
      barrierDismissible: true, // Allows dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 5,
          backgroundColor: Colors.transparent, // Modal content will provide its own background
          child: _PinDetailsModalContent(
            pin: pin,
            onPinUpdated: () { // Callback to refresh data on the main page after an update
              _refreshPinData();
            }
          ),
        );
      },
    );
  }


  // Builds a card widget for a single pin.
  Widget _buildPinCard(Pin pin) {
    return GestureDetector(
      onTap: () => _showPinDetailsModal(context, pin), // Show details on tap
      child: Card(
        elevation: 3.0,
        margin: const EdgeInsets.all(6.0),
        clipBehavior: Clip.antiAlias, // Ensures content respects card's rounded corners
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Make children fill width
          children: [
            Expanded( // Image container
              child: Container(
                color: Colors.grey[100], // Placeholder background for image
                child: Image.network(
                  pin.imageUrl,
                  fit: BoxFit.contain, // Show entire image, might leave empty space
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child; // Image loaded
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6200EA)));
                  },
                  errorBuilder: (context, error, stackTrace) => // Display if image fails to load
                      Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 48)),
                ),
              ),
            ),
            Padding( // Text content padding
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                children: [
                  Text(
                    pin.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF311B92)),
                    maxLines: 2, // Prevent overly long names from breaking layout
                    overflow: TextOverflow.ellipsis, // Add "..." for overflow
                  ),
                  const SizedBox(height: 3),
                  // Display set name if available
                  if (pin.setName != null && pin.setName!.isNotEmpty)
                    Text(
                      "Set: ${pin.setName}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text( // Display quantity
                    "Qty: ${pin.quantity}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a card widget for a single set.
  Widget _buildSetCard(PinSet set) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(set.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text("Created: ${set.createdAt.toLocal().toString().substring(0,10)}"), // Format date nicely
        onTap: () {
          // Placeholder for future functionality, e.g., viewing pins in this set.
          print("Tapped on set: ${set.name} (ID: ${set.id})");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Tapped on set: ${set.name}. Pin filtering for this set coming soon!"))
          );
        },
      ),
    );
  }

  // Builds the view for "My Collection" tab (list of pins).
  Widget _buildMyCollectionTabView() {
    if (_isLoadingPins) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pinsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_pinsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_myPins.isEmpty) {
      // Informative message when no pins are present.
      return const Center(child: Text("Your pin collection is empty. Add pins from the catalog or scan new ones!"));
    }

    // Grid view for displaying pins, with pull-to-refresh.
    return RefreshIndicator(
      onRefresh: _fetchMyPins, // Refetch pins on pull
      child: GridView.builder(
        padding: const EdgeInsets.all(12.0), // Padding around the grid
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Number of columns in the grid
          childAspectRatio: 0.7, // Aspect ratio of grid items (width / height)
          crossAxisSpacing: 10.0, // Spacing between columns
          mainAxisSpacing: 10.0,  // Spacing between rows
        ),
        itemCount: _myPins.length,
        itemBuilder: (context, index) {
          return _buildPinCard(_myPins[index]); // Build a card for each pin
        },
      ),
    );
  }

  // Builds the view for "My Sets" tab (list of sets).
  Widget _buildMySetsTabView() {
      if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_setsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_setsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_mySets.isEmpty) {
      // Informative message when no sets are present.
      // TODO: Consider adding a button or prompt to guide user to create their first set.
      return const Center(child: Text("You haven't created any sets yet."));
    }
    // List view for displaying sets, with pull-to-refresh.
      return RefreshIndicator(
      onRefresh: _fetchMySets, // Refetch sets on pull
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0), // Padding at the top of the list
        itemCount: _mySets.length,
        itemBuilder: (context, index) {
          return _buildSetCard(_mySets[index]); // Build a card for each set
        },
      ),
    );
  }

  // Builds the segmented control for switching between "My Sets" and "My Collection" views.
  Widget _buildSegmentedControl(BuildContext context) {
    // Define colors for consistent styling.
    const Color accentGold = Color(0xFFFFC107);
    const Color lightBackground = Color(0xFFF0F2F5);
    const Color unselectedText = Color(0xFF424242);
    const Color selectedText = Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0), // No horizontal margin for full-width feel if desired
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container( // Inner container for styling the segmented control itself
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: lightBackground,
          borderRadius: BorderRadius.circular(25.0), // Rounded corners for the control
          boxShadow: [ // Subtle shadow for depth
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Button for "My Sets"
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 0 ? accentGold : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 0) { // Only update if not already selected
                    setState(() { _selectedViewIndex = 0; });
                    _fetchMySets(); // Fetch data for the "My Sets" view
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.collections_bookmark_outlined, color: _selectedViewIndex == 0 ? selectedText : unselectedText, size: 20),
                    const SizedBox(width: 8),
                    Text("My Sets", style: TextStyle(color: _selectedViewIndex == 0 ? selectedText : unselectedText, fontWeight: _selectedViewIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4), // Small gap between buttons
            // Button for "My Collection"
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 1 ? accentGold : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 1) { // Only update if not already selected
                    setState(() { _selectedViewIndex = 1; });
                    _fetchMyPins(); // Fetch data for the "My Collection" view
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.style_outlined, color: _selectedViewIndex == 1 ? selectedText : unselectedText, size: 20),
                    const SizedBox(width: 8),
                    Text("My Collection", style: TextStyle(color: _selectedViewIndex == 1 ? selectedText : unselectedText, fontWeight: _selectedViewIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional AppBar:
      // appBar: AppBar(
      //   title: Text(_selectedViewIndex == 0 ? "My Pin Sets" : "My Pin Collection"),
      //   elevation: 1, // Subtle shadow for the AppBar
      // ),
      body: SafeArea( // Ensures content is not obscured by system UI (notches, status bar)
        child: Column(
          children: [
            _buildSegmentedControl(context), // The view switcher
            Expanded( // The main content area that changes based on selection
              child: _selectedViewIndex == 0
                  ? _buildMySetsTabView()      // Show sets list
                  : _buildMyCollectionTabView(), // Show pins grid
            ),
          ],
        ),
      ),
    );
  }
}


// --- Pin Details Modal Widget ---
// This stateful widget manages the content and interactions within the pin details modal.
class _PinDetailsModalContent extends StatefulWidget {
  final Pin pin; // The pin data to display/edit
  final VoidCallback onPinUpdated; // Callback to refresh the main list after an update

  const _PinDetailsModalContent({required this.pin, required this.onPinUpdated});

  @override
  State<_PinDetailsModalContent> createState() => _PinDetailsModalContentState();
}

class _PinDetailsModalContentState extends State<_PinDetailsModalContent> with SingleTickerProviderStateMixin {
  bool _showFront = true; // Tracks if the front or back of the pin image is shown
  late AnimationController _flipAnimationController;
  late Animation<double> _flipAnimation;

  // TextEditingControllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _setControllerText; // Used for display if not using dropdown, or as temp for new set name
  late TextEditingController _quantityController;
  late TextEditingController _notesController;
  late TextEditingController _editionSizeController;
  late TextEditingController _originController;
  late TextEditingController _releaseDateController; // Consider using a date picker for this
  late TextEditingController _tagsController;


  PinSet? _selectedModalSet; // Holds the currently selected PinSet object for the dropdown
  List<PinSet> _modalExistingSets = []; // List of user's existing sets for the dropdown
  bool _isLoadingModalSets = false; // Tracks loading state for fetching sets

  // Temporary holders for newly processed images (e.g., after background removal)
  Uint8List? _newlyProcessedFrontBytes;
  Uint8List? _newlyProcessedBackBytes;

  bool _isEditing = false; // Toggles between view and edit mode for the modal
  bool _isSavingChanges = false; // Tracks if a save operation is in progress
  bool _isProcessingImage = false; // Tracks if an image processing operation is in progress

  final ImagePicker _picker = ImagePicker(); // For picking images from gallery/camera


  // Consistent styling for the modal elements
  static const Color modalPrimaryBlue = Color(0xFF0D47A1);
  static const Color modalAccentGold = Color(0xFFFFC107);
  static const Color modalSecondaryText = Color(0xFF546E7A);
  static const Color modalBackground = Color(0xFFF8F9FA);
  static const Color modalDivider = Color(0xFFD0D0D0);


  @override
  void initState() {
    super.initState();
    // Initialize animation controller for the image flip effect
    _flipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipAnimationController, curve: Curves.easeInOutQuart)
    );

    // Initialize TextEditingControllers with the current pin's data
    _nameController = TextEditingController(text: widget.pin.name);
    _setControllerText = TextEditingController(text: widget.pin.setName ?? ""); // For display consistency
    _quantityController = TextEditingController(text: widget.pin.quantity.toString());
    _notesController = TextEditingController(text: widget.pin.notes ?? "");
    _editionSizeController = TextEditingController(text: widget.pin.editionSize ?? "");
    _originController = TextEditingController(text: widget.pin.origin ?? "");
    _releaseDateController = TextEditingController(text: widget.pin.releaseDate ?? "");
    _tagsController = TextEditingController(text: widget.pin.tags ?? "");


    // Fetch existing sets for the dropdown and initialize the selected set
    _fetchSetsForModal().then((_) {
        if (widget.pin.setId != null && _modalExistingSets.isNotEmpty) {
            try {
                // Find the set in the fetched list that matches the pin's setId
                _selectedModalSet = _modalExistingSets.firstWhere((s) => s.id == widget.pin.setId);
                _setControllerText.text = _selectedModalSet?.name ?? widget.pin.setName ?? ""; // Update display text
            } catch (e) {
                // Handle case where pin's setId doesn't match any fetched set (e.g., data inconsistency)
                print("Error: Pin's set ID (${widget.pin.setId}) not found in fetched sets. Error: $e");
                _selectedModalSet = null; // Ensure no set is selected if not found
                _setControllerText.text = widget.pin.setName ?? ""; // Fallback to original setName
            }
        } else {
           // If pin has no setId, reflect its current setName (which might be from catalog or custom)
           _setControllerText.text = widget.pin.setName ?? "";
           _selectedModalSet = null; // No specific user set is linked
        }
        // Ensure setState is called if the widget is still mounted, to reflect changes
        if (mounted) {
          setState(() {});
        }
    });
  }

  // Fetches the user's existing sets to populate the dropdown in edit mode.
  Future<void> _fetchSetsForModal() async {
      if (supabase.auth.currentUser == null) return; // Should not happen if modal is shown
      if(mounted) setState(() => _isLoadingModalSets = true);
      try {
        final userId = supabase.auth.currentUser!.id;
        final response = await supabase
            .from('sets')
            .select('id, name, created_at') // Ensure all fields for PinSet.fromMap are selected
            .eq('user_id', userId)
            .order('name', ascending: true); // Order sets alphabetically

        final List<dynamic> setsDataDynamic = response;
        final List<Map<String, dynamic>> setsData = setsDataDynamic.cast<Map<String, dynamic>>();

        final sets = setsData.map((item) => PinSet.fromMap(item)).toList();

        if (mounted) {
          setState(() {
            _modalExistingSets = sets;
            // Initialization of _selectedModalSet is now handled in initState's .then()
          });
        }
      } catch (e) {
        print("Error fetching sets for modal: $e");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error fetching sets: ${e.toString()}"), backgroundColor: Colors.red));
        }
      } finally {
          if(mounted) setState(() => _isLoadingModalSets = false);
      }
  }


  @override
  void dispose() {
    // Dispose all controllers to free up resources
    _flipAnimationController.dispose();
    _nameController.dispose();
    _setControllerText.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _editionSizeController.dispose();
    _originController.dispose();
    _releaseDateController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // Triggers the flip animation for the pin image.
  void _flipImage() {
    if (_flipAnimationController.isAnimating) return; // Prevent multiple flips at once
    if (_showFront) {
      _flipAnimationController.forward(); // Animate to back
    } else {
      _flipAnimationController.reverse(); // Animate to front
    }
    setState(() {
      _showFront = !_showFront; // Toggle the state
    });
  }

  // Calls the Python API for image processing (e.g., background removal).
  Future<Uint8List?> _callPythonApiForModal(Uint8List imageBytes, String fileName) async {
    if(mounted) setState(() => _isProcessingImage = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(pythonApiUrl));
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.toBytes(); // Return processed image bytes
      } else {
        // Handle API errors
        final errorBody = await response.stream.bytesToString();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("API Error: ${jsonDecode(errorBody)['error'] ?? errorBody}"), backgroundColor: Colors.red));
        return null;
      }
    } catch (e) {
      // Handle network or other errors
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing image: $e"), backgroundColor: Colors.red));
      return null;
    } finally {
      if(mounted) setState(() => _isProcessingImage = false);
    }
  }

  // Handles picking an image and optionally processing it.
  Future<void> _changeImage(ImageTarget target) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1600);
    if (pickedFile == null) return; // User cancelled picker

    final imageBytes = await pickedFile.readAsBytes();
    // Assuming background removal is desired for modal images as well
    final processedBytes = await _callPythonApiForModal(imageBytes, pickedFile.name);

    if (processedBytes != null && mounted) {
      setState(() {
        // Update the appropriate temporary image byte holder
        if (target == ImageTarget.front) {
          _newlyProcessedFrontBytes = processedBytes;
        } else {
          _newlyProcessedBackBytes = processedBytes;
        }
      });
    }
  }

  // Saves the changes made to the pin details.
  Future<void> _handleSaveChanges() async {
    if (_isSavingChanges) return; // Prevent multiple save attempts
    setState(() => _isSavingChanges = true);

    // Get values from controllers
    final String newName = _nameController.text.trim();
    final int? newQuantity = int.tryParse(_quantityController.text.trim());
    final String? newNotes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final String? newEditionSize = _editionSizeController.text.trim().isEmpty ? null : _editionSizeController.text.trim();
    final String? newOrigin = _originController.text.trim().isEmpty ? null : _originController.text.trim();
    final String newReleaseDateText = _releaseDateController.text.trim(); // Corrected: String instead of String?
    String? newReleaseDateForDb = newReleaseDateText.isEmpty ? null : newReleaseDateText;
    // Basic validation for date format (YYYY-MM-DD) if it's not empty
    if (newReleaseDateForDb != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(newReleaseDateForDb)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid release date format. Please use YYYY-MM-DD.")));
        setState(() => _isSavingChanges = false);
        return;
    }

    final String? newTags = _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim();


    // Basic validation
    if (newName.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pin name cannot be empty.")));
      setState(() => _isSavingChanges = false);
      return;
    }
    if (newQuantity == null || newQuantity < 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quantity must be a valid non-negative number.")));
        setState(() => _isSavingChanges = false);
        return;
    }

    try {
      String? finalFrontImageUrl = widget.pin.imageUrl;
      String? finalBackImageUrl = widget.pin.imageBackUrl;
      final userId = supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch; // For unique image naming

      // Upload new front image if changed
      if (_newlyProcessedFrontBytes != null) {
        final frontPath = '$userId/front_${timestamp}_${Uri.encodeComponent(newName)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          frontPath, _newlyProcessedFrontBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true)
        );
        finalFrontImageUrl = supabase.storage.from('pin-images').getPublicUrl(frontPath);
      }

      // Upload new back image if changed or added
      if (_newlyProcessedBackBytes != null) {
        final backPath = '$userId/back_${timestamp}_${Uri.encodeComponent(newName)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          backPath, _newlyProcessedBackBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true)
        );
        finalBackImageUrl = supabase.storage.from('pin-images').getPublicUrl(backPath);
      } else if (widget.pin.imageBackUrl != null && _newlyProcessedBackBytes == null && _isEditing && !_showFront) {
        // This condition might be tricky: if user was viewing back, edited other fields, but didn't change back image.
        // It's generally safer to only update image URLs if _newlyProcessed...Bytes is not null.
        // If you want to allow *removing* a back image, you'd need a separate mechanism.
      }


      // Prepare data for updating the 'pins' table
      Map<String, dynamic> updateData = {
        'name': newName,
        'image_url': finalFrontImageUrl,
        'image_back_url': finalBackImageUrl, // This will be null if no back image was ever set or if it's cleared
        'quantity': newQuantity,
        'set_id': _selectedModalSet?.id, // This will be null if "No Set" is chosen or if it was cleared
        'notes': newNotes,
        'edition_size': newEditionSize,
        'origin': newOrigin,
        'release_date': newReleaseDateForDb, // Use validated/formatted date
        'tags': newTags,
        // If _selectedModalSet is null, it means the pin is not part of a user's 'sets' table entry.
        // The 'catalog_series_name' and 'custom_set_name' on the 'pins' table are separate.
        // If you want to update 'custom_set_name' based on text input when no set is selected:
        // 'custom_set_name': _selectedModalSet == null ? _setControllerText.text.trim() : widget.pin.customSetNameFromPinTable,
        // However, this might conflict with the 'setName' derivation logic.
        // For now, we primarily manage the link to the 'sets' table via 'set_id'.
      };

      // Update the pin record in Supabase
      await supabase.from('pins').update(updateData).eq('id', widget.pin.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pin updated successfully!"), backgroundColor: Colors.green)
        );
        widget.onPinUpdated(); // Trigger refresh on the main page
        Navigator.of(context).pop(); // Close the modal
      }

    } catch (e) {
      print("Error saving changes: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save changes: ${e.toString()}"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if(mounted) setState(() => _isSavingChanges = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine if a back image exists (either original or newly processed)
    final bool hasBackImage = (_newlyProcessedBackBytes != null) || (widget.pin.imageBackUrl != null && widget.pin.imageBackUrl!.isNotEmpty);
    // URLs for displaying images, defaulting to original pin data
    final String currentFrontDisplayUrl = widget.pin.imageUrl;
    final String? currentBackDisplayUrl = widget.pin.imageBackUrl;


    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
      decoration: BoxDecoration(
        color: modalBackground,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 3,
          )
        ]
      ),
      child: SingleChildScrollView( // Allows scrolling if content overflows
        child: Column(
          mainAxisSize: MainAxisSize.min, // Modal takes minimum necessary height
          crossAxisAlignment: CrossAxisAlignment.stretch, // Children fill width
          children: <Widget>[
            // Image display area with flip animation
            AspectRatio(
              aspectRatio: 1.0, // Square aspect ratio for the image container
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder( // Handles the flip animation
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi;
                      final transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective effect
                        ..rotateY(angle); // Rotate around Y-axis
                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: _flipAnimation.value < 0.5 // Show front image during first half of animation
                            ? _buildImageSide(
                                _newlyProcessedFrontBytes,
                                currentFrontDisplayUrl,
                                isBack: false
                              )
                            : Transform( // Rotate back image to face correctly
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: Alignment.center,
                                child: _buildImageSide(
                                  _newlyProcessedBackBytes,
                                  currentBackDisplayUrl ?? currentFrontDisplayUrl, // Fallback for back image
                                  isBack: true
                                ),
                              ),
                      );
                    }
                  ),
                  // Flip button, shown if a back image exists or can be added
                  if (hasBackImage || _newlyProcessedFrontBytes != null || _newlyProcessedBackBytes != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Material(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        elevation: 2,
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_android_outlined, color: Colors.white, size: 22),
                          tooltip: _showFront ? "Show Back" : "Show Front",
                          // Enable flip only if there's a back image (original or new)
                          onPressed: (hasBackImage || _newlyProcessedBackBytes != null) ? _flipImage : null,
                        ),
                      ),
                    ),
                  // Loading indicator during image processing
                  if (_isProcessingImage)
                    Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(child: CircularProgressIndicator(color: modalAccentGold))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Buttons to change front/back images, shown only in edit mode
              if (_isEditing) Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.photo_camera_outlined, size: 18, color: modalSecondaryText),
                  label: Text("Front Image", style: TextStyle(color: modalSecondaryText, fontSize: 13)),
                  onPressed: () => _changeImage(ImageTarget.front),
                ),
                TextButton.icon(
                  icon: Icon(Icons.photo_camera_outlined, size: 18, color: modalSecondaryText),
                  label: Text(hasBackImage || _newlyProcessedBackBytes != null ? "Back Image" : "Add Back", style: TextStyle(color: modalSecondaryText, fontSize: 13)),
                  onPressed: () => _changeImage(ImageTarget.back),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: modalDivider.withOpacity(0.7)), // Visual separator
            const SizedBox(height: 12),

            // Pin details section (view or edit)
            Text("Pin Details", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: modalPrimaryBlue)),
            const SizedBox(height: 16),
            _buildDetailRowOrField("Name:", _nameController, isEditing: _isEditing),
            _buildDetailRowOrField("Set:", _setControllerText, isEditing: _isEditing, isSetField: true),
            _buildDetailRowOrField("Quantity:", _quantityController, isEditing: _isEditing, isNumeric: true),
            _buildDetailRowOrField("Notes:", _notesController, isEditing: _isEditing, isMultiLine: true),
            _buildDetailRowOrField("Edition Size:", _editionSizeController, isEditing: _isEditing),
            _buildDetailRowOrField("Origin:", _originController, isEditing: _isEditing),
            _buildDetailRowOrField("Release Date:", _releaseDateController, isEditing: _isEditing, isDateField: true),
            _buildDetailRowOrField("Tags:", _tagsController, isEditing: _isEditing),


            const SizedBox(height: 24),
            // Action buttons (Close, Edit/Save)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: modalSecondaryText),
                  child: const Text("Close"),
                  onPressed: () => Navigator.of(context).pop(), // Close the modal
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _isEditing
                  ? ElevatedButton.icon( // Save Changes button
                      icon: _isSavingChanges
                          ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSavingChanges ? "Saving..." : "Save Changes"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700], // Positive action color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                      onPressed: _isSavingChanges ? null : _handleSaveChanges, // Disable while saving
                    )
                  : ElevatedButton.icon( // Edit Pin button
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text("Edit Pin"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: modalPrimaryBlue, // Primary action color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                      onPressed: () => setState(() => _isEditing = true), // Switch to edit mode
                    ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a side of the flippable image (front or back).
  Widget _buildImageSide(Uint8List? newBytes, String? originalUrl, {bool isBack = false}) {
    Widget imageContent;
    // Prioritize newly processed image bytes if available
    if (newBytes != null) {
      imageContent = Image.memory(newBytes, fit: BoxFit.contain);
    }
    // Fallback to original image URL
    else if (originalUrl != null && originalUrl.isNotEmpty) {
      imageContent = Image.network(
        originalUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(color: modalAccentGold));
        },
        errorBuilder: (context, error, stackTrace) => // Placeholder for error
            Center(child: Icon(isBack ? Icons.no_photography_outlined : Icons.broken_image_outlined, color: Colors.grey[400], size: 70)),
      );
    }
    // Placeholder if no image is available at all
    else {
      imageContent = Center(child: Icon(isBack ? Icons.no_photography_outlined : Icons.image_not_supported_outlined, color: Colors.grey[400], size: 70, semanticLabel: isBack ? "No back image" : "No front image",));
    }

    return Container( // Styled container for the image
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: modalPrimaryBlue.withOpacity(0.2), width: 1)
      ),
      child: ClipRRect( // Ensures image respects the border radius
        borderRadius: BorderRadius.circular(17.0),
        child: imageContent,
      ),
    );
  }

  // Helper widget to build a row for displaying or editing a detail field.
  Widget _buildDetailRowOrField(
    String label,
    TextEditingController controller, {
    bool isEditing = false,
    bool isSetField = false, // Special handling for the 'Set' field (dropdown)
    bool isNumeric = false,  // For numeric keyboard
    bool isMultiLine = false, // For multiline text input (e.g., notes)
    bool isDateField = false, // For date input, potentially with a date picker
  }) {
    Widget fieldWidget;

    if (isEditing) { // In edit mode, show appropriate input field
      if (isSetField) { // 'Set' field uses a DropdownButtonFormField
        fieldWidget = DropdownButtonFormField<PinSet>(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          value: _selectedModalSet, // Current selected set
          hint: const Text("Select Set"),
          isExpanded: true,
          items: [ // Dropdown items: "No Set" option + list of existing sets
            DropdownMenuItem<PinSet>(
              value: null, // Represents no set or clearing the set
              child: Text("No Set / Clear Set", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),
            ),
            ..._modalExistingSets.map((PinSet set) {
              return DropdownMenuItem<PinSet>(
                value: set,
                child: Text(set.name, overflow: TextOverflow.ellipsis),
              );
            }).toList()
          ],
          onChanged: (PinSet? newValue) { // Update state when selection changes
            setState(() {
              _selectedModalSet = newValue;
              _setControllerText.text = newValue?.name ?? ""; // Update display text
            });
          },
        );
      } else { // Other fields use TextFormField
        fieldWidget = TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : (isMultiLine ? TextInputType.multiline : TextInputType.text),
          maxLines: isMultiLine ? null : 1, // Allow multiple lines for notes
          minLines: isMultiLine ? 3 : 1,   // Sensible min lines for notes
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            // Add calendar icon for date fields, and potentially a clear button
            suffixIcon: isDateField
                ? IconButton(
                    icon: Icon(Icons.calendar_today, size: 18, color: modalSecondaryText),
                    onPressed: () async { // Open date picker on icon tap
                      DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
                          firstDate: DateTime(1900), // Sensible earliest date
                          lastDate: DateTime(2101) // Sensible latest date
                      ); // Closing parenthesis for showDatePicker
                      if (pickedDate != null) {
                        // Format date as yyyy-MM-DD for consistency
                        String formattedDate = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        controller.text = formattedDate;
                      }
                    }, // Closing brace for onPressed
                  ) // Closing parenthesis for IconButton
                : null, // else for suffixIcon ternary
          ), // Closing parenthesis for InputDecoration
          readOnly: isDateField && !isEditing, // Make date field read-only if not editing (if using text field for date)
          onTap: isDateField && isEditing ? () async { // Also open date picker on field tap
            DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2101)
            );
            if (pickedDate != null) {
              String formattedDate = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
              controller.text = formattedDate;
            }
          } : null,
        ); // Closing parenthesis for TextFormField
      } // Closing brace for else (isSetField)
    } else { // In view mode, show text
      String displayText = controller.text;
      if (isSetField) {
        // Display the name of the selected set, or the pin's current setName, or "Not in a set"
        displayText = _selectedModalSet?.name ?? (widget.pin.setName?.isNotEmpty == true ? widget.pin.setName! : "Not in a set");
      } else if (controller.text.isEmpty && !isDateField) {
        displayText = "N/A"; // Placeholder for empty non-date fields
      } else if (controller.text.isEmpty && isDateField) {
        displayText = "Not set"; // Placeholder for empty date fields
      }
      fieldWidget = Text(displayText, style: const TextStyle(fontSize: 15, color: Colors.black87), softWrap: true);
    } // Closing brace for else (isEditing)

    return Padding( // Layout for the label and field
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: (isMultiLine && isEditing && !isSetField) ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox( // Label container
            width: 95,
            child: Padding(
              padding: EdgeInsets.only(top: (isMultiLine && isEditing && !isSetField) ? 8.0 : 0), // Adjusted for better alignment with multiline TextFormField
              child: Text("$label ", style: TextStyle(color: modalSecondaryText, fontWeight: FontWeight.w600, fontSize: 14)),
            )
          ),
          Expanded(child: fieldWidget), // Field takes remaining space
        ],
      ),
    ); // Closing parenthesis for Padding
  } // Closing brace for _buildDetailRowOrField method
} // Closing brace for _PinDetailsModalContentState class
