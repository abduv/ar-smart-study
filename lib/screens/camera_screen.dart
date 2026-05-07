import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';
import 'package:ar_ai_smart_study/utils/constants.dart';
import 'package:ar_ai_smart_study/services/ocr_service.dart';
import 'package:ar_ai_smart_study/screens/processing_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      print('Camera init error: $e');
    }
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

  Future<void> _captureAndProcess() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller!.takePicture();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcessingScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Қате: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _toggleFlash() async {
    if (_controller == null) return;
    _flashOn = !_flashOn;
    await _controller!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // AR-style overlay frame
          Positioned.fill(
            child: CustomPaint(
              painter: ScanFramePainter(),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Сканерлеу',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _flashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instruction text
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Кітапты немесе дәптерді рамкаға орналастырыңыз',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _captureAndProcess,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isCapturing
                              ? [Colors.grey, Colors.grey]
                              : [AppTheme.primaryColor, AppTheme.secondaryColor],
                        ),
                      ),
                      child: _isCapturing
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(
                              Icons.camera,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AR-стиль рамка — камера экранында
class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final double left = size.width * 0.08;
    final double top = size.height * 0.22;
    final double right = size.width * 0.92;
    final double bottom = size.height * 0.72;
    final double cornerLength = 30;
    final double radius = 8;

    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top + radius), paint);
    canvas.drawLine(Offset(left + radius, top), Offset(left + cornerLength, top), paint);

    // Top-right corner
    canvas.drawLine(Offset(right, top + cornerLength), Offset(right, top + radius), paint);
    canvas.drawLine(Offset(right - radius, top), Offset(right - cornerLength, top), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom - radius), paint);
    canvas.drawLine(Offset(left + radius, bottom), Offset(left + cornerLength, bottom), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(right, bottom - cornerLength), Offset(right, bottom - radius), paint);
    canvas.drawLine(Offset(right - radius, bottom), Offset(right - cornerLength, bottom), paint);

    // Animated scan line effect (static version)
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.secondaryColor.withOpacity(0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(left, top, right, top + 2));
    canvas.drawLine(
      Offset(left + 10, (top + bottom) / 2),
      Offset(right - 10, (top + bottom) / 2),
      scanPaint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
