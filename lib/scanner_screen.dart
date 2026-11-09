import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'confirm_screen.dart';
import 'dart:io';

class ScannerScreen extends StatefulWidget {
  final String serviceType;
  const ScannerScreen({super.key, required this.serviceType});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _cameraErrorMessage;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceText = '';

  // For stabilization
  Map<String, String> _lastDetectedData = {};
  int _stabilityCount = 0;
  static const int _requiredStability = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraErrorMessage = null;
      _isCameraInitialized = false;
    });

    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage =
              'Live Camera AI OCR is optimized for the Native Android Mobile App! On Web, tap "Choose Photo from Gallery" to upload a receipt photo, or install the Android APK.';
        });
      }
      return;
    }

    try {
      // 1. Check/request camera permission on mobile
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _cameraErrorMessage =
                'Camera permission was denied. Please allow camera access in app settings to scan.';
          });
        }
        return;
      }

      // 2. Fetch available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraErrorMessage = 'No active camera found on this device.';
          });
        }
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: (!kIsWeb && Platform.isAndroid)
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      try {
        await _controller!.setFocusMode(FocusMode.auto);
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      setState(() {
        _isCameraInitialized = true;
        _cameraErrorMessage = null;
      });

      if (!kIsWeb) {
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Could not access camera: ${e.toString()}';
        });
      }
    }
  }

  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final recognizedText = await _textRecognizer.processImage(inputImage);
        _processRecognizedText(recognizedText.text);
      } catch (e) {
        debugPrint('Error processing image stream: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _processRecognizedText(String text) {
    Map<String, String> extractedData = _extractData(text);
    if (extractedData.isEmpty) {
      _stabilityCount = 0;
      return;
    }

    if (widget.serviceType == 'Pay Bill') {
      bool hasPaybill = extractedData.containsKey('number');
      bool hasAccount = extractedData.containsKey('account');

      if (!hasPaybill && !hasAccount) {
        _stabilityCount = 0;
        return;
      }
    }

    bool isSame = true;
    if (_lastDetectedData.length != extractedData.length) {
      isSame = false;
    } else {
      extractedData.forEach((key, value) {
        if (_lastDetectedData[key] != value) isSame = false;
      });
    }

    if (isSame) {
      _stabilityCount++;
    } else {
      _lastDetectedData = extractedData;
      _stabilityCount = 1;
    }

    if (_stabilityCount >= _requiredStability) {
      if (widget.serviceType == 'Pay Bill') {
        if (extractedData.containsKey('number') && extractedData.containsKey('account')) {
          HapticFeedback.heavyImpact();
          _onDataConfirmed(extractedData);
        } else if (_stabilityCount > 8 && extractedData.containsKey('number')) {
          HapticFeedback.mediumImpact();
          _onDataConfirmed(extractedData);
        }
      } else {
        HapticFeedback.heavyImpact();
        _onDataConfirmed(extractedData);
      }
    }
  }

  Map<String, String> _extractData(String text) {
    Map<String, String> result = {};
    String upperText = text.toUpperCase();

    String cleanText = upperText.replaceAll(RegExp(r'[^A-Z0-9\s:/]'), ' ');
    final List<String> lines = cleanText.split('\n').map((l) => l.trim()).toList();

    String? findValueAfter(String line, List<String> labels, {bool onlyDigits = false, int minLen = 4}) {
      for (var label in labels) {
        if (line.contains(label)) {
          String afterLabel = line.substring(line.indexOf(label) + label.length);
          String valuesOnly = afterLabel.replaceAll(RegExp(r'(?:NO|NUMBER|#|:|/)'), ' ').trim();
          List<String> parts = valuesOnly.split(RegExp(r'\s+'));
          for (var p in parts) {
            if (p.length >= minLen) {
              if (onlyDigits) {
                String digits = p.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length >= minLen) return digits;
              } else {
                if (p != 'OUNT' && p != 'OUNTNO' && p != 'ACCOUNT') return p;
              }
            }
          }
        }
      }
      return null;
    }

    if (widget.serviceType == 'Pay Bill') {
      for (String line in lines) {
        String? n = findValueAfter(line, ['PB', 'PAYBILL', 'BUSINESS', 'BIZ', 'B.NO', 'BUS'], onlyDigits: true, minLen: 5);
        if (n != null) result['number'] = n;
        String? a = findValueAfter(line, ['ACC', 'ACCOUNT', 'REF', 'REFERENCE', 'A/C'], onlyDigits: false, minLen: 4);
        if (a != null) result['account'] = a;
      }
    } else if (widget.serviceType == 'Withdraw Cash') {
      for (String line in lines) {
        String? n = findValueAfter(line, ['AGENT'], onlyDigits: true, minLen: 5);
        if (n != null) result['number'] = n;
        String? s = findValueAfter(line, ['STORE'], onlyDigits: true, minLen: 1);
        if (s != null) result['store'] = s;
      }
    } else if (widget.serviceType == 'Buy Goods & Services') {
      for (String line in lines) {
        String? n = findValueAfter(line, ['TILL', 'GOODS', 'SERVICE'], onlyDigits: true, minLen: 5);
        if (n != null) result['number'] = n;
      }
    } else if (widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara') {
      for (String line in lines) {
        String? n = findValueAfter(line, ['PHONE', 'MOBILE', 'NO', 'NUMBER', 'TO'], onlyDigits: true, minLen: 10);
        if (n != null) result['number'] = n;
      }
    }

    if (result['number'] == null) {
      List<String> words = cleanText.split(RegExp(r'\s+'));
      for (String word in words) {
        String digits = word.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) continue;

        if (widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara') {
          if (digits.length >= 10 && (digits.startsWith('07') || digits.startsWith('01') || digits.startsWith('254'))) {
            result['number'] = digits;
            break;
          }
        } else {
          if (digits.length >= 5 && digits.length <= 10) {
            result['number'] = digits;
            break;
          }
        }
      }
    }

    return result;
  }

  void _onDataConfirmed(Map<String, String> data) {
    if (!mounted) return;
    try {
      _controller?.stopImageStream();
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmScreen(
          serviceType: widget.serviceType,
          scannedNumber: data['number'] ?? '',
          scannedAccount: data['account'] ?? '',
          scannedStore: data['store'] ?? '',
        ),
      ),
    ).then((_) {
      _stabilityCount = 0;
      _lastDetectedData = {};
      if (!kIsWeb) {
        _startImageStream();
      }
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null || kIsWeb) return null;

    InputImageRotation? rotation;
    if (!kIsWeb && Platform.isAndroid) {
      var rotationValue = _controller!.value.deviceOrientation;
      switch (rotationValue) {
        case DeviceOrientation.portraitUp:
          rotation = InputImageRotation.rotation90deg;
          break;
        case DeviceOrientation.landscapeLeft:
          rotation = InputImageRotation.rotation0deg;
          break;
        case DeviceOrientation.portraitDown:
          rotation = InputImageRotation.rotation270deg;
          break;
        case DeviceOrientation.landscapeRight:
          rotation = InputImageRotation.rotation180deg;
          break;
      }
    } else if (!kIsWeb && Platform.isIOS) {
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (!kIsWeb && Platform.isAndroid && format != InputImageFormat.nv21) ||
        (!kIsWeb && Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    Map<String, String> data = _extractData(recognizedText.text);

    if (data.isNotEmpty) {
      _onDataConfirmed(data);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid number found in image')),
        );
      }
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _voiceText = val.recognizedWords;
            _processVoiceResult(_voiceText);
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _processVoiceResult(String text) {
    String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10 && (digits.startsWith('07') || digits.startsWith('01') || digits.startsWith('254'))) {
      HapticFeedback.heavyImpact();
      _speech.stop();
      setState(() => _isListening = false);
      _onDataConfirmed({'number': digits});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraErrorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.serviceType, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 72, color: Colors.white54),
                const SizedBox(height: 24),
                const Text(
                  'Camera Access Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose Photo from Gallery'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00A86B)),
              SizedBox(height: 16),
              Text('Starting camera...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Overlay
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                const Spacer(),
                _buildScannerOverlay(),
                const Spacer(),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            widget.serviceType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    bool foundBoth = widget.serviceType == 'Pay Bill' &&
        _lastDetectedData.containsKey('number') &&
        _lastDetectedData.containsKey('account');

    return Column(
      children: [
        const SizedBox(height: 24),
        if (_isListening)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF00A86B).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.mic, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                const Text('Listening for phone number...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_voiceText, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: foundBoth ? const Color(0xFF00A86B) : Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              foundBoth ? 'Paybill & Account Found!' : 'Scanning for payment numbers...',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.serviceType == 'Pay Bill' && !foundBoth)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _lastDetectedData.containsKey('number')
                    ? 'Found Paybill, looking for Account...'
                    : 'Aim at both Paybill and Account No.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ]
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleButton(
            icon: Icons.photo_library,
            onTap: _pickFromGallery,
            label: 'Gallery',
          ),
          _CircleButton(
            icon: Icons.center_focus_strong,
            onTap: () async {
              if (_isProcessing) return;
              _isProcessing = true;
              try {
                final XFile image = await _controller!.takePicture();
                final inputImage = InputImage.fromFilePath(image.path);
                final recognizedText = await _textRecognizer.processImage(inputImage);
                Map<String, String> data = _extractData(recognizedText.text);
                if (data.isNotEmpty) {
                  HapticFeedback.heavyImpact();
                  _onDataConfirmed(data);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not find a number. Try moving closer.')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Take picture error: $e');
              } finally {
                _isProcessing = false;
              }
            },
            label: 'Scan Now',
            isMain: true,
          ),
          if (widget.serviceType == 'Send Money' || widget.serviceType == 'Pochi la Biashara')
            _CircleButton(
              icon: _isListening ? Icons.mic : Icons.mic_none,
              onTap: _listen,
              label: 'Voice',
              color: _isListening ? Colors.red : Colors.white24,
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool isMain;
  final Color? color;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.isMain = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(isMain ? 20 : 16),
            decoration: BoxDecoration(
              color: color ?? (isMain ? const Color(0xFF00A86B) : Colors.white24),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isMain ? 32 : 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
