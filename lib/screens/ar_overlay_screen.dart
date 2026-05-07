import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';
import 'package:ar_ai_smart_study/models/scan_result.dart';

/// AR-стиль overlay — сурет үстіне түсіндірме шығарады
class AROverlayScreen extends StatefulWidget {
  final ScanResult result;

  const AROverlayScreen({super.key, required this.result});

  @override
  State<AROverlayScreen> createState() => _AROverlayScreenState();
}

class _AROverlayScreenState extends State<AROverlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _showOverlay = true;
  int _currentStep = 0;

  List<String> get _explanationSteps {
    // Түсіндірмені қадамдарға бөлу
    final lines = widget.result.explanation.split('\n');
    final steps = <String>[];
    final buffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('##') && buffer.isNotEmpty) {
        steps.add(buffer.toString().trim());
        buffer.clear();
      }
      buffer.writeln(line);
    }
    if (buffer.isNotEmpty) {
      steps.add(buffer.toString().trim());
    }

    return steps.isEmpty ? [widget.result.explanation] : steps;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  void _nextStep() {
    if (_currentStep < _explanationSteps.length - 1) {
      _controller.reset();
      setState(() => _currentStep++);
      _controller.forward();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _controller.reset();
      setState(() => _currentStep--);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image (full screen)
          if (widget.result.imagePath != null)
            Positioned.fill(
              child: Image.file(
                File(widget.result.imagePath!),
                fit: BoxFit.contain,
              ),
            ),

          // AR grid overlay effect
          Positioned.fill(
            child: CustomPaint(
              painter: ARGridPainter(),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.view_in_ar,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'AR режим',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showOverlay ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          setState(() => _showOverlay = !_showOverlay),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // AR Explanation overlay card
          if (_showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.secondaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step indicator
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentStep + 1}/${_explanationSteps.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Step dots
                          Row(
                            children: List.generate(
                              min(_explanationSteps.length, 6),
                              (i) => Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _currentStep
                                      ? AppTheme.secondaryColor
                                      : Colors.white30,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Explanation text
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _explanationSteps[_currentStep],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep > 0)
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_back_ios, size: 16),
                              label: const Text('Алдыңғы'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              onPressed: _prevStep,
                            )
                          else
                            const SizedBox.shrink(),
                          if (_currentStep < _explanationSteps.length - 1)
                            TextButton.icon(
                              icon: const Icon(Icons.arrow_forward_ios,
                                  size: 16),
                              label: const Text('Келесі'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.secondaryColor,
                              ),
                              onPressed: _nextStep,
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Дайын'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.secondaryColor,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// AR-стиль гридті сызады
class ARGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.secondaryColor.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Corner accents
    final accentPaint = Paint()
      ..color = AppTheme.secondaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const d = 40.0;
    // Top-left
    canvas.drawLine(const Offset(20, 20), const Offset(20 + d, 20), accentPaint);
    canvas.drawLine(const Offset(20, 20), const Offset(20, 20 + d), accentPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20 - d, 20), accentPaint);
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20, 20 + d), accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
