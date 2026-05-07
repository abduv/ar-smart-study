import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';
import 'package:ar_ai_smart_study/utils/constants.dart';
import 'package:ar_ai_smart_study/services/ocr_service.dart';
import 'package:ar_ai_smart_study/services/ai_service.dart';
import 'package:ar_ai_smart_study/services/scan_history_service.dart';
import 'package:ar_ai_smart_study/models/scan_result.dart';
import 'package:ar_ai_smart_study/screens/result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String imagePath;

  const ProcessingScreen({super.key, required this.imagePath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String _statusText = AppConstants.recognizingText;
  double _progress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _process();
  }

  Future<void> _process() async {
    try {
      // Step 1: OCR — мәтін тану
      setState(() {
        _statusText = AppConstants.recognizingText;
        _progress = 0.2;
      });

      final recognizedText = await OCRService.recognizeText(widget.imagePath);

      if (recognizedText.trim().isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = AppConstants.noTextFound;
        });
        return;
      }

      // Step 2: AI — түсіндірме жасау
      setState(() {
        _statusText = AppConstants.generatingExplanation;
        _progress = 0.6;
      });

      final aiService = context.read<AIService>();
      final explanation = await aiService.getExplanation(recognizedText);

      setState(() => _progress = 1.0);

      // Step 3: Тарихқа сақтау
      final result = ScanResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        recognizedText: recognizedText,
        explanation: explanation,
        imagePath: widget.imagePath,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        context.read<ScanHistoryService>().addResult(result);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '${AppConstants.errorOccurred}\n$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(widget.imagePath),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 40),

              if (!_hasError) ...[
                // Loading animation
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          startAngle: 0,
                          endAngle: 6.28,
                          transform: GradientRotation(
                              _animController.value * 6.28),
                          colors: const [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                            AppTheme.primaryColor,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.psychology,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Status text
                Text(
                  _statusText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ] else ...[
                // Error state
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Артқа қайту'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
