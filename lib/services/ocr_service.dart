import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Суреттен мәтінді тану
  static Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final StringBuffer buffer = StringBuffer();
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Суреттен мәтін блоктарын тану (AR overlay үшін позициясымен)
  static Future<List<RecognizedBlock>> recognizeTextWithPositions(
      String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final List<RecognizedBlock> blocks = [];
    for (TextBlock block in recognizedText.blocks) {
      blocks.add(RecognizedBlock(
        text: block.text,
        boundingBox: block.boundingBox,
        lines: block.lines.map((l) => l.text).toList(),
      ));
    }

    return blocks;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}

class RecognizedBlock {
  final String text;
  final Rect boundingBox;
  final List<String> lines;

  RecognizedBlock({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });
}
