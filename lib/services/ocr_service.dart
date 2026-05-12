import 'dart:ui';
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

    final raw = buffer.toString().trim();

    // Постобработка: исправление кириллицы
    return _fixCyrillicText(raw);
  }

  /// Суреттен мәтін блоктарын тану (AR overlay үшін позициясымен)
  static Future<List<RecognizedBlock>> recognizeTextWithPositions(
      String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final List<RecognizedBlock> blocks = [];
    for (TextBlock block in recognizedText.blocks) {
      blocks.add(RecognizedBlock(
        text: _fixCyrillicText(block.text),
        boundingBox: block.boundingBox,
        lines: block.lines.map((l) => _fixCyrillicText(l.text)).toList(),
      ));
    }

    return blocks;
  }

  // ============================================================
  // Постобработка: Латиница → Кириллица
  // OCR часто путает кириллические буквы с похожими латинскими
  // (А→A, Н→H, б→6, ы→bl и т.д.)
  // ============================================================

  static String _fixCyrillicText(String text) {
    if (text.isEmpty) return text;

    // Считаем кириллические и латинские символы
    final cyrCount =
        RegExp(r'[а-яА-ЯёЁәғқңөұүһіӘҒҚҢӨҰҮҺІ]').allMatches(text).length;
    final latCount = RegExp(r'[a-zA-Z]').allMatches(text).length;

    // Если уже преимущественно кириллица — не трогаем
    if (latCount == 0) return text;
    if (cyrCount > latCount * 2) return text;

    // Проверяем: похож ли текст на "гарблед" кириллицу?
    // Признаки: много букв-двойников (A,B,C,E,H,K,M,O,P,T,X и т.д.)
    // и мало "чисто латинских" букв (f,j,q,w,v,d,g,l,z в контексте)
    final ambiguousUpper = RegExp(r'[ABCEHKMOPTXY]');
    final ambiguousLower = RegExp(r'[aceikmnopxy]');
    final ambCount = ambiguousUpper.allMatches(text).length +
        ambiguousLower.allMatches(text).length;

    // Если менее 30% символов — амбигуозные, это скорее всего настоящая латиница
    if (latCount > 0 && ambCount / latCount < 0.3) return text;

    var result = text;

    // 1. Многосимвольные паттерны (сначала!)
    result = result.replaceAll('bl', 'ы');
    result = result.replaceAll('Bl', 'Ы');
    result = result.replaceAll('BL', 'Ы');
    result = result.replaceAll('III', 'Ш');
    result = result.replaceAll('II', 'П');
    result = result.replaceAll('JI', 'Л');
    result = result.replaceAll('ji', 'л');

    // 2. Цифры → кириллица (только между буквами)
    result = result.replaceAllMapped(
      RegExp(r'(?<=[a-zA-Zа-яА-ЯёЁ])6(?=[a-zA-Zа-яА-ЯёЁ])'),
      (_) => 'б',
    );
    result = result.replaceAllMapped(
      RegExp(r'^6(?=[a-zA-Zа-яА-ЯёЁ])'),
      (_) => 'б',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<=[a-zA-Zа-яА-ЯёЁ])3(?=[a-zA-Zа-яА-ЯёЁ])'),
      (_) => 'з',
    );

    // 3. Посимвольная замена латиница → кириллица
    const upperMap = {
      'A': 'А',
      'B': 'В',
      'C': 'С',
      'E': 'Е',
      'H': 'Н',
      'K': 'К',
      'M': 'М',
      'O': 'О',
      'P': 'Р',
      'T': 'Т',
      'X': 'Х',
      'Y': 'У',
      'I': 'І',
    };
    const lowerMap = {
      'a': 'а',
      'c': 'с',
      'e': 'е',
      'i': 'і',
      'k': 'к',
      'm': 'м',
      'n': 'н',
      'o': 'о',
      'p': 'р',
      'u': 'у',
      'x': 'х',
      'y': 'у',
    };

    // Дополнительные: спецсимволы из расширенной латиницы
    const extendedMap = {
      'ş': 'ш',
      'Ş': 'Ш',
      'ž': 'ж',
      'Ž': 'Ж',
      'č': 'ч',
      'Č': 'Ч',
      'ñ': 'ң',
      'Ñ': 'Ң',
      'ö': 'ө',
      'Ö': 'Ө',
      'ü': 'ү',
      'Ü': 'Ү',
      'İ': 'І',
      'ı': 'і',
      'ğ': 'ғ',
      'Ğ': 'Ғ',
    };

    final buf = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final ch = result[i];
      if (upperMap.containsKey(ch)) {
        buf.write(upperMap[ch]);
      } else if (lowerMap.containsKey(ch)) {
        buf.write(lowerMap[ch]);
      } else if (extendedMap.containsKey(ch)) {
        buf.write(extendedMap[ch]);
      } else {
        buf.write(ch);
      }
    }

    return buf.toString();
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
