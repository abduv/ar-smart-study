import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ar_ai_smart_study/utils/constants.dart';

class AIService extends ChangeNotifier {
  bool _isLoading = false;
  String? _lastExplanation;
  String? _error;

  bool get isLoading => _isLoading;
  String? get lastExplanation => _lastExplanation;
  String? get error => _error;

  Future<String> getExplanation(String recognizedText,
      {String language = 'russian'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prompt = _buildPrompt(recognizedText, language);
      final explanation = await _callAI(prompt);
      _lastExplanation = explanation;
      _isLoading = false;
      notifyListeners();
      return explanation;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String> askFollowUp(
      String originalText, String explanation, String question) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prompt = '''
Исходный текст:
$originalText

Предыдущее объяснение:
$explanation

Вопрос ученика:
$question

Ответь на вопрос конкретно, опираясь на исходный текст. Не давай общие советы — дай прямой ответ.
Отвечай на русском языке.
''';

      String answer;
      if (AppConstants.aiApiKey == 'YOUR_API_KEY_HERE') {
        answer = _generateFollowUp(originalText, explanation, question);
      } else {
        answer = await _callAI(prompt);
      }

      _isLoading = false;
      notifyListeners();
      return answer;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  String _buildPrompt(String text, String language) {
    return '''
Ты — AI-учитель, помогающий ученикам.

Ученик отсканировал камерой этот текст:
---
$text
---

Твои задачи:
1. Если это задача с числами/уравнениями — реши её пошагово
2. Если это вопрос — ответь на него
3. Если это рассказ, сказка или текст — объясни содержание, перескажи суть
4. Приведи формулы и правила только если это учебный материал
5. Дай краткий вывод

Текст может содержать ошибки OCR (распознавания). Попытайся понять смысл даже если есть опечатки.
Отвечай на русском языке, простым и понятным языком.
Используй Markdown для форматирования.
''';
  }

  Future<String> _callAI(String prompt) async {
    if (AppConstants.aiApiKey == 'YOUR_API_KEY_HERE') {
      return _generateExplanation(prompt);
    }

    final response = await http.post(
      Uri.parse(AppConstants.aiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.aiApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': AppConstants.aiModel,
        'max_tokens': 2048,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    } else {
      throw Exception('Ошибка AI: ${response.statusCode} — ${response.body}');
    }
  }

  // ============================================================
  // ДЕМО РЕЖИМ
  // ============================================================

  /// Строго определяем: это задача с числами или обычный текст?
  bool _isMathProblem(String text) {
    // Должно быть реальное уравнение/выражение с числами и операторами
    // Не просто наличие символа +, а именно "число оператор число"
    final equationPattern = RegExp(
        r'\d+\s*[\+\-\*\/\×\÷]\s*\d+|'   // 5 + 3, 12 * 4
        r'\d+\s*x\s*[\+\-\=]|'             // 2x + 3 =
        r'x\s*[\+\-\=]\s*\d+|'             // x + 5 =
        r'\d+x[\²³]|'                       // 3x²
        r'\d+\s*=\s*\d+|'                   // 15 = 15
        r'sin\s*\(|cos\s*\(|tan\s*\(|'     // sin(x)
        r'sqrt\s*\(|log\s*\(|'             // sqrt(x)
        r'дискриминант|уравнение|теорема'
    );
    return equationPattern.hasMatch(text.toLowerCase());
  }

  bool _isPhysicsProblem(String text) {
    final lower = text.toLowerCase();
    // Должны быть единицы измерения + числа или формулы
    final hasUnits = RegExp(r'м/с|кг|ньютон|джоуль|ватт|km/h|m/s').hasMatch(lower);
    final hasFormula = RegExp(r'F\s*=|v\s*=|E\s*=|a\s*=|P\s*=').hasMatch(text);
    final hasPhysicsWords = RegExp(r'сила|скорость|ускорение|масса|энергия|күш|жылдамдық').hasMatch(lower);
    return (hasUnits || hasFormula) && (hasPhysicsWords || _findNumbers(text).length >= 2);
  }

  bool _isChemistry(String text) {
    return RegExp(
        r'H₂O|CO₂|NaCl|H2O|CO2|H2SO4|NaOH|HCl|'
        r'→|⟶|'
        r'[A-Z][a-z]?\d+\s*\+\s*[A-Z]'  // Chemical equation pattern
    ).hasMatch(text);
  }

  List<String> _findNumbers(String text) {
    return RegExp(r'-?\d+\.?\d*')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
  }

  Future<String> _generateExplanation(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final textMatch = RegExp(r'---\n([\s\S]*?)\n---').firstMatch(prompt);
    final text = textMatch?.group(1)?.trim() ?? prompt;

    if (_isMathProblem(text)) {
      return _mathResponse(text);
    } else if (_isPhysicsProblem(text)) {
      return _physicsResponse(text);
    } else if (_isChemistry(text)) {
      return _chemistryResponse(text);
    } else {
      return _textResponse(text);
    }
  }

  // --- Ответ для обычного текста (рассказ, сказка, параграф и т.д.) ---
  String _textResponse(String text) {
    final buf = StringBuffer();
    final sentences = text
        .split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().length > 5)
        .map((s) => s.trim())
        .toList();

    buf.writeln('### Содержание текста');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    if (sentences.length > 1) {
      buf.writeln('### О чём этот текст');
      buf.writeln();
      buf.writeln('В тексте ${sentences.length > 3 ? "рассказывается история" : "говорится"} о следующем:');
      buf.writeln();
      for (var i = 0; i < sentences.length && i < 6; i++) {
        buf.writeln('- ${sentences[i]}');
      }
      buf.writeln();
    }

    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    buf.writeln('**Количество слов:** ~$wordCount');
    buf.writeln();
    buf.writeln('Задайте вопрос по этому тексту во вкладке **"Сұрақ"** — и я отвечу подробнее.');

    return buf.toString();
  }

  // --- Ответ для математических задач ---
  String _mathResponse(String text) {
    final buf = StringBuffer();
    final numbers = _findNumbers(text);

    buf.writeln('### Условие');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    if (numbers.isNotEmpty) {
      buf.writeln('**Числа из задачи:** ${numbers.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### Решение');
    buf.writeln();

    // Квадратное уравнение
    if (text.contains(RegExp(r'x\s*[\²2]|x\^2|дискриминант'))) {
      buf.writeln('Квадратное уравнение: `ax² + bx + c = 0`');
      buf.writeln();
      buf.writeln('**1.** Дискриминант: `D = b² - 4ac`');
      buf.writeln();
      buf.writeln('**2.** Корни:');
      buf.writeln('- `x₁ = (-b + √D) / 2a`');
      buf.writeln('- `x₂ = (-b - √D) / 2a`');
      if (numbers.length >= 3) {
        try {
          final a = double.parse(numbers[0]);
          final b = double.parse(numbers[1]);
          final c = double.parse(numbers[2]);
          final d = b * b - 4 * a * c;
          buf.writeln();
          buf.writeln('**3.** a=$a, b=$b, c=$c');
          buf.writeln('- D = $b² - 4·$a·$c = **$d**');
          if (d > 0) {
            final sq = _sqrt(d);
            final x1 = (-b + sq) / (2 * a);
            final x2 = (-b - sq) / (2 * a);
            buf.writeln('- x₁ = **${x1.toStringAsFixed(2)}**');
            buf.writeln('- x₂ = **${x2.toStringAsFixed(2)}**');
          } else if (d == 0) {
            buf.writeln('- x = **${(-b / (2 * a)).toStringAsFixed(2)}**');
          } else {
            buf.writeln('- D < 0 → корней нет');
          }
        } catch (_) {}
      }
    }
    // Простое выражение
    else {
      final exprMatch = RegExp(r'(\d+\.?\d*)\s*([\+\-\*\/])\s*(\d+\.?\d*)').firstMatch(text);
      if (exprMatch != null) {
        final a = double.parse(exprMatch.group(1)!);
        final op = exprMatch.group(2)!;
        final b = double.parse(exprMatch.group(3)!);
        double? result;
        switch (op) {
          case '+': result = a + b; break;
          case '-': result = a - b; break;
          case '*': result = a * b; break;
          case '/': result = b != 0 ? a / b : null; break;
        }
        buf.writeln('$a $op $b = **${result?.toStringAsFixed(result == result?.toInt() ? 0 : 2) ?? "ошибка: деление на 0"}**');
      } else {
        buf.writeln('**1.** Записываем данные');
        buf.writeln('**2.** Подставляем в формулу');
        buf.writeln('**3.** Вычисляем результат');
      }
    }

    return buf.toString();
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  // --- Ответ для физики ---
  String _physicsResponse(String text) {
    final buf = StringBuffer();
    final numbers = _findNumbers(text);

    buf.writeln('### Условие');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    if (numbers.isNotEmpty) {
      buf.writeln('**Данные:** ${numbers.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### Решение');
    buf.writeln();

    final lower = text.toLowerCase();
    if (lower.contains(RegExp(r'сила|күш|F\s*='))) {
      buf.writeln('**F = m · a**');
      if (numbers.length >= 2) {
        final m = double.tryParse(numbers[0]);
        final a = double.tryParse(numbers[1]);
        if (m != null && a != null) {
          buf.writeln();
          buf.writeln('F = $m · $a = **${(m * a).toStringAsFixed(2)} Н**');
        }
      }
    } else if (lower.contains(RegExp(r'скорость|жылдамдық|v\s*='))) {
      buf.writeln('**v = s / t**');
      if (numbers.length >= 2) {
        final s = double.tryParse(numbers[0]);
        final t = double.tryParse(numbers[1]);
        if (s != null && t != null && t != 0) {
          buf.writeln();
          buf.writeln('v = $s / $t = **${(s / t).toStringAsFixed(2)} м/с**');
        }
      }
    } else {
      buf.writeln('**1.** Записываем данные в СИ');
      buf.writeln('**2.** Подбираем формулу');
      buf.writeln('**3.** Подставляем и считаем');
    }

    return buf.toString();
  }

  // --- Ответ для химии ---
  String _chemistryResponse(String text) {
    final buf = StringBuffer();

    buf.writeln('### Условие');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    final known = <String, String>{
      'H2O': 'Вода', 'CO2': 'Углекислый газ', 'NaCl': 'Соль',
      'H2SO4': 'Серная кислота', 'NaOH': 'Щёлочь', 'HCl': 'Соляная кислота',
    };

    final found = <String>[];
    known.forEach((f, name) {
      if (text.contains(f)) found.add('**$f** — $name');
    });

    if (found.isNotEmpty) {
      buf.writeln('### Вещества');
      buf.writeln();
      for (final f in found) buf.writeln('- $f');
      buf.writeln();
    }

    if (text.contains(RegExp(r'→|⟶'))) {
      buf.writeln('### Реакция');
      buf.writeln();
      buf.writeln('Проверьте уравнивание: количество атомов слева и справа должно совпадать.');
    }

    return buf.toString();
  }

  // ============================================================
  // FOLLOW-UP — конкретные ответы на вопросы
  // ============================================================

  String _generateFollowUp(
      String originalText, String explanation, String question) {
    final buf = StringBuffer();

    // Находим в исходном тексте предложения, которые могут относиться к вопросу
    final sentences = originalText
        .split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().length > 5)
        .map((s) => s.trim())
        .toList();

    // Ищем релевантные предложения по ключевым словам вопроса
    final questionWords = question
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    final relevant = <String>[];
    for (final s in sentences) {
      final sLower = s.toLowerCase();
      for (final w in questionWords) {
        if (sLower.contains(w)) {
          relevant.add(s);
          break;
        }
      }
    }

    if (relevant.isNotEmpty) {
      buf.writeln('По тексту нашёл следующее:');
      buf.writeln();
      for (final r in relevant) {
        buf.writeln('> $r');
      }
      buf.writeln();
      buf.writeln('Это из отсканированного текста — здесь содержится ответ на ваш вопрос.');
    } else if (sentences.isNotEmpty) {
      // Вопрос не совпал напрямую — даём контекст
      buf.writeln('В отсканированном тексте сказано:');
      buf.writeln();
      for (var i = 0; i < sentences.length && i < 4; i++) {
        buf.writeln('> ${sentences[i]}');
      }
      buf.writeln();
      buf.writeln('Попробуйте переформулировать вопрос или уточнить, что именно вас интересует.');
    } else {
      buf.writeln('К сожалению, в тексте не удалось найти прямого ответа на этот вопрос.');
      buf.writeln();
      buf.writeln('Попробуйте:');
      buf.writeln('- Задать вопрос другими словами');
      buf.writeln('- Отсканировать нужную часть текста ещё раз');
    }

    return buf.toString();
  }
}
