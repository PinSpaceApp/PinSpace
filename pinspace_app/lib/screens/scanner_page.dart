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
const String supabaseEdgeFunctionUrl = 'https://syjgwmubhnhwrrxqphpw.supabase.co/functions/v1/process-pin-image';


// Define states for the scanner page
enum ScannerProcessStatus {
  initializingCamera,
  cameraPreview,
  imageSelected, // Original image selected, pre-Python API call
  processingPythonAPI, // Calling PythonAnywhere
  pythonAPIProcessed, // Image back from Python, pre-Supabase call
  processingSupabaseAI, // Calling Supabase Edge Function (Cloud Vision etc.)
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

  XFile? _originalXFile; // Stores the originally picked/captured file info
  Uint8List? _originalImageBytes; // Raw bytes of the original image
  Uint8List? _processedImageBytes; // Bytes of the image after Python API processing (WebP)

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
      _originalXFile = null;
      _originalImageBytes = null;
      _processedImageBytes = null;
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
        _initializeCamera(); // Re-initialize if needed
      } else {
        _status = ScannerProcessStatus.noCamera;
        _errorMessage = "Use buttons to scan or upload.";
      }
    });
  }

  Future<Uint8List?> _callPythonAnywhereAPI(Uint8List imageBytes, String fileName) async {
    setState(() { _status = ScannerProcessStatus.processingPythonAPI; _errorMessage = null; });
    print('Calling PythonAnywhere API ($pythonApiUrl) for background removal...');

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
      print('PythonAPI response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final processedBytes = await response.stream.toBytes();
        print('PythonAPI processing successful. Received ${processedBytes.length} bytes (expected WebP).');
        if (!mounted) return null;
        setState(() {
          _processedImageBytes = processedBytes;
          _status = ScannerProcessStatus.pythonAPIProcessed;
        });
        return processedBytes;
      } else {
        final errorBody = await response.stream.bytesToString();
        print('PythonAPI error ($pythonApiUrl): $errorBody');
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
            _errorMessage = 'PythonAPI processing failed: $displayError';
            _status = ScannerProcessStatus.error;
          });
        }
        return null;
      }
    } catch (e) {
      print('Error calling PythonAnywhere API ($pythonApiUrl): $e');
      if (mounted) {
        setState(() {
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
      _suggestedImageUrls = [];
    });

    _originalImageBytes = await imageFile.readAsBytes();
    String fileName = imageFile.name; 

    final processedBytesFromPython = await _callPythonAnywhereAPI(_originalImageBytes!, fileName);

    if (processedBytesFromPython != null) {
      if (_isSmartScanEnabled) {
        String processedFileName = fileName.contains('.')
            ? '${fileName.substring(0, fileName.lastIndexOf('.'))}_processed.webp'
            : '${fileName}_processed.webp';
        await _callSupabaseAI(processedBytesFromPython, processedFileName);
      } else {
        if (mounted) {
          setState(() { _status = ScannerProcessStatus.manualEntry; });
        }
      }
    } else {
      print("Failed to get processed image from PythonAPI.");
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
      _suggestedImageUrls = [];
      _errorMessage = null;
      _selectedHiResImageUrl = null;
      _pinNameController.clear();
      _seriesController.clear();
      _releaseDateController.clear();
      _originController.clear();
      _avgPriceController.clear();
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

  Future<void> _callSupabaseAI(Uint8List processedImageBytes, String processedFileName) async {
    setState(() { _status = ScannerProcessStatus.processingSupabaseAI; _errorMessage = null; });

    final base64Image = base64Encode(processedImageBytes);
    print('Smart Scan: Sending PROCESSED image (filename: $processedFileName, type: image/webp) to Supabase Edge function...');

    if (supabaseEdgeFunctionUrl.startsWith('YOUR_DEPLOYED')) {
        print("ERROR: Supabase Edge function URL not set.");
        if (mounted) {
            setState(() {
                _errorMessage = "Scanner service (Supabase) is not configured.";
                _status = ScannerProcessStatus.error;
            });
        }
        return;
    }

    final headers = {
      'Content-Type': 'application/json',
      // 'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
    };

    try {
      final response = await http.post(
        Uri.parse(supabaseEdgeFunctionUrl),
        headers: headers,
        body: jsonEncode({'imageData': base64Image, 'imageMimeType': 'image/webp'}),
      );

      print('Supabase Edge Function response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic>? urls = data['suggestedUrls'];
        final String? identifiedName = data['identifiedName'];

        if (mounted) {
          setState(() {
            if (identifiedName != null) _pinNameController.text = identifiedName;
            _suggestedImageUrls = (urls != null && urls.isNotEmpty) ? List<String>.from(urls) : [];
            _status = ScannerProcessStatus.showingSuggestions;
          });
          _lookupPinFacts(_pinNameController.text);
        }
      } else {
        String serverError = response.body;
        try {
          final errorData = jsonDecode(response.body);
          serverError = errorData['error'] ?? response.body;
        } catch (_) { /* Keep original body if not JSON */ }
        print('Supabase Edge Function error: $serverError');
        if (mounted) {
          setState(() {
            _errorMessage = 'Cloud Vision processing failed: $serverError';
            _status = ScannerProcessStatus.error;
          });
        }
      }
    } catch (e) {
      print('Error calling Supabase Edge Function: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not connect to Cloud Vision service: $e';
          _status = ScannerProcessStatus.error;
        });
      }
    }
  }

  Future<void> _lookupPinFacts(String pinIdentifier) async { /* ... same placeholder ... */ }

  Future<void> _processManually() async {
      if (_originalImageBytes == null) {
          setState(() { _errorMessage = "No image selected to process."; _status = ScannerProcessStatus.error; });
          return;
      }
      final processedBytes = await _callPythonAnywhereAPI(_originalImageBytes!, _originalXFile?.name ?? "manual_scan.png");
      if (processedBytes != null) {
          if (mounted) {
              setState(() {
                  _processedImageBytes = processedBytes;
                  _status = ScannerProcessStatus.manualEntry;
              });
          }
      }
  }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Smart Scan'),
                Switch(
                  value: _isSmartScanEnabled,
                  onChanged: (value) async {
                    bool previousSmartScanState = _isSmartScanEnabled;
                    setState(() { _isSmartScanEnabled = value; });

                    if (_originalImageBytes != null) { 
                        if (_isSmartScanEnabled && !previousSmartScanState) { 
                            if (_processedImageBytes != null && _status == ScannerProcessStatus.manualEntry) {
                                await _callSupabaseAI(_processedImageBytes!, "processed_${_originalXFile?.name ?? "image.webp"}");
                            } else { 
                                final processedBytes = await _callPythonAnywhereAPI(_originalImageBytes!, _originalXFile?.name ?? "image.png");
                                if (processedBytes != null) {
                                    await _callSupabaseAI(processedBytes, "processed_${_originalXFile?.name ?? "image.webp"}");
                                }
                            }
                        } else if (!_isSmartScanEnabled && previousSmartScanState) { 
                            if (_status == ScannerProcessStatus.showingSuggestions || _status == ScannerProcessStatus.processingSupabaseAI) {
                                setState(() { _status = ScannerProcessStatus.manualEntry; });
                            }
                            else if (_status == ScannerProcessStatus.pythonAPIProcessed) {
                                setState(() { _status = ScannerProcessStatus.manualEntry; });
                            }
                        }
                    }
                  },
                ),
              ],
            ),
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
            if (_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions && _suggestedImageUrls.isNotEmpty)
              _buildSuggestionsSection(),
            
            if (!_isSmartScanEnabled && _status == ScannerProcessStatus.imageSelected && _originalImageBytes != null)
                 Padding( 
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Process Image (Remove BG & Enhance)'),
                        onPressed: _processManually,
                    ),
                ),
            if (!_isSmartScanEnabled && (_status == ScannerProcessStatus.manualEntry || _status == ScannerProcessStatus.pythonAPIProcessed) && _processedImageBytes != null)
              Padding( 
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Image processed. Fill details below.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),

            if ((_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions) || 
                (!_isSmartScanEnabled && _status == ScannerProcessStatus.manualEntry && _processedImageBytes != null))
              Expanded(
                flex: 2,
                child: SingleChildScrollView(child: _buildPinDetailsForm()),
              ),
            if (_status == ScannerProcessStatus.error && _errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                // CORRECTED LINE: textAlign is a parameter of Text, not TextStyle
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
                    ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")))
                    : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")))
              )),
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text("Removing background & enhancing..."),
            ],
          );
        }
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Removing background & enhancing...")]);
      
      case ScannerProcessStatus.processingSupabaseAI:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_processedImageBytes != null) 
              Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: Image.memory(_processedImageBytes!, fit: BoxFit.contain))),
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text("Identifying pin with Cloud Vision..."),
          ],
        );
      case ScannerProcessStatus.saving:
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Saving pin...")]);

      case ScannerProcessStatus.imageSelected:
        if (_originalXFile != null) {
          return kIsWeb
              ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")))
              : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying image")));
        }
        return const Text('Tap Capture or Gallery.');

      case ScannerProcessStatus.pythonAPIProcessed:
      case ScannerProcessStatus.showingSuggestions:
      case ScannerProcessStatus.manualEntry:
      case ScannerProcessStatus.error:
        if (_processedImageBytes != null) {
          return Image.memory(_processedImageBytes!, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying processed image")));
        } else if (_originalXFile != null) { 
           return kIsWeb
              ? Image.network(_originalXFile!.path, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying original image")))
              : Image.file(File(_originalXFile!.path), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Error displaying original image")));
        }
        return const Text('No image to display. Tap Capture or Gallery.');
      default:
        return const Text('Please capture or select an image.');
    }
  }

  Widget _buildSuggestionsSection() {
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

  Widget _buildPinDetailsForm() {
    if (!((_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions) || 
          (!_isSmartScanEnabled && _status == ScannerProcessStatus.manualEntry && _processedImageBytes != null))) {
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

  Widget _buildActionButtons() {
    final bool isProcessingAnyAPI = _status == ScannerProcessStatus.processingPythonAPI ||
                                  _status == ScannerProcessStatus.processingSupabaseAI ||
                                  _status == ScannerProcessStatus.initializingCamera ||
                                  _status == ScannerProcessStatus.saving;

    if (_status == ScannerProcessStatus.cameraPreview || _status == ScannerProcessStatus.noCamera || _status == ScannerProcessStatus.initializingCamera) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture'),
              onPressed: isProcessingAnyAPI || (_status == ScannerProcessStatus.noCamera && !kIsWeb && _cameraController == null) ? null : _captureWithCamera,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: isProcessingAnyAPI ? null : () => _pickImageUsingPicker(ImageSource.gallery),
            ),
          ),
        ],
      );
    } else if (_status == ScannerProcessStatus.showingSuggestions ||
               _status == ScannerProcessStatus.manualEntry ||
               _status == ScannerProcessStatus.pythonAPIProcessed ||
               _status == ScannerProcessStatus.imageSelected || 
               _status == ScannerProcessStatus.error) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                if ((_isSmartScanEnabled && _status == ScannerProcessStatus.showingSuggestions) || 
                    (!_isSmartScanEnabled && _status == ScannerProcessStatus.manualEntry && _processedImageBytes != null))
                    ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Pin to Collection'),
                        onPressed: isProcessingAnyAPI ? null : _savePin,
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                    ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan/Upload New Pin'),
                    onPressed: isProcessingAnyAPI ? null : _resetScannerState,
                ),
            ],
        );
    }
    return Container(); 
  }
}
