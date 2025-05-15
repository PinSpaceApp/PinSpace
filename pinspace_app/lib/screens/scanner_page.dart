// lib/screens/scanner_page.dart
import 'dart:convert'; // For base64 encoding and jsonDecode
import 'dart:io'; // Still needed for File on mobile
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // To check platform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // HTTP package for backend calls
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

// --- CONFIGURATION ---
const String pythonApiUrl = 'https://colejunck1.pythonanywhere.com/remove-background';

// Define a simple class for Set objects
class PinSet {
  final int id;
  final String name;
  PinSet({required this.id, required this.name});
  @override
  String toString() => name;
}

// Enum to track which image we are currently targeting
enum ImageTarget { front, back }

// Define states for the scanner page
enum ScannerProcessStatus {
  initializingCamera,
  cameraPreview, // Ready to capture front
  frontImageSelected, // Front image selected, pre-Python API call for front
  processingFrontPythonAPI, // Calling PythonAnywhere for front image
  frontImageProcessed, // Front image processed, ready to capture back or enter details
  backImageSelected, // Back image selected, pre-Python API call for back
  processingBackPythonAPI, // Calling PythonAnywhere for back image
  manualEntry, // Both images potentially processed, details can be entered
  saving,
  error,
  noCamera,
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Future<void>? _initializeControllerFuture;

  // Front Image State
  XFile? _originalFrontXFile;
  Uint8List? _originalFrontImageBytes;
  Uint8List? _processedFrontImageBytes;

  // Back Image State
  XFile? _originalBackXFile;
  Uint8List? _originalBackImageBytes;
  Uint8List? _processedBackImageBytes; 

  final _pinNameController = TextEditingController();
  final _setController = TextEditingController();
  
  List<PinSet> _existingSets = []; 
  List<PinSet> _filteredSetSuggestions = []; 
  PinSet? _selectedSet; 

  final FocusNode _setFocusNode = FocusNode();
  OverlayEntry? _setSuggestionsOverlayEntry;
  bool _isLoadingSets = false; 

  String? _errorMessage;
  ScannerProcessStatus _status = ScannerProcessStatus.initializingCamera;

