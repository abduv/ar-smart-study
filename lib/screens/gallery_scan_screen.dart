import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ar_ai_smart_study/screens/processing_screen.dart';

class GalleryScanScreen extends StatefulWidget {
  const GalleryScanScreen({super.key});

  @override
  State<GalleryScanScreen> createState() => _GalleryScanScreenState();
}

class _GalleryScanScreenState extends State<GalleryScanScreen> {
  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(imagePath: image.path),
        ),
      );
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
