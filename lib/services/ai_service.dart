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

  /// Танылған мәтінге AI түсіндірме жасау
  Future<String> getExplanation(String recognizedText,
      {String language = 'kazakh'}) async {
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

  /// Қосымша сұрақ қою
  Future<String> askFollowUp(
      String originalText, String explanation, String question) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prompt = '''
Бұрынғы мәтін:
$originalText

Бұрынғы түсіндірме:
$explanation

Оқушының сұрағы:
$question

Осы сұраққа қазақ тілінде, қарапайым тілмен, оқушыға түсінікті етіп жауап бер.
Қажет болса мысал немесе формула қос.
''';

      final answer = await _callAI(prompt);
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
    final langInstruction = language == 'kazakh'
        ? 'Қазақ тілінде жауап бер.'
        : language == 'russian'
            ? 'Отвечай на русском языке.'
            : 'Answer in English.';

    return '''
Сен — оқушыларға көмектесетін AI-мұғалімсің.

Оқушы камерамен мына мәтінді сканерледі:
---
$text
---

Міндеттерің:
1. Мәтіннің тақырыбын анықта (математика, физика, химия, тарих, т.б.)
2. Мәтінді қадам-қадаммен түсіндір
3. Егер есеп/тапсырма болса — шешімін қадаммен көрсет
4. Маңызды формулалар мен ережелерді бөлек жаз
5. Қысқаша қорытынды жаса

$langInstruction
Қарапайым тілмен, оқушыға түсінікті етіп жаз.
Markdown формат қолдан.
''';
  }

  Future<String> _callAI(String prompt) async {
    // Егер API кілті жоқ болса — демо режим
    if (AppConstants.aiApiKey == 'YOUR_API_KEY_HERE') {
      return _getDemoExplanation(prompt);
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
      throw Exception('AI қатесі: ${response.statusCode} — ${response.body}');
    }
  }

  /// Демо режим — API кілтісіз жұмыс істейді
  Future<String> _getDemoExplanation(String prompt) async {
    await Future.delayed(const Duration(seconds: 2));

    return '''
## 📚 Тақырып: Сканерленген мәтін

### 📝 Түсіндірме

Бұл мәтінде берілген ақпаратты талдап көрейік.

**Негізгі ойлар:**
- Мәтіннен негізгі тақырып анықталды
- Маңызды терминдер мен ұғымдар табылды

### 📐 Формулалар мен ережелер

> Бұл демо режим. Нақты AI түсіндірме алу үшін `lib/utils/constants.dart` файлында API кілтін қойыңыз.

### ✅ Қорытынды

Қосымша камераңды кітапқа бағыттап, мәтінді сканерлейді, AI арқылы түсіндірме жасайды.

---
*💡 Кеңес: API кілтін орнатыңыз — нақты AI түсіндірме аласыз!*
''';
  }
}
