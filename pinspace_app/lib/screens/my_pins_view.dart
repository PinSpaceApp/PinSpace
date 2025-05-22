// lib/screens/my_pins_view.dart
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math; // For the flip animation
import 'package:image_picker/image_picker.dart'; // For picking images
import 'dart:typed_data'; // For Uint8List
import 'package:http/http.dart' as http; // For API calls

final supabase = Supabase.instance.client;

// --- CONFIGURATION ---
const String pythonApiUrl = 'https://colejunck1.pythonanywhere.com/remove-background';

// --- Data Models ---
// Note: PinSet is also defined here because _PinDetailsModalContent needs it.
// In a larger app, models might live in their own directory.
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

enum ImageTarget { front, back }

class Pin {
  final int id;
  String name;
  String imageUrl;
  String? imageBackUrl;
  String? setName;
  int? setId;
  int quantity;
  final DateTime addedAt;
  String? notes;
  String? tradeStatus;
  String? status;
  int? catalogPinRefId;
  String? editionSize;
  String? origin;
  String? releaseDate;
  String? tags;
  String? customSetNameFromPinTable;
  String? catalogSeriesNameFromPinTable;

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
    if (map['sets'] != null && map['sets'] is Map && map['sets']['name'] != null) {
      resolvedSetName = map['sets']['name'] as String?;
    }
    if (resolvedSetName == null && map['catalog_series_name'] != null) {
      resolvedSetName = map['catalog_series_name'] as String?;
    }
    if (resolvedSetName == null && map['custom_set_name'] != null) {
        resolvedSetName = map['custom_set_name'] as String?;
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
      notes: map['notes'] as String?,
      tradeStatus: map['trade_status'] as String?,
      status: map['status'] as String?,
      catalogPinRefId: map['catalog_pin_ref_id'] as int?,
      editionSize: map['edition_size'] as String?,
      origin: map['origin'] as String?,
      releaseDate: map['release_date'] as String?,
      tags: map['tags'] as String?,
      customSetNameFromPinTable: map['custom_set_name'] as String?,
      catalogSeriesNameFromPinTable: map['catalog_series_name'] as String?,
    );
  }
   Pin copyWith({
    String? name,
    String? imageUrl,
    String? imageBackUrl,
    String? setName,
    int? setId,
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
// --- End Data Models ---

class MyPinsView extends StatefulWidget {
  const MyPinsView({super.key});

  @override
  State<MyPinsView> createState() => _MyPinsViewState();
}

class _MyPinsViewState extends State<MyPinsView> {
  List<Pin> _myPins = [];
  bool _isLoadingPins = true;
  String? _pinsError;

  @override
  void initState() {
    super.initState();
    _fetchMyPins();
  }

  Future<void> _refreshPinData() async {
    await _fetchMyPins();
  }

  Future<void> _fetchMyPins() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        setState(() {
          _pinsError = "Please log in to see your pins.";
          _isLoadingPins = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingPins = true;
        _pinsError = null;
      });
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('pins')
          .select('*, image_back_url, sets!pins_set_id_fkey(name)')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      final List<dynamic> pinsDataDynamic = response;
      final List<Map<String, dynamic>> pinsData = pinsDataDynamic.cast<Map<String, dynamic>>();
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
            onPinUpdated: () {
              _refreshPinData();
            }
          ),
        );
      },
    );
  }

  Widget _buildPinCard(Pin pin) {
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
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6200EA)));
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF311B92)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPins) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pinsError != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_pinsError!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
      ));
    }
    if (_myPins.isEmpty) {
      return const Center(child: Text("Your pin collection is empty. Add pins from the catalog or scan new ones!"));
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
}

// --- Pin Details Modal Widget ---
class _PinDetailsModalContent extends StatefulWidget {
  final Pin pin;
  final VoidCallback onPinUpdated;

  const _PinDetailsModalContent({required this.pin, required this.onPinUpdated});

  @override
  State<_PinDetailsModalContent> createState() => _PinDetailsModalContentState();
}

class _PinDetailsModalContentState extends State<_PinDetailsModalContent> with SingleTickerProviderStateMixin {
  bool _showFront = true;
  late AnimationController _flipAnimationController;
  late Animation<double> _flipAnimation;

  late TextEditingController _nameController;
  late TextEditingController _setControllerText;
  late TextEditingController _quantityController;
  late TextEditingController _notesController;
  late TextEditingController _editionSizeController;
  late TextEditingController _originController;
  late TextEditingController _releaseDateController;
  late TextEditingController _tagsController;

  PinSet? _selectedModalSet;
  List<PinSet> _modalExistingSets = [];
  bool _isLoadingModalSets = false;

  Uint8List? _newlyProcessedFrontBytes;
  Uint8List? _newlyProcessedBackBytes;

