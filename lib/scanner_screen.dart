import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
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

  // For stabilization
  String _lastDetectedNumber = '';
  int _stabilityCount = 0;
  static const int _requiredStability = 3;

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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

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
    String extracted = _extractNumber(text);
    if (extracted.isEmpty) {
      _stabilityCount = 0;
      return;
    }

    if (extracted == _lastDetectedNumber) {
      _stabilityCount++;
    } else {
      _lastDetectedNumber = extracted;
      _stabilityCount = 1;
    }

    if (_stabilityCount >= _requiredStability) {
      _onNumberConfirmed(extracted);
    }
  }

  String _extractNumber(String text) {
    // Keep numbers and whitespace only to avoid losing digits like 55
    String cleanText = text.replaceAll(RegExp(r'[^0-9\s]'), ' ');
    List<String> words = cleanText.split(RegExp(r'\s+'));

    for (String word in words) {
      if (word.isEmpty) continue;

      if (widget.serviceType == 'Pochi la Biashara') {
        if (word.length >= 10 && (word.startsWith('07') || word.startsWith('01') || word.startsWith('254'))) {
          return word;
        }
      } else {
        // Agent/Till/Paybill usually 5-8 digits
        if (word.length >= 5 && word.length <= 8) {
          return word;
        }
      }
    }
    return '';
  }

  void _onNumberConfirmed(String number) {
    if (!mounted) return;
    _controller?.stopImageStream();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmScreen(
          serviceType: widget.serviceType,
          scannedNumber: number,
        ),
      ),
    ).then((_) {
      // Resume streaming when coming back
      _stabilityCount = 0;
      _lastDetectedNumber = '';
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
    String extracted = _extractNumber(recognizedText.text);

    if (extracted.isNotEmpty) {
      _onNumberConfirmed(extracted);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid number found in image')),
        );
      }
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
    return Column(
      children: [
        Container(
          width: 250,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00A86B), width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Align number within the box',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(
            icon: Icons.photo_library,
            onTap: _pickFromGallery,
            label: 'Gallery',
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

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
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
