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

Ответь на русском языке, понятно и по делу. Если нужно — приведи пример или формулу.
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
1. Если это задача — реши её пошагово
2. Если это вопрос — ответь на него
3. Если это текст — объясни его простым языком
4. Приведи формулы и правила если нужно
5. Дай краткий вывод

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
  // ДЕМО РЕЖИМ — анализ текста и генерация ответа
  // ============================================================

  String _detectType(String text) {
    final lower = text.toLowerCase();

    final mathPatterns = RegExp(
        r'[\+\-\×\÷\=]|'
        r'\d+\s*[\+\-\*\/\=]\s*\d+|'
        r'sin|cos|tan|log|sqrt|'
        r'x\s*[\+\-\*\/\=]|'
        r'формула|теңдеу|теорема|уравнение|'
        r'квадрат|функция|корень|дискриминант|'
        r'\d+x|\d+\s*x');
    if (mathPatterns.hasMatch(lower)) return 'math';

    final physicsPatterns = RegExp(
        r'м/с|кг|ньютон|джоуль|ватт|'
        r'km/h|m/s|kg|'
        r'күш|жылдамдық|масса|энергия|'
        r'сила|скорость|ускорение|'
        r'F\s*=|v\s*=|E\s*=|'
        r'импульс|гравитация|электр');
    if (physicsPatterns.hasMatch(lower)) return 'physics';

    final chemPatterns = RegExp(
        r'H₂O|CO₂|NaCl|O₂|H₂|'
        r'H2O|CO2|H2SO4|'
        r'молекула|атом|реакция|'
        r'кислота|оксид|'
        r'[A-Z][a-z]?\d|→|⟶');
    if (chemPatterns.hasMatch(text)) return 'chemistry';

    final bioPatterns = RegExp(
        r'клетка|ДНК|РНК|ген|хромосом|'
        r'жасуша|cell|DNA|RNA|'
        r'фотосинтез|митоз|организм|белок');
    if (bioPatterns.hasMatch(lower)) return 'biology';

    final historyPatterns = RegExp(
        r'\b\d{3,4}\s*(ж|г|год)|'
        r'ғасыр|век|хан|патша|'
        r'империя|соғыс|война');
    if (historyPatterns.hasMatch(lower)) return 'history';

    return 'general';
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
    final type = _detectType(text);
    final numbers = _findNumbers(text);

    switch (type) {
      case 'math':
        return _mathResponse(text, numbers);
      case 'physics':
        return _physicsResponse(text, numbers);
      case 'chemistry':
        return _chemistryResponse(text);
      case 'biology':
        return _biologyResponse(text);
      case 'history':
        return _historyResponse(text);
      default:
        return _generalResponse(text);
    }
  }

  String _mathResponse(String text, List<String> numbers) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    if (numbers.isNotEmpty) {
      buf.writeln('**Данные:** ${numbers.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### Решение');
    buf.writeln();

    if (text.contains(RegExp(r'x\s*[\²2]|x\^2|квадрат|дискриминант|ax'))) {
      buf.writeln('Это квадратное уравнение вида `ax² + bx + c = 0`');
      buf.writeln();
      buf.writeln('**Шаг 1.** Находим дискриминант: `D = b² - 4ac`');
      buf.writeln();
      buf.writeln('**Шаг 2.** Если D > 0 — два корня:');
      buf.writeln('- `x₁ = (-b + √D) / 2a`');
      buf.writeln('- `x₂ = (-b - √D) / 2a`');
      buf.writeln();
      buf.writeln('Если D = 0 — один корень: `x = -b / 2a`');
      buf.writeln();
      buf.writeln('Если D < 0 — корней нет');
      if (numbers.length >= 3) {
        buf.writeln();
        buf.writeln('**Шаг 3.** Подставляем: a=${numbers[0]}, b=${numbers[1]}, c=${numbers[2]}');
        try {
          final a = double.parse(numbers[0]);
          final b = double.parse(numbers[1]);
          final c = double.parse(numbers[2]);
          final d = b * b - 4 * a * c;
          buf.writeln();
          buf.writeln('D = ${b.toInt()}² - 4·${a.toInt()}·${c.toInt()} = **${d.toInt()}**');
          if (d > 0) {
            final x1 = (-b + _sqrt(d)) / (2 * a);
            final x2 = (-b - _sqrt(d)) / (2 * a);
            buf.writeln();
            buf.writeln('x₁ = **${x1.toStringAsFixed(2)}**');
            buf.writeln('x₂ = **${x2.toStringAsFixed(2)}**');
          } else if (d == 0) {
            final x = -b / (2 * a);
            buf.writeln();
            buf.writeln('x = **${x.toStringAsFixed(2)}**');
          } else {
            buf.writeln();
            buf.writeln('D < 0, корней нет.');
          }
        } catch (_) {}
      }
    } else if (text.contains(RegExp(r'\d+\s*[\+\-\*\/]\s*\d+'))) {
      final exprMatch = RegExp(r'(\d+\.?\d*)\s*([\+\-\*\/])\s*(\d+\.?\d*)').firstMatch(text);
      if (exprMatch != null) {
        final a = double.parse(exprMatch.group(1)!);
        final op = exprMatch.group(2)!;
        final b = double.parse(exprMatch.group(3)!);
        double? result;
        String opName = '';
        switch (op) {
          case '+':
            result = a + b;
            opName = 'Сложение';
            break;
          case '-':
            result = a - b;
            opName = 'Вычитание';
            break;
          case '*':
            result = a * b;
            opName = 'Умножение';
            break;
          case '/':
            result = b != 0 ? a / b : null;
            opName = 'Деление';
            break;
        }
        buf.writeln('**$opName:**');
        buf.writeln();
        buf.writeln('${a.toStringAsFixed(a == a.toInt() ? 0 : 2)} $op ${b.toStringAsFixed(b == b.toInt() ? 0 : 2)} = **${result?.toStringAsFixed(result == result?.toInt() ? 0 : 2) ?? "деление на 0"}**');
      } else {
        buf.writeln('**Шаг 1.** Определяем порядок действий: скобки → степень → умножение/деление → сложение/вычитание');
        buf.writeln();
        buf.writeln('**Шаг 2.** Выполняем вычисления по порядку');
        buf.writeln();
        buf.writeln('**Шаг 3.** Проверяем результат обратным действием');
      }
    } else {
      buf.writeln('**Шаг 1.** Записываем данные');
      buf.writeln();
      buf.writeln('**Шаг 2.** Выбираем нужную формулу');
      buf.writeln();
      buf.writeln('**Шаг 3.** Подставляем значения и вычисляем');
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  double _sqrt(double x) {
    if (x < 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  String _physicsResponse(String text, List<String> numbers) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    if (numbers.isNotEmpty) {
      buf.writeln('**Данные:** ${numbers.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### Решение');
    buf.writeln();

    if (text.contains(RegExp(r'күш|сила|force|F\s*=|ньютон'))) {
      buf.writeln('Применяем второй закон Ньютона: **F = m · a**');
      buf.writeln();
      buf.writeln('- F — сила (Н)');
      buf.writeln('- m — масса (кг)');
      buf.writeln('- a — ускорение (м/с²)');
      if (numbers.length >= 2) {
        final m = double.tryParse(numbers[0]);
        final a = double.tryParse(numbers[1]);
        if (m != null && a != null) {
          buf.writeln();
          buf.writeln('F = $m · $a = **${(m * a).toStringAsFixed(2)} Н**');
        }
      }
    } else if (text.contains(RegExp(r'жылдамдық|скорость|velocity|v\s*='))) {
      buf.writeln('Формула скорости: **v = s / t**');
      buf.writeln();
      buf.writeln('- v — скорость (м/с)');
      buf.writeln('- s — путь (м)');
      buf.writeln('- t — время (с)');
      if (numbers.length >= 2) {
        final s = double.tryParse(numbers[0]);
        final t = double.tryParse(numbers[1]);
        if (s != null && t != null && t != 0) {
          buf.writeln();
          buf.writeln('v = $s / $t = **${(s / t).toStringAsFixed(2)} м/с**');
        }
      }
    } else if (text.contains(RegExp(r'энергия|energy|E\s*='))) {
      buf.writeln('**Кинетическая энергия:** Eк = mv²/2');
      buf.writeln();
      buf.writeln('**Потенциальная энергия:** Eп = mgh');
      buf.writeln();
      buf.writeln('**Закон сохранения:** Eк₁ + Eп₁ = Eк₂ + Eп₂');
    } else {
      buf.writeln('**Шаг 1.** Записываем данные и переводим в СИ');
      buf.writeln();
      buf.writeln('**Шаг 2.** Выбираем формулу');
      buf.writeln();
      buf.writeln('**Шаг 3.** Подставляем и считаем');
      buf.writeln();
      buf.writeln('**Шаг 4.** Проверяем единицы измерения');
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  String _chemistryResponse(String text) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    final formulas = <String, String>{
      'H2O': 'Вода (2 водорода + 1 кислород)',
      'CO2': 'Углекислый газ (1 углерод + 2 кислорода)',
      'NaCl': 'Поваренная соль (натрий + хлор)',
      'H2SO4': 'Серная кислота',
      'NaOH': 'Гидроксид натрия (щёлочь)',
      'HCl': 'Соляная кислота',
      'CaCO3': 'Карбонат кальция (мел)',
      'Fe2O3': 'Оксид железа (ржавчина)',
    };

    final found = <String>[];
    formulas.forEach((formula, desc) {
      if (text.contains(formula)) {
        found.add('- **$formula** — $desc');
      }
    });

    if (found.isNotEmpty) {
      buf.writeln('**Найденные вещества:**');
      for (final f in found) {
        buf.writeln(f);
      }
      buf.writeln();
    }

    buf.writeln('### Объяснение');
    buf.writeln();

    if (text.contains(RegExp(r'→|⟶|реакция|reaction'))) {
      buf.writeln('Это химическая реакция.');
      buf.writeln();
      buf.writeln('**Типы реакций:**');
      buf.writeln('1. **Соединение:** A + B → AB');
      buf.writeln('2. **Разложение:** AB → A + B');
      buf.writeln('3. **Замещение:** A + BC → AC + B');
      buf.writeln('4. **Обмен:** AB + CD → AD + CB');
      buf.writeln();
      buf.writeln('Не забудьте уравнять — атомов слева и справа должно быть поровну.');
    } else {
      buf.writeln('- **Атом** — мельчайшая частица вещества');
      buf.writeln('- **Молекула** — группа связанных атомов');
      buf.writeln('- **Валентность** — способность атома образовывать связи');
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  String _biologyResponse(String text) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### Объяснение');
    buf.writeln();

    if (text.contains(RegExp(r'жасуша|клетка|cell'))) {
      buf.writeln('**Строение клетки:**');
      buf.writeln('- **Ядро** — хранит ДНК (генетическую информацию)');
      buf.writeln('- **Цитоплазма** — внутренняя среда клетки');
      buf.writeln('- **Мембрана** — защита и регуляция обмена веществ');
      buf.writeln('- **Митохондрии** — «электростанции» клетки (выработка энергии)');
      buf.writeln('- **Рибосомы** — синтез белков');
    } else if (text.contains(RegExp(r'ДНК|DNA|ген|gene'))) {
      buf.writeln('**ДНК** — дезоксирибонуклеиновая кислота');
      buf.writeln();
      buf.writeln('- Хранит наследственную информацию');
      buf.writeln('- Двойная спираль');
      buf.writeln('- Пары оснований: А-Т, Г-Ц');
      buf.writeln();
      buf.writeln('**Ген** — участок ДНК, кодирующий белок');
    } else {
      buf.writeln('Биологические понятия из текста:');
      buf.writeln();
      buf.writeln('- Живые организмы состоят из клеток');
      buf.writeln('- Основные свойства жизни: обмен веществ, размножение, рост, раздражимость');
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  String _historyResponse(String text) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();

    final yearRegex = RegExp(r'\b(\d{3,4})\s*(ж|г|год)?');
    final years = yearRegex.allMatches(text).map((m) => m.group(1)!).toList();

    if (years.isNotEmpty) {
      buf.writeln('**Даты:** ${years.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### Объяснение');
    buf.writeln();
    buf.writeln('**Как анализировать:**');
    buf.writeln('1. Определить период времени');
    buf.writeln('2. Найти ключевых участников');
    buf.writeln('3. Понять причинно-следственную связь');
    buf.writeln('4. Оценить значение события');

    final sentences = text.split(RegExp(r'[.!?\n]+')).where((s) => s.trim().length > 15).toList();
    if (sentences.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Ключевые моменты:**');
      for (var i = 0; i < sentences.length && i < 4; i++) {
        buf.writeln('- ${sentences[i].trim()}');
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  String _generalResponse(String text) {
    final buf = StringBuffer();

    buf.writeln('### Разбор');
    buf.writeln();
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### Объяснение');
    buf.writeln();

    final sentences = text.split(RegExp(r'[.!?\n]+')).where((s) => s.trim().length > 10).toList();
    if (sentences.isNotEmpty) {
      buf.writeln('**Основные мысли:**');
      for (var i = 0; i < sentences.length && i < 5; i++) {
        buf.writeln('${i + 1}. ${sentences[i].trim()}');
      }
      buf.writeln();
    }

    buf.writeln('**Советы:**');
    buf.writeln('- Выделите ключевую мысль текста');
    buf.writeln('- Отметьте важные термины');
    buf.writeln('- Задайте уточняющие вопросы');

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Есть вопросы? Спрашивайте во вкладке "Сұрақ"*');

    return buf.toString();
  }

  // ============================================================
  // FOLLOW-UP (допвопросы) в демо режиме
  // ============================================================

  String _generateFollowUp(
      String originalText, String explanation, String question) {
    final type = _detectType(originalText);
    final lowerQ = question.toLowerCase();
    final buf = StringBuffer();

    if (lowerQ.contains(RegExp(r'пример|мысал|example'))) {
      switch (type) {
        case 'math':
          buf.writeln('**Пример:**');
          buf.writeln();
          buf.writeln('Дано: 2x + 5 = 15');
          buf.writeln();
          buf.writeln('1. 2x = 15 - 5');
          buf.writeln('2. 2x = 10');
          buf.writeln('3. x = 10 / 2 = **5**');
          break;
        case 'physics':
          buf.writeln('**Пример:**');
          buf.writeln();
          buf.writeln('Машина проехала 120 км за 2 часа. Скорость?');
          buf.writeln();
          buf.writeln('v = s/t = 120/2 = **60 км/ч**');
          break;
        default:
          buf.writeln('Пример по вашему тексту:');
          buf.writeln();
          buf.writeln('> ${originalText.length > 80 ? originalText.substring(0, 80) : originalText}...');
          buf.writeln();
          buf.writeln('Попробуйте пересказать своими словами — это лучший способ запомнить.');
      }
    } else if (lowerQ.contains(RegExp(r'формула|formula'))) {
      switch (type) {
        case 'math':
          buf.writeln('**Основные формулы:**');
          buf.writeln('- `a² + b² = c²` — теорема Пифагора');
          buf.writeln('- `D = b² - 4ac` — дискриминант');
          buf.writeln('- `x = (-b ± √D) / 2a` — корни квадратного уравнения');
          buf.writeln('- `S = πr²` — площадь круга');
          break;
        case 'physics':
          buf.writeln('**Основные формулы:**');
          buf.writeln('- `F = ma` — сила');
          buf.writeln('- `v = s/t` — скорость');
          buf.writeln('- `E = mc²` — энергия');
          buf.writeln('- `A = Fs` — работа');
          break;
        default:
          buf.writeln('В данном тексте формулы не обнаружены.');
      }
    } else if (lowerQ.contains(RegExp(r'почему|неге|зачем|why'))) {
      buf.writeln('Хороший вопрос!');
      buf.writeln();
      buf.writeln('Исходя из текста:');
      buf.writeln('> ${originalText.length > 100 ? originalText.substring(0, 100) : originalText}...');
      buf.writeln();
      buf.writeln('Чтобы глубже разобраться, обратите внимание на основные принципы и закономерности.');
    } else if (lowerQ.contains(RegExp(r'как|қалай|how'))) {
      buf.writeln('**Пошагово:**');
      buf.writeln();
      buf.writeln('1. Определяем данные');
      buf.writeln('2. Выбираем нужную формулу/метод');
      buf.writeln('3. Выполняем по шагам');
      buf.writeln('4. Проверяем результат');
    } else {
      buf.writeln('**$question**');
      buf.writeln();
      switch (type) {
        case 'math':
          buf.writeln('По математике: запомните формулы и решайте побольше примеров — это лучший способ разобраться.');
          break;
        case 'physics':
          buf.writeln('По физике: попробуйте связать формулы с реальными примерами из жизни — так легче запомнить.');
          break;
        case 'chemistry':
          buf.writeln('По химии: обращайте внимание на свойства элементов. Периодическая таблица — ваш главный помощник.');
          break;
        default:
          buf.writeln('Перечитайте текст, выделите ключевые моменты и попробуйте пересказать своими словами.');
      }
    }

    return buf.toString();
  }
}
