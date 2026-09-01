import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
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
  static const int _requiredStability = 2; // Reduced slightly for better feel when scanning two things

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Lower resolution for faster real-time processing
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      // Optimize camera settings
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);

      setState(() => _isCameraInitialized = true);
      _startImageStream();
    } catch (e) {
      debugPrint('Camera initialization error: $e');
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

    // For Paybill, we ideally want BOTH numbers. If only one is found, we keep looking.
    if (widget.serviceType == 'Pay Bill') {
      bool hasPaybill = extractedData.containsKey('number');
      bool hasAccount = extractedData.containsKey('account');
      
      if (!hasPaybill && !hasAccount) {
        _stabilityCount = 0;
        return;
      }
    }

    // Check if the current detection matches the last one
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
      // Logic for "Pay Bill": If we have both, proceed. If we only have Paybill for a long time, proceed anyway.
      if (widget.serviceType == 'Pay Bill') {
        if (extractedData.containsKey('number') && extractedData.containsKey('account')) {
          HapticFeedback.heavyImpact();
          _onDataConfirmed(extractedData);
        } else if (_stabilityCount > 8 && extractedData.containsKey('number')) {
          // Fallback: we found the paybill but couldn't find the account after 8 stable frames
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
    
    // 1. Clean the text but keep context (letters, digits, colon, slash)
    String cleanText = upperText.replaceAll(RegExp(r'[^A-Z0-9\s:/]'), ' ');
    final List<String> lines = cleanText.split('\n').map((l) => l.trim()).toList();
    
    // helper to find number near a label
    String? findValueAfter(String line, List<String> labels, {bool onlyDigits = false, int minLen = 4}) {
      for (var label in labels) {
        if (line.contains(label)) {
          // Look for the first alphanumeric block after the label in the same line
          // e.g. "ACC: 12345" or "ACCOUNT NO 12345"
          String afterLabel = line.substring(line.indexOf(label) + label.length);
          // Remove noise like "NO", "NUMBER", "#", ":", "/"
          String valuesOnly = afterLabel.replaceAll(RegExp(r'(?:NO|NUMBER|#|:|/)'), ' ').trim();
          List<String> parts = valuesOnly.split(RegExp(r'\s+'));
          for (var p in parts) {
            if (p.length >= minLen) {
              if (onlyDigits) {
                String digits = p.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length >= minLen) return digits;
              } else {
                // Ensure it's not a noise word
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

    // Final Fallback: If no labels found, look for raw numeric sequences
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
    _controller?.stopImageStream();

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
      _startImageStream();
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    InputImageRotation? rotation;
    if (Platform.isAndroid) {
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
    } else if (Platform.isIOS) {
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
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
    _isFlashOn = !_isFlashOn;
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
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
    // Look for numbers in the speech
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
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
              foundBoth 
                ? 'Paybill & Account Found!' 
                : 'Scanning for payment numbers...',
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
              // Manual scan trigger
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
