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
  String? setName;
  int? setId;
  int quantity; // Make mutable
  final DateTime addedAt;

  Pin({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.imageBackUrl, 
    this.setName,
    this.setId,
    required this.quantity,
    required this.addedAt,
  });

  factory Pin.fromMap(Map<String, dynamic> map) {
    String? resolvedSetName;
    if (map['sets'] != null && map['sets'] is Map) {
      resolvedSetName = map['sets']['name'] as String?;
    } else if (map['set_name'] != null) {
      resolvedSetName = map['set_name'] as String?;
    }

    return Pin(
      id: map['id'] as int,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String,
      imageBackUrl: map['image_back_url'] as String?, 
      setId: map['set_id'] as int?,
      setName: resolvedSetName,
      quantity: map['quantity'] as int? ?? 1,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }
  // Method to create a copy with updated values, useful for immutable state updates
    PincopyWith({
    String? name,
    String? imageUrl,
    String? imageBackUrl,
    String? setName,
    int? setId,
    int? quantity,
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
    );
  }
}

class PinSet {
  final int id;
  final String name;
  final DateTime createdAt; 

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
  int _selectedViewIndex = 0;
  List<Pin> _myPins = [];
  bool _isLoadingPins = false;
  String? _pinsError;
  List<PinSet> _mySets = [];
  bool _isLoadingSets = false;
  String? _setsError;

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  void _fetchMyData() {
    if (_selectedViewIndex == 0) {
      _fetchMySets();
      if (_myPins.isEmpty && !_isLoadingPins) _fetchMyPins();
    } else {
      _fetchMyPins();
      if (_mySets.isEmpty && !_isLoadingSets) _fetchMySets();
    }
  }
  
