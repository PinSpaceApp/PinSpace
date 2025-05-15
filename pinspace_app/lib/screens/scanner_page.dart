// lib/screens/scanner_page.dart
import 'dart:convert'; // For base64 encoding and jsonDecode
import 'dart:io'; // Still needed for File on mobile
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // To check platform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // HTTP package for backend calls
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase for auth token

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

// --- CONFIGURATION ---
const String pythonApiUrl = 'https://colejunck1.pythonanywhere.com/remove-background';

// Define a simple class for Set objects
class PinSet {
  final int id;
  final String name;

  PinSet({required this.id, required this.name});

  // For easier use in lists if needed, though not strictly necessary for this implementation
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinSet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return name; // This allows the Autocomplete widget to display the name
  }
}


// Define states for the scanner page
enum ScannerProcessStatus {
  initializingCamera,
  cameraPreview,
  imageSelected,
  processingPythonAPI,
  manualEntry,
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

  XFile? _originalXFile;
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;

  final _pinNameController = TextEditingController();
  final _setController = TextEditingController(); // Still used for typing
  
  List<PinSet> _existingSets = []; // Now stores PinSet objects
  List<PinSet> _filteredSetSuggestions = []; // For display in overlay
  PinSet? _selectedSet; // Stores the currently selected PinSet object

  final FocusNode _setFocusNode = FocusNode();
  OverlayEntry? _setSuggestionsOverlayEntry;
  bool _isLoadingSets = false; 

