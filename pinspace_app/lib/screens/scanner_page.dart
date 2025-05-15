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
// import 'package:http_parser/http_parser.dart'; // Uncomment if you need MediaType for MultipartFile

// Get a reference to the Supabase client instance (if not already global in main.dart)
final supabase = Supabase.instance.client;

// --- CONFIGURATION ---
const String pythonApiUrl = 'https://colejunck1.pythonanywhere.com/remove-background';
// Supabase Edge Function URL - Not used in this version, but kept for future AI details lookup
// const String supabaseEdgeFunctionUrl = 'https://syjgwmubhnhwrrxqphpw.supabase.co/functions/v1/process-pin-image';


// Define states for the scanner page
enum ScannerProcessStatus {
  initializingCamera,
  cameraPreview,
  imageSelected, // Original image selected, pre-Python API call
  processingPythonAPI, // Calling PythonAnywhere
  manualEntry, // Image processed (from Python API), ready for details
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
  Uint8List? _processedImageBytes; // Bytes of the image after Python API processing (WebP)

  // Controllers for the remaining fields
  final _pinNameController = TextEditingController();
  final _seriesController = TextEditingController();
  // Removed: _releaseDateController, _originController, _avgPriceController

  String? _errorMessage;
  ScannerProcessStatus _status = ScannerProcessStatus.initializingCamera;
  // Removed: _isSmartScanEnabled 

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
    _pinNameController.dispose();
    _seriesController.dispose();
    // Removed: _releaseDateController.dispose();
    // Removed: _originController.dispose();
    // Removed: _avgPriceController.dispose();
    super.dispose();
  }

  void _resetScannerState() {
    setState(() {
      _originalXFile = null;
      _originalImageBytes = null;
      _processedImageBytes = null;
      _errorMessage = null;
      _pinNameController.clear();
      _seriesController.clear();
      // Removed clearing for other controllers
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
      _status = ScannerProcessStatus.imageSelected; // Temporarily to show original
      _errorMessage = null;
    });

    _originalImageBytes = await imageFile.readAsBytes();
    String fileName = imageFile.name;

    // Always call Python API now
    final processedBytesFromPython = await _callPythonAnywhereAPI(_originalImageBytes!, fileName);
    
    if (mounted) {
        if (processedBytesFromPython != null) {
            setState(() {
                _processedImageBytes = processedBytesFromPython;
                _status = ScannerProcessStatus.manualEntry; // Go to manual entry with processed image
            });
            // If you re-introduce AI for details lookup later, call it here:
            // String processedFileName = fileName.contains('.')
            //     ? '${fileName.substring(0, fileName.lastIndexOf('.'))}_processed.webp'
            //     : '${fileName}_processed.webp';
            // await _callSomeAIDetailsLookup(_processedImageBytes!, processedFileName);
        } else {
            // Error state already set by _callPythonAnywhereAPI
            print("Python API call failed. Staying in error state or showing original.");
            // If _callPythonAnywhereAPI sets status to error, it will be handled by build.
            // If it returns null but doesn't set error (should not happen), ensure UI reflects it.
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
      _seriesController.clear();
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

  // Placeholder for future AI details lookup
  // Future<void> _callSomeAIDetailsLookup(Uint8List imageBytes, String fileName) async {
  //   print("Future AI: Looking up details for $fileName");
  //   // This is where you'd call another service (e.g., a different Supabase function or Google Cloud Vision for object/text detection)
  // }

  Future<void> _lookupPinFacts(String pinIdentifier) async { /* ... same placeholder ... */ }
  
  void _savePin() async { /* ... same placeholder ... */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Pin")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Removed the "Smart Scan" Switch
            const SizedBox(height: 10), // Keep some spacing
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
            
            // The "Process Image" button is no longer needed as it's automatic
            
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
    );
  }

  Widget _buildPreviewContent() {
    // print("BUILD_PREVIEW: Status: $_status, OriginalBytes: ${_originalImageBytes?.length}, ProcessedBytes: ${_processedImageBytes?.length}");
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

      case ScannerProcessStatus.imageSelected: // Shows original before Python API call starts
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
        TextFormField(controller: _pinNameController, decoration: const InputDecoration(labelText: 'Pin Name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextFormField(controller: _seriesController, decoration: const InputDecoration(labelText: 'Series', border: OutlineInputBorder())),
        // Removed: Release Date, Origin, Avg Price
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
               _status == ScannerProcessStatus.imageSelected || // User might want to reset even if original is just shown
               _status == ScannerProcessStatus.error) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                if (_status == ScannerProcessStatus.manualEntry && _processedImageBytes != null)
                    ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Pin to Collection'),
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