  final ImagePicker _picker = ImagePicker();
  bool _showTip = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    } else {
      setState(() {
        _status = ScannerProcessStatus.noCamera;
        _errorMessage = "Live camera preview not available on web. Use buttons below image areas.";
      });
    }
    _fetchUserSets(); 

    _setController.addListener(_onSetSearchChanged);
    _setFocusNode.addListener(_setFocusNodeListener);
  }
  
  void _setFocusNodeListener() {
    if (_setFocusNode.hasFocus) {
      _showSetSuggestionsPanel(true);
      if (_existingSets.isEmpty && !_isLoadingSets) { 
          _fetchUserSets();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
          if (!_setFocusNode.hasFocus) { 
            _showSetSuggestionsPanel(false);
          }
      });
    }
  }

  Future<void> _fetchUserSets() async {
    if (supabase.auth.currentUser == null) return; 
    setState(() { _isLoadingSets = true; });
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('sets')
          .select('id, name') 
          .eq('user_id', userId)
          .order('name', ascending: true); 

      final sets = response
          .map((item) => PinSet(id: item['id'] as int, name: item['name'] as String))
          .toList();
      if (mounted) { 
        setState(() {
          _existingSets = sets;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching your sets: ${e.toString()}"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingSets = false; });
      }
    }
  }

  void _onSetSearchChanged() {
    final String query = _setController.text.trim(); 
    final String lowerCaseQuery = query.toLowerCase();
    List<PinSet> currentSuggestions;

    if (query.isEmpty) {
      currentSuggestions = List.from(_existingSets);
    } else {
      currentSuggestions = _existingSets
          .where((set) => set.name.toLowerCase().contains(lowerCaseQuery))
          .toList();
    }
    
    if (mounted) {
      setState(() {
        _filteredSetSuggestions = currentSuggestions;
      });
    }

    if (_setSuggestionsOverlayEntry != null && _setFocusNode.hasFocus) {
        _setSuggestionsOverlayEntry!.markNeedsBuild();
    } else if (_setFocusNode.hasFocus && (_filteredSetSuggestions.isNotEmpty || query.isNotEmpty) && _setSuggestionsOverlayEntry == null) {
        _showSetSuggestionsPanel(true);
    }
  }

  Future<void> _createNewSetAndSelect(String newSetNameRaw) async {
    final String newSetName = newSetNameRaw.trim(); 
    if (newSetName.isEmpty) return;
    if (supabase.auth.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You must be logged in to create a set."), backgroundColor: Colors.red));
        return;
    }

    _showSetSuggestionsPanel(false); 
    _setFocusNode.unfocus();

    final existingLocalSet = _existingSets.firstWhere(
        (s) => s.name.toLowerCase() == newSetName.toLowerCase(),
        orElse: () => PinSet(id: -1, name: "") 
    );

    if (existingLocalSet.id != -1) {
        if (mounted) {
            setState(() {
                _setController.text = existingLocalSet.name; 
                _selectedSet = existingLocalSet;
                _setController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _setController.text.length));
            });
        }
        return;
    }
    try {
      final userId = supabase.auth.currentUser!.id;
      final List<Map<String, dynamic>> response = await supabase.from('sets').insert({
        'user_id': userId,
        'name': newSetName, 
      }).select('id, name'); 

      if (response.isEmpty) throw Exception("Failed to create set or retrieve its ID.");
      final newSetData = response.first;
      final createdSet = PinSet(id: newSetData['id'] as int, name: newSetData['name'] as String);

      if (mounted) {
        if (!_existingSets.any((s) => s.id == createdSet.id)) {
           _existingSets.add(createdSet);
           _existingSets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); 
        }
        setState(() {
          _setController.text = createdSet.name; 
          _selectedSet = createdSet; 
          _setController.selection = TextSelection.fromPosition(
              TextPosition(offset: _setController.text.length));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Set \"${createdSet.name}\" created!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
         String errorMessage = "Failed to create set.";
        if (e is PostgrestException) {
            if (e.message.contains('unique_set_name_for_user')) {
                errorMessage = "Set \"$newSetName\" already exists.";
                await _fetchUserSets(); 
                final justCreatedSet = _existingSets.firstWhere(
                    (s) => s.name.toLowerCase() == newSetName.toLowerCase(),
                    orElse: () => PinSet(id: -1, name: "")
                );
                if (justCreatedSet.id != -1) {
                    setState(() {
                        _setController.text = justCreatedSet.name;
                        _selectedSet = justCreatedSet;
                    });
                }
            } else {
                 errorMessage = "Failed to create set: ${e.message}";
            }
        } else {
            errorMessage = "Failed to create set: ${e.toString()}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showSetSuggestionsPanel(bool show) {
    if (show && _setSuggestionsOverlayEntry == null) {
      final overlay = Overlay.of(context);
      if (overlay == null) return;
      final RenderBox? textFieldRenderBox = _setFocusNode.context?.findRenderObject() as RenderBox?;
      if (textFieldRenderBox == null) return; 

      final textFieldSize = textFieldRenderBox.size;
      final textFieldOffset = textFieldRenderBox.localToGlobal(Offset.zero, ancestor: overlay.context.findRenderObject());

      List<String> displayableSuggestionStrings = _filteredSetSuggestions.map((set) => set.name).toList();
      final String currentQuery = _setController.text.trim();
      final bool exactMatchInFiltered = _filteredSetSuggestions.any((set) => set.name.toLowerCase() == currentQuery.toLowerCase());

      if (currentQuery.isNotEmpty && !exactMatchInFiltered) {
          displayableSuggestionStrings.insert(0, "+ Create \"$currentQuery\"");
      }

      _setSuggestionsOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: textFieldOffset.dy + textFieldSize.height + 4.0, 
          left: textFieldOffset.dx,
          width: textFieldSize.width,
          child: Material( 
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200), 
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: displayableSuggestionStrings.length,
                itemBuilder: (context, index) {
                  final suggestionString = displayableSuggestionStrings[index];
                  bool isCreateOption = suggestionString.startsWith("+ Create \"");
                  
                  String textToShow = suggestionString;
                  if (isCreateOption) {
                    textToShow = suggestionString.substring(2); 
                  }

                  return ListTile(
                    title: Text(
                        textToShow, 
                        style: TextStyle(
                            fontWeight: isCreateOption ? FontWeight.bold : FontWeight.normal,
                            color: isCreateOption ? Theme.of(context).colorScheme.primary : null
                        ),
                    ),
                    dense: true,
                    onTap: () {
                      if (isCreateOption) {
                        String newSetNameFromTextField = _setController.text.trim();
                        _createNewSetAndSelect(newSetNameFromTextField); 
                      } else {
                        final selectedPinSet = _existingSets.firstWhere(
                            (s) => s.name == suggestionString, 
                            orElse: () => PinSet(id: -1, name: "") 
                        );
                        if (mounted && selectedPinSet.id != -1) {
                          setState(() {
                            _setController.text = selectedPinSet.name; 
                            _selectedSet = selectedPinSet; 
                            _setController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _setController.text.length));
                          });
                        }
                        _showSetSuggestionsPanel(false);
                        _setFocusNode.unfocus();
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      overlay.insert(_setSuggestionsOverlayEntry!);
      if(_setFocusNode.hasFocus) _onSetSearchChanged();
    } else if (!show && _setSuggestionsOverlayEntry != null) {
      _setSuggestionsOverlayEntry!.remove();
      _setSuggestionsOverlayEntry = null;
    }
  }

  Future<void> _initializeCamera() async {
     if (kIsWeb) {
      setState(() { _status = ScannerProcessStatus.noCamera; _errorMessage = "Live camera preview not available on web. Use buttons."; });
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() { _status = ScannerProcessStatus.noCamera; _errorMessage = "No cameras available."; });
        return;
      }
      final firstCamera = _cameras!.first;
      _cameraController = CameraController(firstCamera, ResolutionPreset.high, enableAudio: false);
      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;
      if (!mounted) return;
      setState(() { _status = ScannerProcessStatus.cameraPreview; });
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _status = ScannerProcessStatus.noCamera;
          if (e is CameraException) { _errorMessage = "Camera error: ${e.description}"; }
          else { _errorMessage = "Failed to initialize camera."; }
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pinNameController.dispose();
    _setController.removeListener(_onSetSearchChanged);
    _setController.dispose();
    _setFocusNode.removeListener(_setFocusNodeListener); 
    _setFocusNode.dispose();
    _setSuggestionsOverlayEntry?.remove();
    super.dispose();
  }

  void _resetScannerState() {
    setState(() {
      _originalFrontXFile = null;
      _originalFrontImageBytes = null;
      _processedFrontImageBytes = null;
      _originalBackXFile = null;
      _originalBackImageBytes = null;
      _processedBackImageBytes = null; 

      _errorMessage = null;
      _pinNameController.clear();
      _setController.clear(); 
      _selectedSet = null; 
      _filteredSetSuggestions = [];
      _showSetSuggestionsPanel(false); 

      if (!kIsWeb && _cameraController != null && _cameraController!.value.isInitialized) {
        _status = ScannerProcessStatus.cameraPreview;
      } else if (!kIsWeb) {
        _status = ScannerProcessStatus.initializingCamera;
        _initializeCamera();
      } else {
        _status = ScannerProcessStatus.noCamera;
        _errorMessage = "Live camera preview not available on web. Use buttons below image areas."; 
      }
    });
  }

  Future<Uint8List?> _callPythonAnywhereAPI(Uint8List imageBytes, String fileName, ImageTarget target) async {
    setState(() { 
      _status = (target == ImageTarget.front) ? ScannerProcessStatus.processingFrontPythonAPI : ScannerProcessStatus.processingBackPythonAPI;
      _errorMessage = null; 
    });
    print('CALLING PYTHON API: URL: $pythonApiUrl for ${target.name} image: $fileName');
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse(pythonApiUrl));
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));
      final response = await request.send();
      print('PYTHON API RESPONSE (${target.name}): Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final processedBytes = await response.stream.toBytes();
        print('PYTHON API RESPONSE (${target.name}): Success. Received ${processedBytes.length} bytes.');
        return processedBytes;
      } else {
        final errorBody = await response.stream.bytesToString();
        print('PYTHON API RESPONSE (${target.name}): Error Body: $errorBody');
        if(mounted) {
          setState(() {
            _errorMessage = 'PythonAPI processing for ${target.name} failed: ${jsonDecode(errorBody)['error'] ?? errorBody}';
            _status = ScannerProcessStatus.error;
          });
        }
        return null;
      }
    } catch (e) {
      print('PYTHON API CALL (${target.name}): Exception: $e');
      if(mounted) {
        setState(() {
          _errorMessage = 'Could not connect to Python processing service for ${target.name}: $e';
          _status = ScannerProcessStatus.error;
        });
      }
      return null;
    }
  }

  Future<void> _handleImageSelection(XFile imageFile, ImageTarget target) async {
    final imageBytes = await imageFile.readAsBytes();
    String fileName = imageFile.name;

    if (target == ImageTarget.front) {
      setState(() {
        _originalFrontXFile = imageFile;
        _originalFrontImageBytes = imageBytes;
        _processedFrontImageBytes = null; 
        _errorMessage = null;
      });
      
      final processedBytes = await _callPythonAnywhereAPI(imageBytes, fileName, ImageTarget.front);
      if (mounted) {
        if (processedBytes != null) {
          setState(() {
            _processedFrontImageBytes = processedBytes;
            _status = _originalBackXFile == null ? ScannerProcessStatus.frontImageProcessed : ScannerProcessStatus.manualEntry;
          });
        } 
      }
    } else if (target == ImageTarget.back) {
      setState(() {
        _originalBackXFile = imageFile;
        _originalBackImageBytes = imageBytes;
        _processedBackImageBytes = null; 
        _errorMessage = null;
      });

      final processedBytes = await _callPythonAnywhereAPI(imageBytes, fileName, ImageTarget.back);
      if (mounted) {
        if (processedBytes != null) {
          setState(() {
            _processedBackImageBytes = processedBytes;
            _status = ScannerProcessStatus.manualEntry; 
          });
        } 
      }
    }
  }

  Future<void> _captureOrPickImage(ImageSource source, ImageTarget target) async {
    if (target == ImageTarget.front) {
      setState(() { _originalFrontXFile = null; _originalFrontImageBytes = null; _processedFrontImageBytes = null; });
    } else {
      setState(() { _originalBackXFile = null; _originalBackImageBytes = null; _processedBackImageBytes = null; });
    }

    if (source == ImageSource.camera && !kIsWeb) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        setState(() { _errorMessage = 'Camera not ready.'; _status = ScannerProcessStatus.error; });
        return;
      }
      if (_cameraController!.value.isTakingPicture) return;
      try {
        final XFile imageXFile = await _cameraController!.takePicture();
        await _handleImageSelection(imageXFile, target);
      } catch (e) {
        if (mounted) setState(() { _errorMessage = 'Failed to capture image: $e'; _status = ScannerProcessStatus.error; });
      }
    } else { 
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 1600);
        if (pickedFile != null) {
          await _handleImageSelection(pickedFile, target);
        }
      } catch (e) {
        if (mounted) setState(() { _errorMessage = 'Failed to pick image: $e'; _status = ScannerProcessStatus.error; });
      }
    }
  }
  
  void _savePin() async { 
    if (_processedFrontImageBytes == null) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Front image is missing or not processed."))
      );
      return;
    }
    if (_originalBackXFile != null && _processedBackImageBytes == null && _status != ScannerProcessStatus.processingBackPythonAPI) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Back image selected but not yet processed. Please wait or try again."))
      );
      return; 
    }

    final String pinName = _pinNameController.text.trim();
    if (pinName.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pin name cannot be empty."))
      );
      return;
    }
    
    setState(() { _status = ScannerProcessStatus.saving; });

    try {
      final userId = supabase.auth.currentUser!.id;
      String? publicFrontImageUrl;
      String? publicBackImageUrl;

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final frontImageFileName = _originalFrontXFile?.name ?? "front_$timestamp.webp";
      final frontImagePath = '$userId/front_${timestamp}_${Uri.encodeComponent(frontImageFileName)}';
      await supabase.storage.from('pin-images').uploadBinary(
        frontImagePath,
        _processedFrontImageBytes!,
        fileOptions: const FileOptions(contentType: 'image/webp', upsert: false),
      );
      publicFrontImageUrl = supabase.storage.from('pin-images').getPublicUrl(frontImagePath);

      if (_processedBackImageBytes != null) { 
        final backImageFileName = _originalBackXFile?.name ?? "back_$timestamp.webp";
        final backImagePath = '$userId/back_${timestamp}_${Uri.encodeComponent(backImageFileName)}';
        
        await supabase.storage.from('pin-images').uploadBinary(
          backImagePath,
          _processedBackImageBytes!, 
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: false), 
        );
        publicBackImageUrl = supabase.storage.from('pin-images').getPublicUrl(backImagePath);
      }
      
      Map<String, dynamic> pinData = {
        'user_id': userId,
        'name': pinName,
        'image_url': publicFrontImageUrl, 
        'image_back_url': publicBackImageUrl, 
        'quantity': 1, 
      };

      if (_selectedSet != null) { 
        pinData['set_id'] = _selectedSet!.id;
      }
      
      await supabase.from('pins').insert(pinData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin saved successfully!'), backgroundColor: Colors.green)
        );
        _resetScannerState(); 
      }

    } catch (e) {
      print("Error saving pin: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to save pin: $e";
          _status = ScannerProcessStatus.error;
        });
      }
    }
  }

  Widget _buildImageCaptureArea(ImageTarget target) {
    bool isFront = target == ImageTarget.front;
    XFile? currentOriginalXFile = isFront ? _originalFrontXFile : _originalBackXFile;
    Uint8List? displayBytes = isFront ? _processedFrontImageBytes : _processedBackImageBytes;
    displayBytes ??= isFront ? _originalFrontImageBytes : _originalBackImageBytes;

    String title = isFront ? "Pin Front" : "Pin Back";
    bool isLoadingThisImage = (isFront && _status == ScannerProcessStatus.processingFrontPythonAPI) ||
                              (!isFront && _status == ScannerProcessStatus.processingBackPythonAPI);
    
    bool canCapture = _status != ScannerProcessStatus.saving && !isLoadingThisImage;

    Widget imageDisplayContent;
    if (isLoadingThisImage) {
        imageDisplayContent = const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:8), Text("Processing...")],));
    } else if (displayBytes != null) {
      imageDisplayContent = Image.memory(displayBytes, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey));
    } else if (currentOriginalXFile != null && !isFront && !isLoadingThisImage) { 
       imageDisplayContent = kIsWeb 
          ? Image.network(currentOriginalXFile.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey))
          : Image.file(File(currentOriginalXFile.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey));
    }
    else {
      imageDisplayContent = Icon(isFront ? Icons.photo_camera_front_outlined : Icons.photo_camera_back_outlined, size: 60, color: Colors.grey[400]);
    }

    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(11), 
                child: imageDisplayContent
            ),
          ),
        ),
        const SizedBox(height: 8),
        // *** MODIFIED BUTTON LAYOUT ***
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text("Capture"),
                onPressed: !canCapture || (_cameraController == null && !kIsWeb) ? null : () => _captureOrPickImage(ImageSource.camera, target),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced padding
                  textStyle: const TextStyle(fontSize: 12), // Smaller text
                ),
              ),
            ),
            const SizedBox(width: 8), // Space between buttons
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text("Gallery"),
                onPressed: !canCapture ? null : () => _captureOrPickImage(ImageSource.gallery, target),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Reduced padding
                  textStyle: const TextStyle(fontSize: 12), // Smaller text
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPhotoTip() {
    if (!_showTip) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50]?.withOpacity(0.8), 
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.blueGrey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.shade100.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Colors.amber[700], size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // *** MODIFIED TIP TEXT ***
              "PinSpace Photography Tip:\nPlace your pin on a plain, well-lit background for the best background removal results! ✨",
              style: TextStyle(fontSize: 13.5, color: Colors.blueGrey[900], height: 1.4),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _showTip = false),
            child: Icon(Icons.close_rounded, size: 20, color: Colors.blueGrey[400]),
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Pin")),
      body: GestureDetector( 
        onTap: () {
          FocusScope.of(context).unfocus(); 
          _showSetSuggestionsPanel(false); 
        },
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_status == ScannerProcessStatus.initializingCamera)
                const Center(child: Column(children: [CircularProgressIndicator(), Text("Initializing Camera...")])),
              
              if (_status == ScannerProcessStatus.noCamera && kIsWeb) 
                 Padding(
                   padding: const EdgeInsets.only(bottom: 16.0),
                   child: Center(child: Text(_errorMessage ?? "Camera not available. Use buttons in image areas.", style: TextStyle(color: Colors.orange[700]))),
                 ),
              if (_status == ScannerProcessStatus.noCamera && !kIsWeb) 
                 Padding(
                   padding: const EdgeInsets.only(bottom: 16.0),
                   child: Center(child: Text(_errorMessage ?? "No camera found.", style: TextStyle(color: Colors.red[700]))),
                 ),


              if (_status != ScannerProcessStatus.initializingCamera) ...[
                _buildPhotoTip(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SizedBox(height: 280, child: _buildImageCaptureArea(ImageTarget.front))),
                    const SizedBox(width: 16),
                    Expanded(child: SizedBox(height: 280, child: _buildImageCaptureArea(ImageTarget.back))),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_processedFrontImageBytes != null || _processedBackImageBytes != null || _status == ScannerProcessStatus.manualEntry) ...[ 
                  _buildPinDetailsForm(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                ] else if (_status != ScannerProcessStatus.processingFrontPythonAPI && 
                           _status != ScannerProcessStatus.processingBackPythonAPI &&
                           _status != ScannerProcessStatus.error && 
                           _status != ScannerProcessStatus.noCamera && 
                           _status != ScannerProcessStatus.initializingCamera
                           ) ... [
                     _buildActionButtons(), // Show reset button if in an intermediate state
                ],


                if (_status == ScannerProcessStatus.error && _errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                      textAlign: TextAlign.center, 
                    ),
                  ),
              ],
              const SizedBox(height: 20), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDetailsForm() {
    bool showForm = _originalFrontXFile != null || _originalBackXFile != null;

    if (!showForm) {
        return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _pinNameController,
          decoration: const InputDecoration(labelText: 'Pin Name', border: OutlineInputBorder())
        ),
        const SizedBox(height: 16),
        Focus( 
          focusNode: _setFocusNode,
          child: TextFormField(
            controller: _setController,
            decoration: InputDecoration(
                labelText: 'Set Name (Optional)', 
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingSets ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,))) : null,
            ),
            onChanged: (value) {
              _onSetSearchChanged(); 
              if (_setFocusNode.hasFocus && (_setSuggestionsOverlayEntry == null || (_setSuggestionsOverlayEntry != null && !_setSuggestionsOverlayEntry!.mounted) )) {
                  _showSetSuggestionsPanel(true);
              } else if (_setFocusNode.hasFocus && _setSuggestionsOverlayEntry != null && _setSuggestionsOverlayEntry!.mounted) {
                  _setSuggestionsOverlayEntry!.markNeedsBuild(); 
              }
            },
            onTap: () { 
                 if (!_setFocusNode.hasFocus) { 
                    _setFocusNode.requestFocus(); 
                 } else { 
                    _showSetSuggestionsPanel(true); 
                 }
            }
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
     bool canSave = _processedFrontImageBytes != null && 
                   _status != ScannerProcessStatus.saving && 
                   _status != ScannerProcessStatus.processingFrontPythonAPI &&
                   _status != ScannerProcessStatus.processingBackPythonAPI &&
                   _status != ScannerProcessStatus.initializingCamera;
    if (_originalBackXFile != null && (_processedBackImageBytes == null && _status != ScannerProcessStatus.processingBackPythonAPI)) {
        canSave = false;
    }

    bool canReset = _status != ScannerProcessStatus.saving && 
                    _status != ScannerProcessStatus.processingFrontPythonAPI &&
                    _status != ScannerProcessStatus.processingBackPythonAPI &&
                    _status != ScannerProcessStatus.initializingCamera;

    // Show action buttons (Save/Clear) if any image interaction has started,
    // or if there's an error, or if ready for manual entry.
    // Don't show if purely in camera preview/no camera initial state without any image yet.
    bool showMainActions = (_originalFrontXFile != null || _originalBackXFile != null || _processedFrontImageBytes != null || _processedBackImageBytes != null || _status == ScannerProcessStatus.error || _status == ScannerProcessStatus.manualEntry);
    
    if (!showMainActions && (_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera || _status == ScannerProcessStatus.initializingCamera) ) {
      // In initial camera/no camera states, the capture buttons are inside _buildImageCaptureArea.
      // We might only want a "Reset" button if an error occurred in these initial states.
      if(_status == ScannerProcessStatus.error && _errorMessage != null) {
         return OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Start Over'),
            onPressed: canReset ? _resetScannerState : null, 
        );
      }
      return const SizedBox.shrink();
    }
    
    // If past initial states (e.g. image selected, processing, manual entry, error after selection)
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Pin to My Collection'), 
                onPressed: canSave ? _savePin : null, 
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, 
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12)
                ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Clear & Scan New'),
                onPressed: canReset ? _resetScannerState : null, 
            ),
        ],
    );
  }
}
