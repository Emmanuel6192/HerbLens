import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/classifier.dart';
import '../services/image_processor.dart';
import 'camera_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HerbClassifier _classifier = HerbClassifier();
  bool _isModelLoading = true;
  bool _modelLoadFailed = false;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _classifier.loadModel();
    if (mounted) {
      setState(() {
        _isModelLoading = false;
        _modelLoadFailed = !_classifier.isLoaded;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final status = await Permission.photos.request();
    if (!status.isGranted && mounted) {
      _showPermissionDenied('Photo Library');
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;

    // Let the user crop to the herb before running inference
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop to the herb',
          toolbarColor: const Color(0xFF2D5A27),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF7BC67A),
          backgroundColor: const Color(0xFF0D1F0A),
          dimmedLayerColor: Colors.black87,
          cropGridColor: const Color(0xFF7BC67A),
          cropFrameColor: const Color(0xFF7BC67A),
          statusBarLight: false,
          navBarLight: false,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped != null) await _analyzeImage(cropped.path, fromGallery: false);
  }

  Future<void> _openCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      _showPermissionDenied('Camera');
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result != null) await _analyzeImage(result, fromGallery: false);
  }

  Future<void> _analyzeImage(String imagePath, {required bool fromGallery}) async {
    setState(() => _isAnalyzing = true);

    try {
      final Uint8List rawBytes = await ImageProcessor.loadImageBytes(imagePath);
      final result = await _classifier.classify(rawBytes);

      if (mounted) {
        setState(() => _isAnalyzing = false);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imagePath: imagePath,
              result: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  void _showPermissionDenied(String permission) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A3317),
        title: Text('$permission Access Required',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'Please grant $permission access in your device settings to use this feature.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Color(0xFF7BC67A))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F0A),
      body: Stack(
        children: [
          // Background botanical pattern
          _buildBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Analyzing overlay
          if (_isAnalyzing) _buildAnalyzingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: CustomPaint(painter: _LeafPatternPainter()),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5A27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF7BC67A).withOpacity(0.4),
              ),
            ),
            child: const Icon(Icons.eco_rounded,
                color: Color(0xFF7BC67A), size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HerbLens',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _isModelLoading
                    ? 'Loading AI model...'
                    : _modelLoadFailed
                        ? 'Model unavailable'
                        : 'AI Herb Identifier',
                style: TextStyle(
                  fontSize: 11,
                  color: _modelLoadFailed
                      ? Colors.red[300]!.withOpacity(0.9)
                      : const Color(0xFF7BC67A).withOpacity(0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_isModelLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7BC67A),
              ),
            )
          else if (_modelLoadFailed)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isModelLoading = true;
                  _modelLoadFailed = false;
                });
                _loadModel();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: Colors.red[300]),
                    const SizedBox(width: 5),
                    Text('Model Error · Retry',
                        style: TextStyle(fontSize: 11, color: Colors.red[300])),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7BC67A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF7BC67A).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 6, color: Color(0xFF7BC67A)),
                  SizedBox(width: 5),
                  Text('Ready',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF7BC67A))),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.2, end: 0, duration: 600.ms);
  }

  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Central scanning illustration
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2D5A27).withOpacity(0.6),
                  const Color(0xFF0D1F0A).withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF7BC67A).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7BC67A).withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7BC67A).withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                // Icon
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_florist_rounded,
                      size: 72,
                      color: const Color(0xFF7BC67A).withOpacity(0.9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Point & Identify',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 3000.ms,
                color: const Color(0xFF7BC67A).withOpacity(0.1),
              ),

          const SizedBox(height: 48),

          Text(
            'Identify Local Herbs\nInstantly',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 16),

          Text(
            'Images should be close up and cropped centrally \nfor best results .',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.5),
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Primary CTA - Camera
          GestureDetector(
            onTap: (_isModelLoading || _modelLoadFailed) ? null : _openCamera,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (_isModelLoading || _modelLoadFailed)
                      ? [Colors.grey[800]!, Colors.grey[700]!]
                      : [const Color(0xFF3D7A36), const Color(0xFF2D5A27)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: (_isModelLoading || _modelLoadFailed)
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF3D7A36).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Take a Photo',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: 14),

          // Secondary - Gallery
          GestureDetector(
            onTap: (_isModelLoading || _modelLoadFailed) ? null : _pickFromGallery,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_rounded,
                      color: Colors.white.withOpacity(0.7), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Upload from Gallery',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7BC67A).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7BC67A),
                  strokeWidth: 3,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                  begin: 1.0,
                  end: 1.1,
                  duration: 1000.ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(begin: 1.1, end: 1.0, duration: 1000.ms),
            const SizedBox(height: 32),
            Text(
              'Analyzing Herb...',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Running AI inference',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for subtle leaf pattern background
class _LeafPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2D5A27).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Draw subtle dot grid
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }

    // Glow at bottom
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 1.2),
        radius: 0.7,
        colors: [
          const Color(0xFF2D5A27).withOpacity(0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