  bool _isEditing = false;
  bool _isSavingChanges = false;
  bool _isProcessingImage = false;

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
    _notesController = TextEditingController(text: widget.pin.notes ?? "");
    _editionSizeController = TextEditingController(text: widget.pin.editionSize ?? "");
    _originController = TextEditingController(text: widget.pin.origin ?? "");
    _releaseDateController = TextEditingController(text: widget.pin.releaseDate ?? "");
    _tagsController = TextEditingController(text: widget.pin.tags ?? "");

    _fetchSetsForModal().then((_) {
        if (widget.pin.setId != null && _modalExistingSets.isNotEmpty) {
            try {
                _selectedModalSet = _modalExistingSets.firstWhere((s) => s.id == widget.pin.setId);
                _setControllerText.text = _selectedModalSet?.name ?? widget.pin.setName ?? "";
            } catch (e) {
                print("Error: Pin's set ID (${widget.pin.setId}) not found in fetched sets. Error: $e");
                _selectedModalSet = null;
                _setControllerText.text = widget.pin.setName ?? "";
            }
        } else {
           _setControllerText.text = widget.pin.setName ?? "";
           _selectedModalSet = null;
        }
        if (mounted) {
          setState(() {});
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

        final List<dynamic> setsDataDynamic = response;
        final List<Map<String, dynamic>> setsData = setsDataDynamic.cast<Map<String, dynamic>>();
        final sets = setsData.map((item) => PinSet.fromMap(item)).toList();

        if (mounted) {
          setState(() {
            _modalExistingSets = sets;
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
    _notesController.dispose();
    _editionSizeController.dispose();
    _originController.dispose();
    _releaseDateController.dispose();
    _tagsController.dispose();
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
    final String? newNotes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final String? newEditionSize = _editionSizeController.text.trim().isEmpty ? null : _editionSizeController.text.trim();
    final String? newOrigin = _originController.text.trim().isEmpty ? null : _originController.text.trim();
    final String newReleaseDateText = _releaseDateController.text.trim();
    String? newReleaseDateForDb = newReleaseDateText.isEmpty ? null : newReleaseDateText;

    if (newReleaseDateForDb != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(newReleaseDateForDb)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid release date format. Please use YYYY-MM-DD.")));
        setState(() => _isSavingChanges = false);
        return;
    }

    final String? newTags = _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim();

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
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (_newlyProcessedFrontBytes != null) {
        final frontPath = '$userId/front_${timestamp}_${Uri.encodeComponent(newName)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          frontPath, _newlyProcessedFrontBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true)
        );
        finalFrontImageUrl = supabase.storage.from('pin-images').getPublicUrl(frontPath);
      }

      if (_newlyProcessedBackBytes != null) {
        final backPath = '$userId/back_${timestamp}_${Uri.encodeComponent(newName)}.webp';
        await supabase.storage.from('pin-images').uploadBinary(
          backPath, _newlyProcessedBackBytes!,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: true)
        );
        finalBackImageUrl = supabase.storage.from('pin-images').getPublicUrl(backPath);
      }

      Map<String, dynamic> updateData = {
        'name': newName,
        'image_url': finalFrontImageUrl,
        'image_back_url': finalBackImageUrl,
        'quantity': newQuantity,
        'set_id': _selectedModalSet?.id,
        'notes': newNotes,
        'edition_size': newEditionSize,
        'origin': newOrigin,
        'release_date': newReleaseDateForDb,
        'tags': newTags,
      };

      await supabase.from('pins').update(updateData).eq('id', widget.pin.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pin updated successfully!"), backgroundColor: Colors.green)
        );
        widget.onPinUpdated();
        Navigator.of(context).pop();
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
                                _newlyProcessedFrontBytes,
                                currentFrontDisplayUrl,
                                isBack: false
                              )
                            : Transform(
                                transform: Matrix4.identity()..rotateY(math.pi),
                                alignment: Alignment.center,
                                child: _buildImageSide(
                                  _newlyProcessedBackBytes,
                                  currentBackDisplayUrl ?? currentFrontDisplayUrl,
                                  isBack: true
                                ),
                              ),
                      );
                    }
                  ),
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
                          onPressed: (hasBackImage || _newlyProcessedBackBytes != null) ? _flipImage : null,
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
            Divider(color: modalDivider.withOpacity(0.7)),
            const SizedBox(height: 12),

