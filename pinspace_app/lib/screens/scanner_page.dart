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

// Get a reference to the Supabase client instance (if not already global in main.dart)
final supabase = Supabase.instance.client;

// Define states for the scanner page
enum ScannerProcessStatus {
  initializingCamera,
  cameraPreview,
  imageSelected,
  processingAI,
  showingSuggestions,
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

  XFile? _currentXFile;

  List<String> _suggestedImageUrls = [];
  String? _selectedHiResImageUrl;

  final _seriesController = TextEditingController();
  final _releaseDateController = TextEditingController();
  final _originController = TextEditingController();
  final _avgPriceController = TextEditingController();
  final _pinNameController = TextEditingController();

  String? _errorMessage;
  ScannerProcessStatus _status = ScannerProcessStatus.initializingCamera;
  bool _isSmartScanEnabled = true;

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
    _seriesController.dispose();
    _releaseDateController.dispose();
    _originController.dispose();
    _avgPriceController.dispose();
    _pinNameController.dispose();
    super.dispose();
  }

  void _resetScannerState() {
     setState(() {
      _currentXFile = null;
      _suggestedImageUrls = [];
      _errorMessage = null;
      _selectedHiResImageUrl = null;
      _pinNameController.clear();
      _seriesController.clear();
      _releaseDateController.clear();
      _originController.clear();
      _avgPriceController.clear();
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
      setState(() { _currentXFile = imageXFile; _status = ScannerProcessStatus.imageSelected; });
      final Uint8List imageBytes = await imageXFile.readAsBytes();
      if (_isSmartScanEnabled) {
        _processImageWithAI(imageBytes, imageXFile.name);
      } else {
        setState(() { _status = ScannerProcessStatus.manualEntry; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to capture image: $e'; _status = ScannerProcessStatus.error; });
    }
  }

  Future<void> _pickImageUsingPicker(ImageSource source) async {
    setState(() { /* Clear previous state */ _currentXFile = null; _suggestedImageUrls = []; _errorMessage = null; _selectedHiResImageUrl = null; _pinNameController.clear(); _seriesController.clear(); _releaseDateController.clear(); _originController.clear(); _avgPriceController.clear(); });
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1000);
      if (pickedFile != null) {
        setState(() { _currentXFile = pickedFile; _status = ScannerProcessStatus.imageSelected; });
        final Uint8List imageBytes = await pickedFile.readAsBytes();
        if (_isSmartScanEnabled) {
          _processImageWithAI(imageBytes, pickedFile.name);
        } else {
          setState(() { _status = ScannerProcessStatus.manualEntry; });
        }
      } else { _resetScannerState(); }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to pick image: $e'; _status = ScannerProcessStatus.error; });
    }
  }

  // --- Updated AI Processing Logic ---
  Future<void> _processImageWithAI(Uint8List imageBytes, String originalFileName) async {
    if (_currentXFile == null) return; 
    setState(() { _status = ScannerProcessStatus.processingAI; _errorMessage = null; _suggestedImageUrls = []; });

    final base64Image = base64Encode(imageBytes);
    print('Smart Scan: Sending image (filename: $originalFileName) to backend function...');

    // *** USE THE URL YOU PROVIDED ***
    const String edgeFunctionUrl = 'https://syjgwmubhnhwrrxqphpw.supabase.co/functions/v1/process-pin-image';
    // *** ----------------------- ***

    // This check is now less critical if you've hardcoded the URL above, but good for safety.
    if (edgeFunctionUrl.startsWith('YOUR_DEPLOYED')) {
        print("ERROR: Edge function URL not set in scanner_page.dart (Still using placeholder).");
        if (mounted) {
            setState(() {
                _errorMessage = "Scanner service is not configured. Please contact support.";
                _status = ScannerProcessStatus.error;
            });
        }
        return;
    }

    final headers = {
      'Content-Type': 'application/json',
      // If your Edge Function requires Supabase Auth JWT for protection:
      // (Make sure your Edge Function is set to enforce JWT in Supabase dashboard if you use this)
      // 'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
    };

    try {
      final response = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: headers,
        body: jsonEncode({'imageData': base64Image}),
      );

      print('Backend response status: ${response.statusCode}');
      // print('Backend response body for debugging: ${response.body}'); 

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? urls = data['suggestedUrls'];
        final String? identifiedName = data['identifiedName'];
        // final List<dynamic>? labels = data['labels']; // You can use these too

        if (mounted) {
          setState(() {
            if (identifiedName != null) _pinNameController.text = identifiedName;
            _suggestedImageUrls = (urls != null && urls.isNotEmpty) ? List<String>.from(urls) : [];
            _status = ScannerProcessStatus.showingSuggestions;
          });
          _lookupPinFacts(_pinNameController.text); // Trigger fact lookup
        }
      } else {
        // Try to parse error from backend if available
        String serverError = response.body;
        try {
          final errorData = jsonDecode(response.body);
          serverError = errorData['error'] ?? response.body;
        } catch (_) {
          // Keep original body if not JSON
        }
        print('Edge Function error: $serverError');
        if (mounted) {
          setState(() {
            _errorMessage = 'Image processing failed: $serverError';
            _status = ScannerProcessStatus.error;
          });
        }
      }
    } catch (e) {
      print('Error calling Edge Function: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not connect to scanner service: $e';
          _status = ScannerProcessStatus.error;
        });
      }
    }
  }

  Future<void> _lookupPinFacts(String pinIdentifier) async { /* ... same placeholder ... */ }
  Future<void> _removeBackground() async { /* ... same placeholder ... */ }
  void _savePin() async { /* ... same placeholder ... */ }

  @override
  Widget build(BuildContext context) { /* ... UI remains the same ... */
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Smart Scan'),
                Switch(
                  value: _isSmartScanEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isSmartScanEnabled = value;
                      if (_currentXFile != null) {
                        if (_isSmartScanEnabled) {
                          _currentXFile!.readAsBytes().then((bytes) => _processImageWithAI(bytes, _currentXFile!.name));
                        } else {
                           _status = ScannerProcessStatus.manualEntry;
                           _suggestedImageUrls = [];
                           _selectedHiResImageUrl = null;
                        }
                      } else if ((_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera) && !_isSmartScanEnabled){
                        } else if ((_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera) && _isSmartScanEnabled){
                        }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                alignment: Alignment.center,
                child: _buildPreviewContent(),
              ),
            ),
            const SizedBox(height: 10),
            if (_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions && _suggestedImageUrls.isNotEmpty)
              _buildSuggestionsSection(),
            if (!_isSmartScanEnabled && (_status == ScannerProcessStatus.manualEntry || _status == ScannerProcessStatus.imageSelected) && _currentXFile != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: OutlinedButton.icon( icon: const Icon(Icons.auto_fix_high), label: const Text('Remove Background (White)'), onPressed: _removeBackground,),
              ),
            if (_status == ScannerProcessStatus.showingSuggestions || _status == ScannerProcessStatus.manualEntry)
              Expanded(
                flex: 2,
                child: SingleChildScrollView(child: _buildPinDetailsForm()),
              ),
            if (_status == ScannerProcessStatus.error && _errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 10),
            _buildActionButtons(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() { /* ... UI remains the same ... */
     switch (_status) {
      case ScannerProcessStatus.initializingCamera:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Initializing Camera...", style: TextStyle(color: Colors.white))]);
      case ScannerProcessStatus.noCamera:
        return Text(_errorMessage ?? "No camera found or permission denied.", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center,);
      case ScannerProcessStatus.cameraPreview:
        if (kIsWeb) {
             return const Text("Use 'Capture' or 'Gallery' buttons.", style: TextStyle(color: Colors.white));
        }
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          return FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CameraPreview(_cameraController!)
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        }
        return const Text("Preparing camera...", style: TextStyle(color: Colors.white));
      case ScannerProcessStatus.processingAI:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Smart Scan processing...")]);
      case ScannerProcessStatus.saving:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Saving pin...")]);
      case ScannerProcessStatus.imageSelected:
      case ScannerProcessStatus.showingSuggestions:
      case ScannerProcessStatus.manualEntry:
      case ScannerProcessStatus.error:
        if (_currentXFile != null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Your Image:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: kIsWeb ? Image.network(_currentXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")))
                                : Image.file(File(_currentXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image"))),
                ),
              ),
              if (_status == ScannerProcessStatus.showingSuggestions && _suggestedImageUrls.isEmpty && _errorMessage == null)
                 const Padding(padding: EdgeInsets.only(top: 8.0), child: Text("No high-res suggestions found.")),
            ],
          );
        }
        return const Text('Tap Capture or Gallery.', style: TextStyle(color: Colors.black));
    }
  }

  Widget _buildSuggestionsSection() { /* ... UI remains the same ... */
    if (!(_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions && _suggestedImageUrls.isNotEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Suggested High-Res Images:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedImageUrls.length,
            itemBuilder: (context, index) {
              final url = _suggestedImageUrls[index];
              bool isSelected = url == _selectedHiResImageUrl;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () { setState(() { _selectedHiResImageUrl = url; }); },
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isSelected ? 5 : 8),
                      child: Image.network(url, fit: BoxFit.cover,
                        loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorBuilder: (c,e,s) => Container(width: 100, height: 100, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPinDetailsForm() { /* ... UI remains the same ... */
    if (!(_status == ScannerProcessStatus.showingSuggestions || _status == ScannerProcessStatus.manualEntry)) {
        return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(controller: _pinNameController, decoration: const InputDecoration(labelText: 'Pin Name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextFormField(controller: _seriesController, decoration: const InputDecoration(labelText: 'Series', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextFormField(controller: _releaseDateController, decoration: const InputDecoration(labelText: 'Release Date', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextFormField(controller: _originController, decoration: const InputDecoration(labelText: 'Origin (e.g., Park, Event)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextFormField(controller: _avgPriceController, decoration: const InputDecoration(labelText: 'Average Selling Price (Optional)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildActionButtons() { /* ... UI remains the same ... */
    final bool processingOrSaving = _status == ScannerProcessStatus.processingAI ||
                                  _status == ScannerProcessStatus.initializingCamera ||
                                  _status == ScannerProcessStatus.saving;

    if (_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera || _status == ScannerProcessStatus.initializingCamera) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              label: const Text('Capture'),
              onPressed: processingOrSaving || (_status == ScannerProcessStatus.noCamera && !kIsWeb && _cameraController == null) ? null : _captureWithCamera,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: processingOrSaving ? null : () => _pickImageUsingPicker(ImageSource.gallery),
            ),
          ),
        ],
      );
    } else if (_status == ScannerProcessStatus.showingSuggestions || _status == ScannerProcessStatus.manualEntry || _status == ScannerProcessStatus.imageSelected || _status == ScannerProcessStatus.error) {
       return Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ if (_status == ScannerProcessStatus.showingSuggestions || _status == ScannerProcessStatus.manualEntry) ElevatedButton.icon( icon: const Icon(Icons.save_alt_outlined), label: const Text('Save Pin to Collection'), onPressed: processingOrSaving ? null : _savePin, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), ), const SizedBox(height: 10), OutlinedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Scan/Upload New Pin'), onPressed: processingOrSaving ? null : _resetScannerState, ), ], );
    }
    return Container();
  }
}
