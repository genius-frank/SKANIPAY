import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'confirm_screen.dart';

class ScannerScreen extends StatefulWidget {
  final String serviceType;
  const ScannerScreen({super.key, required this.serviceType});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _scanImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) return;

      setState(() => _isProcessing = true);

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);

      String extractedNumber = '';

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String cleaned = line.text.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleaned.length >= 4) {
            extractedNumber = cleaned;
            break;
          }
        }
        if (extractedNumber.isNotEmpty) break;
      }

      setState(() => _isProcessing = false);

      if (extractedNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No number found. Please try again with better lighting.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmScreen(
              serviceType: widget.serviceType,
              scannedNumber: extractedNumber,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A86B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.serviceType,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.document_scanner,
                size: 120,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              const Text(
                'Point your camera at the number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Make sure the number is clearly visible and well lit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 60),
              _isProcessing
                  ? const Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Reading number...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
                  : GestureDetector(
                onTap: _scanImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        color: Color(0xFF00A86B),
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Tap to Scan Number',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A86B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}