            Text("Pin Details", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: modalPrimaryBlue)),
            const SizedBox(height: 16),
            _buildDetailRowOrField("Name:", _nameController, isEditing: _isEditing),
            _buildDetailRowOrField("Set:", _setControllerText, isEditing: _isEditing, isSetField: true),
            _buildDetailRowOrField("Quantity:", _quantityController, isEditing: _isEditing, isNumeric: true),
            _buildDetailRowOrField("Notes:", _notesController, isEditing: _isEditing, isMultiLine: true),
            _buildDetailRowOrField("Edition Size:", _editionSizeController, isEditing: _isEditing),
            _buildDetailRowOrField("Origin:", _originController, isEditing: _isEditing),
            _buildDetailRowOrField("Release Date:", _releaseDateController, isEditing: _isEditing, isDateField: true, isTagsField: false),
            _buildDetailRowOrField("Tags:", _tagsController, isEditing: _isEditing, isTagsField: true),

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
                      icon: _isSavingChanges
                          ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSavingChanges ? "Saving..." : "Save Changes"),
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
                      label: const Text("Edit Pin"),
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
    }
    else if (originalUrl != null && originalUrl.isNotEmpty) {
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
    }
    else {
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

  Widget _buildDetailRowOrField(
    String label,
    TextEditingController controller, {
    bool isEditing = false,
    bool isSetField = false,
    bool isNumeric = false,
    bool isMultiLine = false,
    bool isDateField = false,
    bool isTagsField = false,
  }) {
    Widget fieldWidget;

    if (isEditing) {
      if (isSetField) {
        fieldWidget = DropdownButtonFormField<PinSet>(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          value: _selectedModalSet,
          hint: const Text("Select Set"),
          isExpanded: true,
          items: [
            DropdownMenuItem<PinSet>(
              value: null,
              child: Text("No Set / Clear Set", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),
            ),
            ..._modalExistingSets.map((PinSet set) {
              return DropdownMenuItem<PinSet>(
                value: set,
                child: Text(set.name, overflow: TextOverflow.ellipsis),
              );
            }).toList()
          ],
          onChanged: (PinSet? newValue) {
            setState(() {
              _selectedModalSet = newValue;
              _setControllerText.text = newValue?.name ?? "";
            });
          },
        );
      } else {
        fieldWidget = TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : (isMultiLine ? TextInputType.multiline : TextInputType.text),
          maxLines: isMultiLine ? null : 1,
          minLines: isMultiLine ? 3 : 1,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: isDateField
                ? IconButton(
                    icon: Icon(Icons.calendar_today, size: 18, color: modalSecondaryText),
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2101)
                      );
                      if (pickedDate != null) {
                        String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
                        controller.text = formattedDate;
                      }
                    },
                  )
                : null,
          ),
          readOnly: isDateField && !isEditing,
          onTap: isDateField && isEditing ? () async {
            DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2101)
            );
            if (pickedDate != null) {
              String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
              controller.text = formattedDate;
            }
          } : null,
        );
      }
    } else {
        if (isTagsField && controller.text.isNotEmpty) {
            List<String> tags = controller.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
            if (tags.isNotEmpty) {
                fieldWidget = Wrap(
                    spacing: 6.0,
                    runSpacing: 0.0,
                    children: tags.map((tag) => Chip(
                        label: Text(tag, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                        backgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                );
            } else {
                 fieldWidget = const Text("No tags", style: TextStyle(fontSize: 15, color: Colors.black54, fontStyle: FontStyle.italic));
            }
        } else if (isDateField && controller.text.isNotEmpty) {
            try {
                DateTime date = DateFormat('yyyy-MM-dd').parse(controller.text);
                String formattedDate = DateFormat('MMM. dd, yyyy').format(date); // Corrected format
                fieldWidget = Text(formattedDate, style: const TextStyle(fontSize: 15, color: Colors.black87));
            } catch (e) {
                fieldWidget = Text(controller.text, style: const TextStyle(fontSize: 15, color: Colors.red));
                print("Error parsing date for display: $e");
            }
        } else {
          String displayText = controller.text;
          if (isSetField) {
            displayText = _selectedModalSet?.name ?? (widget.pin.setName?.isNotEmpty == true ? widget.pin.setName! : "Not in a set");
          } else if (controller.text.isEmpty && !isDateField && !isTagsField) {
            displayText = "N/A";
          } else if (controller.text.isEmpty && (isDateField || isTagsField)) {
            displayText = "Not set";
          }
          fieldWidget = Text(displayText, style: const TextStyle(fontSize: 15, color: Colors.black87), softWrap: true);
        }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: (isMultiLine && isEditing && !isSetField || (isTagsField && !isEditing && controller.text.isNotEmpty))
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 95,
            child: Padding(
              padding: EdgeInsets.only(top: (isMultiLine && isEditing && !isSetField || (isTagsField && !isEditing && controller.text.isNotEmpty)) ? 8.0 : 0),
              child: Text("$label ", style: TextStyle(color: modalSecondaryText, fontWeight: FontWeight.w600, fontSize: 14)),
            )
          ),
          Expanded(child: fieldWidget),
        ],
      ),
    );
  }
}
