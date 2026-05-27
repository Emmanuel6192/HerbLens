import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashOn = false;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _startCamera(_cameras[_cameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile photo = await _controller!.takePicture();
      final croppedPath = await _cropToOverlay(photo.path);
      if (mounted) Navigator.pop(context, croppedPath);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Crops the captured photo so only what was inside the 260×260 overlay
  /// square is returned. The overlay is centred on the screen.
  Future<String> _cropToOverlay(String sourcePath) async {
    // ── 1. Read the raw image from disk ────────────────────────────────────
    final rawBytes = await File(sourcePath).readAsBytes();
    final original = img.decodeImage(rawBytes);
    if (original == null) return sourcePath; // fallback: return as-is

    // ── 2. Map the overlay square → pixel coordinates in the sensor image ──
    //
    // The CameraPreview is rendered with BoxFit.cover over the full screen.
    // The sensor image may be portrait or landscape; we always work in the
    // orientation Flutter hands us (the `image` package honours EXIF).
    //
    // Screen size (logical pixels)
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Actual decoded pixel dimensions
    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();

    // The overlay is centred between the top bar and bottom bar, not the raw
    // screen centre.  Replicate the same offset calculation used in the UI.
    final topInset        = MediaQuery.of(context).padding.top;
    final bottomInset     = MediaQuery.of(context).padding.bottom;
    const topBarHeight    = 44.0 + 12.0 + 12.0;
    const bottomBarHeight = 76.0 + 24.0 + 24.0;
    final topTotal        = topInset    + topBarHeight;
    final bottomTotal     = bottomInset + bottomBarHeight;
    final logicalOffset   = (topTotal - bottomTotal) / 2; // logical px shift

    // Centre of the overlay in logical screen coordinates
    final overlayCentreX = screenW / 2;
    final overlayCentreY = screenH / 2 + logicalOffset;

    // BoxFit.cover scale
    final scale = (imgW / screenW) > (imgH / screenH)
        ? imgH / screenH
        : imgW / screenW;

    const overlayLogical = 260.0;
    final overlayPixels  = overlayLogical * scale;

    // Map logical overlay centre → sensor pixel centre
    final cx = overlayCentreX * scale;
    final cy = overlayCentreY * scale;

    // Top-left corner of the crop region
    final cropX = (cx - overlayPixels / 2).round().clamp(0, original.width  - 1);
    final cropY = (cy - overlayPixels / 2).round().clamp(0, original.height - 1);
    final cropW = overlayPixels.round().clamp(1, original.width  - cropX);
    final cropH = overlayPixels.round().clamp(1, original.height - cropY);

    // ── 3. Crop & save ─────────────────────────────────────────────────────
    final cropped = img.copyCrop(
      original,
      x: cropX, y: cropY,
      width: cropW, height: cropH,
    );

    final dir      = await getTemporaryDirectory();
    final outPath  = '${dir.path}/herb_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 92));

    debugPrint('[CameraScreen] Cropped $imgW×$imgH → $cropW×$cropH at ($cropX,$cropY)');
    return outPath;
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitialized = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    await _startCamera(_cameras[_cameraIndex]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.width * _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7BC67A)),
            ),

          // Scanning overlay
          if (_isInitialized) _buildScanOverlay(),

          // Top controls
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(child: _buildTopBar()),
          ),

          // Bottom shutter
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    // Top bar: SafeArea top padding + 12 vertical padding + 44 button height + 12 = ~68 + top inset
    // Bottom bar: bottom padding + 24 top padding + 76 shutter + 24 bottom padding
    // We push the centre point down by half the difference so it sits in the
    // middle of the live-preview area, not the middle of the whole screen.
    final topInset    = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const topBarHeight    = 44.0 + 12.0 + 12.0;   // icon + vertical padding
    const bottomBarHeight = 76.0 + 24.0 + 24.0;   // shutter + vertical padding
    final topTotal    = topInset    + topBarHeight;
    final bottomTotal = bottomInset + bottomBarHeight;
    // Shift centre: positive = move down, negative = move up
    final verticalOffset = (topTotal - bottomTotal) / 2;

    return Positioned.fill(
      child: CustomPaint(
        painter: _ScanOverlayPainter(verticalOffset: verticalOffset),
        child: Center(
          child: Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 260 + 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Frame the herb clearly',
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          ), // Transform.translate
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _circleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          _circleButton(
            icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleFlash,
            active: _flashOn,
          ),
          const SizedBox(width: 10),
          _circleButton(
            icon: Icons.flip_camera_ios_rounded,
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7BC67A).withOpacity(0.3) : Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? const Color(0xFF7BC67A) : Colors.white38,
          ),
        ),
        child: Icon(icon,
            color: active ? const Color(0xFF7BC67A) : Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          40, 24, 40, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isCapturing ? null : _capture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isCapturing ? 68 : 76,
              height: _isCapturing ? 68 : 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white38, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.white24, blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: _isCapturing
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                  : const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final double verticalOffset;
  const _ScanOverlayPainter({this.verticalOffset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const boxSize = 260.0;
    final left = (size.width  - boxSize) / 2;
    final top  = (size.height - boxSize) / 2 + verticalOffset;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, boxSize, boxSize),
          const Radius.circular(16),
        )),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