  // Callback function for the modal to trigger a refresh
  Future<void> _refreshPinData() async {
    await _fetchMyPins(); // Or a more targeted fetch if you know the pin ID
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
      final response = await supabase
          .from('pins')
          .select('*, image_back_url, sets!pins_set_id_fkey(name)')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      final List<Map<String, dynamic>> pinsData = List<Map<String, dynamic>>.from(response);
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
      final response = await supabase
          .from('sets')
          .select('id, name, created_at') 
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> setsData = List<Map<String, dynamic>>.from(response);
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

  void _showPinDetailsModal(BuildContext context, Pin pin) {
    showDialog(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          elevation: 5,
          backgroundColor: Colors.transparent, 
          child: _PinDetailsModalContent(
            pin: pin, 
            onPinUpdated: () { // Pass the callback
              _refreshPinData();
            }
          ),
        );
      },
    );
  }


  Widget _buildPinCard(Pin pin) {
    // ... (Pin card UI remains the same)
    return GestureDetector( 
      onTap: () => _showPinDetailsModal(context, pin),
      child: Card(
        elevation: 3.0,
        margin: const EdgeInsets.all(6.0), 
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[100], 
                child: Image.network(
                  pin.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6200EA) /* Deep Purple Accent */));
                  },
                  errorBuilder: (context, error, stackTrace) =>
                    Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 48)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF311B92) /* Deep Purple */),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (pin.setName != null && pin.setName!.isNotEmpty)
                    Text(
                      "Set: ${pin.setName}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
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

 Widget _buildSetCard(PinSet set) {
    // ... (Set card UI remains the same)
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(set.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text("Created: ${set.createdAt.toLocal().toString().substring(0,10)}"),
        onTap: () {
          print("Tapped on set: ${set.name} (ID: ${set.id})");
        },
      ),
    );
  }

  Widget _buildMyCollectionTabView() {
    // ... (remains the same)
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
      return const Center(child: Text("Your pin collection is empty. Start scanning!"));
    }

    return RefreshIndicator(
      onRefresh: _fetchMyPins,
      child: GridView.builder(
        padding: const EdgeInsets.all(12.0), 
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7, 
          crossAxisSpacing: 10.0, 
          mainAxisSpacing: 10.0,  
        ),
        itemCount: _myPins.length, 
        itemBuilder: (context, index) {
          return _buildPinCard(_myPins[index]); 
        },
      ),
    );
  }

  Widget _buildMySetsTabView() {
    // ... (remains the same)
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
      return const Center(child: Text("You haven't created any sets yet."));
    }
     return RefreshIndicator(
      onRefresh: _fetchMySets,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8.0),
        itemCount: _mySets.length,
        itemBuilder: (context, index) {
          return _buildSetCard(_mySets[index]);
        },
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    // ... (remains the same)
    const Color primaryDeepBlue = Color(0xFF0D47A1); 
    const Color accentGold = Color(0xFFFFC107); 
    const Color lightBackground = Color(0xFFF0F2F5); 
    const Color unselectedText = Color(0xFF424242); 
    const Color selectedText = Colors.white; 

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container( 
        padding: const EdgeInsets.all(4.0),
         decoration: BoxDecoration(
          color: lightBackground, 
          borderRadius: BorderRadius.circular(25.0),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 0 ? accentGold : Colors.transparent, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 0) {
                    setState(() { _selectedViewIndex = 0; });
                    _fetchMySets();
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
            const SizedBox(width: 4),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _selectedViewIndex == 1 ? accentGold : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onPressed: () {
                  if (_selectedViewIndex != 1) {
                    setState(() { _selectedViewIndex = 1; });
                    _fetchMyPins();
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
      body: SafeArea( 
        child: Column(
          children: [
            _buildSegmentedControl(context),
            Expanded(
              child: _selectedViewIndex == 0
                     ? _buildMySetsTabView()
                     : _buildMyCollectionTabView(),
            ),
          ],
        ),
      ),
    );
  }
}


// --- Pin Details Modal Widget ---
class _PinDetailsModalContent extends StatefulWidget {
  final Pin pin;
  final VoidCallback onPinUpdated; // Callback to refresh the main list

  const _PinDetailsModalContent({required this.pin, required this.onPinUpdated});

  @override
  State<_PinDetailsModalContent> createState() => _PinDetailsModalContentState();
}

class _PinDetailsModalContentState extends State<_PinDetailsModalContent> with SingleTickerProviderStateMixin {
  bool _showFront = true;
  late AnimationController _flipAnimationController;
  late Animation<double> _flipAnimation;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _setControllerText; // For text field
  late TextEditingController _quantityController;
  
  PinSet? _selectedModalSet; // Holds the chosen PinSet object for saving
  List<PinSet> _modalExistingSets = []; 
  bool _isLoadingModalSets = false;

  // Temporary holders for newly processed images before saving
  Uint8List? _newlyProcessedFrontBytes;
  Uint8List? _newlyProcessedBackBytes;

  bool _isEditing = false; // To toggle between view and edit mode
  bool _isSavingChanges = false;
  bool _isProcessingImage = false; // General loading for image processing

  final ImagePicker _picker = ImagePicker();


  static const Color modalPrimaryBlue = Color(0xFF0D47A1); 
  static const Color modalAccentGold = Color(0xFFFFC107); 
  static const Color modalSecondaryText = Color(0xFF546E7A); 
  static const Color modalBackground = Color(0xFFF8F9FA); 
  static const Color modalDivider = Color(0xFFD0D0D0);


  @override
  void initState() {
    super.initState();
    _flipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), 
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipAnimationController, curve: Curves.easeInOutQuart) 
    );

    _nameController = TextEditingController(text: widget.pin.name);
    _setControllerText = TextEditingController(text: widget.pin.setName ?? "");
    _quantityController = TextEditingController(text: widget.pin.quantity.toString());
    
    _fetchSetsForModal().then((_) {
        // Initialize _selectedModalSet after sets are fetched
        if (widget.pin.setId != null && _modalExistingSets.isNotEmpty) {
            try {
                 _selectedModalSet = _modalExistingSets.firstWhere((s) => s.id == widget.pin.setId);
                 _setControllerText.text = _selectedModalSet?.name ?? ""; // Update text field
            } catch (e) {
                print("Selected set ID not found in fetched sets: ${widget.pin.setId}");
                _selectedModalSet = null; // Ensure it's null if not found
                _setControllerText.text = ""; // Clear text if set not found
            }
        }
    }); 
  }

  Future<void> _fetchSetsForModal() async {
     if (supabase.auth.currentUser == null) return;
     if(mounted) setState(() => _isLoadingModalSets = true);
      try {
        final userId = supabase.auth.currentUser!.id;
        final response = await supabase
            .from('sets')
            .select('id, name, created_at') 
            .eq('user_id', userId)
            .order('name', ascending: true);

        final List<Map<String, dynamic>> setsData = List<Map<String, dynamic>>.from(response);
        final sets = setsData
            .map((item) => PinSet.fromMap(item)) 
            .toList();

        if (mounted) {
          setState(() {
            _modalExistingSets = sets;
            // _selectedModalSet initialization moved to initState's .then()
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
    _flipAnimationController.dispose();
    _nameController.dispose();
    _setControllerText.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _flipImage() {
    if (_flipAnimationController.isAnimating) return;
    if (_showFront) {
      _flipAnimationController.forward();
    } else {
      _flipAnimationController.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  Future<Uint8List?> _callPythonApiForModal(Uint8List imageBytes, String fileName) async {
    if(mounted) setState(() => _isProcessingImage = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(pythonApiUrl));
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.toBytes();
      } else {
        final errorBody = await response.stream.bytesToString();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("API Error: ${jsonDecode(errorBody)['error'] ?? errorBody}"), backgroundColor: Colors.red));
        return null;
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing image: $e"), backgroundColor: Colors.red));
      return null;
    } finally {
      if(mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _changeImage(ImageTarget target) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1600);
    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();
    final processedBytes = await _callPythonApiForModal(imageBytes, pickedFile.name);

    if (processedBytes != null && mounted) {
      setState(() {
        if (target == ImageTarget.front) {
          _newlyProcessedFrontBytes = processedBytes;
        } else {
          _newlyProcessedBackBytes = processedBytes;
        }
      });
    }
  }

  Future<void> _handleSaveChanges() async {
    if (_isSavingChanges) return;
    setState(() => _isSavingChanges = true);

    final String newName = _nameController.text.trim();
    final int? newQuantity = int.tryParse(_quantityController.text.trim());

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pin name cannot be empty.")));
      setState(() => _isSavingChanges = false);
      return;
    }
    if (newQuantity == null || newQuantity < 0) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quantity must be a valid number.")));
       setState(() => _isSavingChanges = false);
       return;
    }

    try {
      String? finalFrontImageUrl = widget.pin.imageUrl;
      String? finalBackImageUrl = widget.pin.imageBackUrl;
      final userId = supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload new front image if it exists
      if (_newlyProcessedFrontBytes != null) {
        final frontPath = '$userId/front_${timestamp}_${Uri.encodeComponent(widget.pin.name)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          frontPath, _newlyProcessedFrontBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true) // upsert true to overwrite if same name (though timestamp makes it unique)
        );
        finalFrontImageUrl = supabase.storage.from('pin-images').getPublicUrl(frontPath);
      }

      // Upload new back image if it exists
      if (_newlyProcessedBackBytes != null) {
        final backPath = '$userId/back_${timestamp}_${Uri.encodeComponent(widget.pin.name)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          backPath, _newlyProcessedBackBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true)
        );
        finalBackImageUrl = supabase.storage.from('pin-images').getPublicUrl(backPath);
      }

      // Update pin details in Supabase
      await supabase.from('pins').update({
        'name': newName,
        'image_url': finalFrontImageUrl,
        'image_back_url': finalBackImageUrl,
        'quantity': newQuantity,
        'set_id': _selectedModalSet?.id, // This could be null if no set is chosen
      }).eq('id', widget.pin.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pin updated successfully!"), backgroundColor: Colors.green)
        );
        widget.onPinUpdated(); // Call callback to refresh the list on the main page
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
    final bool hasBackImage = (_newlyProcessedBackBytes != null) || (widget.pin.imageBackUrl != null && widget.pin.imageBackUrl!.isNotEmpty);
    final String currentFrontDisplayUrl = widget.pin.imageUrl; // Initially show original
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio( 
              aspectRatio: 1.0, 
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi; 
                      final transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.001) 
                        ..rotateY(angle);
                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: _flipAnimation.value < 0.5 
                            ? _buildImageSide(
                                _newlyProcessedFrontBytes, // Prioritize newly processed
                                currentFrontDisplayUrl, // Fallback to original
                                isBack: false
                              )
                            : Transform( 
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: Alignment.center,
                                child: _buildImageSide(
                                  _newlyProcessedBackBytes, // Prioritize newly processed
                                  currentBackDisplayUrl ?? currentFrontDisplayUrl, // Fallback
                                  isBack: true
                                ),
                              ),
                      );
                    }
                  ),
                  if (hasBackImage || _newlyProcessedFrontBytes != null) // Show flip if back exists or if front is set (to allow adding back)
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
                          onPressed: (hasBackImage || _newlyProcessedBackBytes != null) ? _flipImage : null, // Only enable flip if there's a back to flip to
                        ),
                      ),
                    ),
                  if (_isProcessingImage)
                    Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(child: CircularProgressIndicator(color: modalAccentGold))),
                ],
              ),
            ),
            const SizedBox(height: 12),
             if (_isEditing) Row( // Show change buttons only in edit mode
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
            Divider(color: modalDivider.withOpacity(0.7)),
            const SizedBox(height: 12),

            Text("Pin Details", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: modalPrimaryBlue)),
            const SizedBox(height: 16),
            _buildDetailRowOrField("Name:", _nameController, isEditing: _isEditing), 
            _buildDetailRowOrField("Set:", _setControllerText, isEditing: _isEditing, isSetField: true),
            _buildDetailRowOrField("Quantity:", _quantityController, isEditing: _isEditing, isNumeric: true),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end, 
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: modalSecondaryText),
                  child: const Text("Close"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8), 
                Flexible( 
                  child: _isEditing 
                  ? ElevatedButton.icon(
                      icon: _isSavingChanges ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSavingChanges ? "Saving..." : "Save"), 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500) 
                      ),
                      onPressed: _isSavingChanges ? null : _handleSaveChanges,
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note, size: 18), 
                      label: const Text("Edit"), 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: modalPrimaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500) 
                      ),
                      onPressed: () => setState(() => _isEditing = true),
                    ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSide(Uint8List? newBytes, String? originalUrl, {bool isBack = false}) {
    Widget imageContent;
    if (newBytes != null) {
      imageContent = Image.memory(newBytes, fit: BoxFit.contain);
    } else if (originalUrl != null && originalUrl.isNotEmpty) {
      imageContent = Image.network(
        originalUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(color: modalAccentGold));
        },
        errorBuilder: (context, error, stackTrace) =>
            Center(child: Icon(isBack ? Icons.no_photography_outlined : Icons.broken_image_outlined, color: Colors.grey[400], size: 70)),
      );
    } else {
      imageContent = Center(child: Icon(isBack ? Icons.no_photography_outlined : Icons.image_not_supported_outlined, color: Colors.grey[400], size: 70, semanticLabel: isBack ? "No back image" : "No front image",));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100], 
        borderRadius: BorderRadius.circular(18.0), 
        border: Border.all(color: modalPrimaryBlue.withOpacity(0.2), width: 1)
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.0), 
        child: imageContent,
      ),
    );
  }

  // Updated to switch between Text and TextFormField based on _isEditing
  Widget _buildDetailRowOrField(String label, TextEditingController controller, {bool isEditing = false, bool isSetField = false, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isEditing && !isSetField ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85, 
            child: Padding(
              padding: EdgeInsets.only(top: isEditing && !isSetField ? 0 : 4.0), // Adjust label alignment for text fields
              child: Text("$label ", style: TextStyle(color: modalSecondaryText, fontWeight: FontWeight.w600, fontSize: 14)),
            )
          ),
          Expanded(
            child: isEditing 
              ? (isSetField 
                  ? DropdownButtonFormField<PinSet>(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      value: _selectedModalSet,
                      hint: const Text("Select Set"),
                      isExpanded: true,
                      items: _modalExistingSets.map((PinSet set) {
                        return DropdownMenuItem<PinSet>(
                          value: set,
                          child: Text(set.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (PinSet? newValue) {
                        setState(() {
                          _selectedModalSet = newValue;
                          _setControllerText.text = newValue?.name ?? "";
                        });
                      },
                      // TODO: Add a way to clear the set or select "No Set"
                    )
                  : TextFormField(
                      controller: controller,
                      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                )
              : Text(controller.text.isEmpty && isSetField ? "Not in a set" : controller.text, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