  String? _errorMessage;
  ScannerProcessStatus _status = ScannerProcessStatus.initializingCamera;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    } else {
      setState(() {
        _status = ScannerProcessStatus.noCamera;
        _errorMessage = "Live camera preview not available on web. Use buttons.";
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
          .select('id, name') // Fetch ID and name
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
      print("Fetched sets: ${_existingSets.map((s)=> s.name).toList()}");
    } catch (e) {
      print("Error fetching sets: $e");
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
    List<PinSet> currentSuggestions; // Now a list of PinSet

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

    // This will trigger the overlay to rebuild if it's visible
    if (_setSuggestionsOverlayEntry != null && _setFocusNode.hasFocus) {
        _setSuggestionsOverlayEntry!.markNeedsBuild();
    } else if (_setFocusNode.hasFocus && _filteredSetSuggestions.isNotEmpty && _setSuggestionsOverlayEntry == null) {
        // If overlay was dismissed but field has focus and suggestions exist, show it
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

    _showSetSuggestionsPanel(false); // Hide suggestions first
    _setFocusNode.unfocus();


    // Check if set already exists (case-insensitive) locally
    final existingLocalSet = _existingSets.firstWhere(
        (s) => s.name.toLowerCase() == newSetName.toLowerCase(),
        orElse: () => PinSet(id: -1, name: "") // Dummy non-matching PinSet
    );

    if (existingLocalSet.id != -1) {
        if (mounted) {
            setState(() {
                _setController.text = existingLocalSet.name; 
                _selectedSet = existingLocalSet;
                _setController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _setController.text.length));
            });
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Set \"${existingLocalSet.name}\" already exists and has been selected."), backgroundColor: Colors.blue));
        }
        return;
    }

    // Show loading or disable button
    // For simplicity, we proceed.

    try {
      final userId = supabase.auth.currentUser!.id;
      final List<Map<String, dynamic>> response = await supabase.from('sets').insert({
        'user_id': userId,
        'name': newSetName, 
      }).select('id, name'); // Select to get the inserted row, including its ID and name


      if (response.isEmpty) {
        throw Exception("Failed to create set or retrieve its ID.");
      }
      final newSetData = response.first;
      final createdSet = PinSet(id: newSetData['id'] as int, name: newSetData['name'] as String);

      print("Successfully created set '${createdSet.name}' (ID: ${createdSet.id}) in Supabase.");

      if (mounted) {
        if (!_existingSets.any((s) => s.id == createdSet.id)) {
           _existingSets.add(createdSet);
           _existingSets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); 
        }
        
        setState(() {
          _setController.text = createdSet.name; 
          _selectedSet = createdSet; // Store the selected PinSet object
          _setController.selection = TextSelection.fromPosition(
              TextPosition(offset: _setController.text.length));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Set \"${createdSet.name}\" created!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      print("Error creating new set in Supabase: $e");
      if (mounted) {
        String errorMessage = "Failed to create set.";
        if (e is PostgrestException) {
            if (e.message.contains('unique_set_name_for_user')) {
                errorMessage = "Set \"$newSetName\" already exists.";
                // Attempt to fetch and select it if it somehow got created by another client
                await _fetchUserSets(); // Refresh the list
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

      // Generate suggestions for display (strings)
      List<String> displaySuggestions = _filteredSetSuggestions.map((set) => set.name).toList();
      final String currentQuery = _setController.text.trim();
      final bool exactMatchInFiltered = _filteredSetSuggestions.any((set) => set.name.toLowerCase() == currentQuery.toLowerCase());

      if (currentQuery.isNotEmpty && !exactMatchInFiltered) {
          displaySuggestions.insert(0, "+ Create \"$currentQuery\"");
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
                itemCount: displaySuggestions.length, // Use displaySuggestions
                itemBuilder: (context, index) {
                  final suggestionString = displaySuggestions[index];
                  bool isCreateOption = suggestionString.startsWith("+ Create \"");
                  
                  String textToShow = suggestionString;
                  if (isCreateOption) {
                    textToShow = suggestionString.substring(2); // Removes "+ "
                  }

                  return ListTile(
                    title: Text(
                        textToShow, 
                        style: TextStyle(
                            fontWeight: isCreateOption 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                            color: isCreateOption
                                        ? Theme.of(context).colorScheme.primary
                                        : null
                        ),
                    ),
                    dense: true,
                    onTap: () {
                      if (isCreateOption) {
                        String newSetNameFromTextField = _setController.text.trim(); // Name to create
                        _createNewSetAndSelect(newSetNameFromTextField); 
                      } else {
                        // User selected an existing set from the string list, find the PinSet object
                        final selectedPinSet = _existingSets.firstWhere(
                            (s) => s.name == suggestionString,
                            orElse: () => PinSet(id: -1, name: "") // Should not happen if list is correct
                        );
                        if (mounted && selectedPinSet.id != -1) {
                          setState(() {
                            _setController.text = selectedPinSet.name; 
                            _selectedSet = selectedPinSet; // Store the PinSet object
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
      // _onSetSearchChanged(); // This might be redundant if called by text field listener
    } else if (!show && _setSuggestionsOverlayEntry != null) {
      _setSuggestionsOverlayEntry!.remove();
      _setSuggestionsOverlayEntry = null;
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      setState(() { _status = ScannerProcessStatus.noCamera; _errorMessage = "Live preview unavailable on web."; });
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
      _originalXFile = null;
      _originalImageBytes = null;
      _processedImageBytes = null;
      _errorMessage = null;
      _pinNameController.clear();
      _setController.clear(); 
      _selectedSet = null; // Clear selected set object
      _filteredSetSuggestions = [];
      _showSetSuggestionsPanel(false); 

      if (!kIsWeb && _cameraController != null && _cameraController!.value.isInitialized) {
        _status = ScannerProcessStatus.cameraPreview;
      } else if (!kIsWeb) {
        _status = ScannerProcessStatus.initializingCamera;
        _initializeCamera();
      } else {
        _status = ScannerProcessStatus.noCamera;
        _errorMessage = "Use buttons to scan or upload.";
      }
    });
  }

  Future<Uint8List?> _callPythonAnywhereAPI(Uint8List imageBytes, String fileName) async {
    setState(() { _status = ScannerProcessStatus.processingPythonAPI; _errorMessage = null; });
    print('CALLING PYTHON API: URL: $pythonApiUrl');
    print('CALLING PYTHON API: Original image byte length: ${imageBytes.length}');
    print('CALLING PYTHON API: Original filename: $fileName');
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse(pythonApiUrl));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );

      final response = await request.send();
      print('PYTHON API RESPONSE: Status Code: ${response.statusCode}');
      response.headers.forEach((key, value) {
          print('PYTHON API RESPONSE: Header: $key = $value');
      });

      if (response.statusCode == 200) {
        final processedBytes = await response.stream.toBytes();
        print('PYTHON API RESPONSE: Success. Received processed byte length: ${processedBytes.length}');
        if (!mounted) return null;
        return processedBytes;
      } else {
        final errorBody = await response.stream.bytesToString();
        print('PYTHON API RESPONSE: Error Body: $errorBody');
        String displayError = errorBody;
        try {
            final Map<String, dynamic> errorJson = jsonDecode(errorBody);
            if (errorJson.containsKey('error')) {
                displayError = errorJson['error'];
            }
        } catch (_) {
            displayError = response.reasonPhrase ?? errorBody;
        }
        if (mounted) {
          setState(() {
            _processedImageBytes = null;
            _errorMessage = 'PythonAPI processing failed: $displayError';
            _status = ScannerProcessStatus.error;
          });
        }
        return null;
      }
    } catch (e) {
      print('PYTHON API CALL: Exception: $e');
      if (mounted) {
        setState(() {
          _processedImageBytes = null;
          _errorMessage = 'Could not connect to Python processing service: $e';
          _status = ScannerProcessStatus.error;
        });
      }
      return null;
    }
  }

  Future<void> _handleImageSelection(XFile imageFile) async {
    setState(() {
      _originalXFile = imageFile;
      _processedImageBytes = null;
      _status = ScannerProcessStatus.imageSelected;
      _errorMessage = null;
    });

    _originalImageBytes = await imageFile.readAsBytes();
    String fileName = imageFile.name;

    final processedBytesFromPython = await _callPythonAnywhereAPI(_originalImageBytes!, fileName);
    
    if (mounted) {
        if (processedBytesFromPython != null) {
            setState(() {
                _processedImageBytes = processedBytesFromPython;
                _status = ScannerProcessStatus.manualEntry; 
            });
        } else {
            if (_status != ScannerProcessStatus.error) {
                 setState(() { _status = ScannerProcessStatus.error; _errorMessage = _errorMessage ?? "Failed to process image via Python API.";});
            }
        }
    }
  }

  Future<void> _captureWithCamera() async {
    if (kIsWeb) {
      await _pickImageUsingPicker(ImageSource.camera);
      return;
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() { _errorMessage = 'Camera not ready.'; _status = ScannerProcessStatus.error; });
      return;
    }
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final XFile imageXFile = await _cameraController!.takePicture();
      await _handleImageSelection(imageXFile);
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = 'Failed to capture image: $e'; _status = ScannerProcessStatus.error; });
      }
    }
  }

  Future<void> _pickImageUsingPicker(ImageSource source) async {
    setState(() {
      _originalXFile = null;
      _originalImageBytes = null;
      _processedImageBytes = null;
      _errorMessage = null;
      _pinNameController.clear();
      _setController.clear();
      _selectedSet = null; // Clear selected set object
      _filteredSetSuggestions.clear();
      _showSetSuggestionsPanel(false);
    });
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 1600);
      if (pickedFile != null) {
        await _handleImageSelection(pickedFile);
      } else {
        if (mounted) _resetScannerState();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = 'Failed to pick image: $e'; _status = ScannerProcessStatus.error; });
      }
    }
  }
  
  void _savePin() async { 
    if (_processedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No processed image to save."))
      );
      return;
    }
    final String pinName = _pinNameController.text.trim();
    // final String setNameFromField = _setController.text.trim(); // Value in text field

    if (pinName.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pin name cannot be empty."))
      );
      return;
    }
    
    // Set name is optional. If _selectedSet is null but _setController has text,
    // it means user typed something but didn't explicitly create/select.
    // For now, we only save set_id if _selectedSet is not null.
    // You could add logic here to auto-create if _setController.text is new and _selectedSet is null.

    setState(() { _status = ScannerProcessStatus.saving; });

    try {
      final userId = supabase.auth.currentUser!.id;
      final imagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.webp';
      
      await supabase.storage.from('pin-images').uploadBinary(
        imagePath,
        _processedImageBytes!,
        fileOptions: const FileOptions(contentType: 'image/webp', upsert: false),
      );
      final publicImageUrl = supabase.storage.from('pin-images').getPublicUrl(imagePath);
      
      Map<String, dynamic> pinData = {
        'user_id': userId,
        'name': pinName,
        'image_url': publicImageUrl,
        'quantity': 1, 
      };

      if (_selectedSet != null) { // Use the ID from the selected PinSet object
        pinData['set_id'] = _selectedSet!.id;
      }
      // If you also want to store the set_name directly in pins table (redundant but sometimes useful for display)
      // if (_selectedSet != null) {
      //   pinData['set_name_cache'] = _selectedSet!.name;
      // } else if (setNameFromField.isNotEmpty) {
      //   pinData['set_name_cache'] = setNameFromField; // If user typed something but didn't create/select
      // }
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Pin")),
      body: GestureDetector( 
        onTap: () {
          FocusScope.of(context).unfocus(); 
          _showSetSuggestionsPanel(false); 
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 10),
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  alignment: Alignment.center,
                  child: _buildPreviewContent(),
                ),
              ),
              const SizedBox(height: 10),
              
              if (_status == ScannerProcessStatus.manualEntry && _processedImageBytes != null)
                Expanded(
                  flex: 2, 
                  child: SingleChildScrollView(child: _buildPinDetailsForm()),
                ),
              if (_status == ScannerProcessStatus.error && _errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center, 
                  ),
                ),
              const SizedBox(height: 10),
              _buildActionButtons(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (_status) {
      case ScannerProcessStatus.initializingCamera:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Initializing Camera...")]);
      case ScannerProcessStatus.noCamera:
        return Text(_errorMessage ?? "No camera found or permission denied.", textAlign: TextAlign.center);
      case ScannerProcessStatus.cameraPreview:
        if (kIsWeb) return const Text("Use 'Capture' or 'Gallery' buttons.");
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          return FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CameraPreview(_cameraController!));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        }
        return const Text("Preparing camera...");

      case ScannerProcessStatus.processingPythonAPI:
        if (_originalXFile != null) { 
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: kIsWeb 
                    ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s){ print("Error displaying original web image: $e"); return const Center(child: Text("Error displaying image"));})
                    : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s){ print("Error displaying original file image: $e"); return const Center(child: Text("Error displaying image"));})
              )),
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text("Processing Image..."),
            ],
          );
        }
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Processing Image...")]);
      
      case ScannerProcessStatus.saving:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Saving pin...")]);

      case ScannerProcessStatus.imageSelected: 
        if (_originalXFile != null) {
          return kIsWeb
              ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")))
              : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")));
        }
        return const Text('Tap Capture or Gallery.');

      case ScannerProcessStatus.manualEntry: 
      case ScannerProcessStatus.error:
        if (_processedImageBytes != null) {
           print('BUILD_PREVIEW: Attempting to display processed image with Image.memory(). Byte length: ${_processedImageBytes!.length}');
          return Image.memory(_processedImageBytes!, fit: BoxFit.contain, errorBuilder: (c,e,s) {
            print('BUILD_PREVIEW: ErrorBuilder for Image.memory(): $e');
            return const Center(child: Text("Error displaying processed image"));
          });
        } else if (_originalXFile != null && _status == ScannerProcessStatus.error) { 
           print('BUILD_PREVIEW: Error status, showing original image as fallback.');
           return kIsWeb
              ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying original image")))
              : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying original image")));
        }
        return Text(_errorMessage ?? 'No image to display. Tap Capture or Gallery.');
      default: 
        return const Text('Please capture or select an image.');
    }
  }

  Widget _buildPinDetailsForm() {
    if (!(_status == ScannerProcessStatus.manualEntry && _processedImageBytes != null)) {
        return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: _pinNameController,
          decoration: const InputDecoration(labelText: 'Pin Name', border: OutlineInputBorder())
        ),
        const SizedBox(height: 10),
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
    final bool isProcessing = _status == ScannerProcessStatus.processingPythonAPI ||
                                  _status == ScannerProcessStatus.saving ||
                                  _status == ScannerProcessStatus.initializingCamera;

    if (_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera || _status == ScannerProcessStatus.initializingCamera) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture'),
              onPressed: isProcessing || (_status == ScannerProcessStatus.noCamera && !kIsWeb && _cameraController == null) ? null : _captureWithCamera,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: isProcessing ? null : () => _pickImageUsingPicker(ImageSource.gallery),
            ),
          ),
        ],
      );
    } else if (_status == ScannerProcessStatus.manualEntry ||
               _status == ScannerProcessStatus.imageSelected || 
               _status == ScannerProcessStatus.error) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                if (_status == ScannerProcessStatus.manualEntry && _processedImageBytes != null)
                    ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Pin to My Collection'), // MODIFIED TEXT
                        onPressed: isProcessing ? null : _savePin,
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                    ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan/Upload New Pin'),
                    onPressed: isProcessing ? null : _resetScannerState,
                ),
            ],
        );
    }
    return Container(); 
  }
}
