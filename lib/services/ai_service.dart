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

      String answer;
      if (AppConstants.aiApiKey == 'YOUR_API_KEY_HERE') {
        answer = _generateSmartFollowUp(originalText, explanation, question);
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
    // Егер API кілті жоқ болса — смарт демо режим
    if (AppConstants.aiApiKey == 'YOUR_API_KEY_HERE') {
      return _generateSmartExplanation(prompt);
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

  // ============================================================
  // СМАРТ ДЕМО РЕЖИМ — мәтінді талдап, нақты түсіндірме жасайды
  // ============================================================

  String _detectSubject(String text) {
    final lower = text.toLowerCase();

    // Математика белгілері
    final mathPatterns = RegExp(
        r'[\+\-\×\÷\=\≠\≤\≥\<\>]|'
        r'\d+\s*[\+\-\*\/\=]\s*\d+|'
        r'sin|cos|tan|log|sqrt|'
        r'x\s*[\+\-\*\/\=]|'
        r'формула|теңдеу|теорема|'
        r'equation|integral|derivative|'
        r'квадрат|функция|график|'
        r'уравнение|корень|дискриминант|'
        r'\d+x[\²³]|\d+x\^');
    if (mathPatterns.hasMatch(lower)) return 'math';

    // Физика белгілері
    final physicsPatterns = RegExp(
        r'м/с|кг|ньютон|джоуль|ватт|'
        r'km/h|m/s|kg|newton|joule|watt|'
        r'күш|жылдамдық|үдеу|масса|энергия|'
        r'сила|скорость|ускорение|'
        r'force|velocity|acceleration|energy|'
        r'F\s*=\s*m\s*[\*·]?\s*a|'
        r'E\s*=\s*m\s*c|'
        r'v\s*=\s*s\s*/\s*t|'
        r'импульс|гравитация|электр');
    if (physicsPatterns.hasMatch(lower)) return 'physics';

    // Химия белгілері
    final chemPatterns = RegExp(
        r'H₂O|CO₂|NaCl|O₂|H₂|'
        r'H2O|CO2|NaCl|O2|H2SO4|'
        r'молекула|атом|элемент|реакция|'
        r'кислота|щелочь|оксид|соль|'
        r'acid|base|molecule|reaction|'
        r'валентность|моль|'
        r'[A-Z][a-z]?\d|→|⟶');
    if (chemPatterns.hasMatch(text)) return 'chemistry';

    // Биология белгілері
    final bioPatterns = RegExp(
        r'клетка|ДНК|РНК|ген|хромосом|'
        r'жасуша|тұқымқуалау|'
        r'cell|DNA|RNA|gene|protein|'
        r'фотосинтез|митоз|мейоз|'
        r'организм|эволюция|'
        r'белок|фермент');
    if (bioPatterns.hasMatch(lower)) return 'biology';

    // Тарих белгілері
    final historyPatterns = RegExp(
        r'\b\d{3,4}\s*(ж|г|год|year)|'
        r'ғасыр|век|century|'
        r'хан|патша|президент|'
        r'империя|мемлекет|'
        r'соғыс|война|war|'
        r'revolution|dynasty|'
        r'б\.з\.д|н\.э|до нашей');
    if (historyPatterns.hasMatch(lower)) return 'history';

    // География белгілері
    final geoPatterns = RegExp(
        r'континент|мұхит|тау|өзен|'
        r'климат|атмосфера|литосфера|'
        r'океан|материк|'
        r'continent|ocean|mountain|river|'
        r'координат|широта|долгота');
    if (geoPatterns.hasMatch(lower)) return 'geography';

    // Тіл/Әдебиет белгілері
    final langPatterns = RegExp(
        r'сөйлем|сөз тіркесі|етістік|зат есім|'
        r'предложение|глагол|существительное|'
        r'грамматика|синтаксис|'
        r'sentence|grammar|verb|noun|'
        r'жалғау|жұрнақ|prefix|suffix');
    if (langPatterns.hasMatch(lower)) return 'language';

    // Информатика белгілері
    final csPatterns = RegExp(
        r'алгоритм|программа|код|'
        r'algorithm|function|variable|loop|'
        r'массив|цикл|переменная|'
        r'if\s*\(|for\s*\(|while\s*\(|'
        r'print|return|class|def |int |string');
    if (csPatterns.hasMatch(lower)) return 'cs';

    return 'general';
  }

  List<String> _extractNumbers(String text) {
    final regex = RegExp(r'-?\d+\.?\d*');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  String _extractEquation(String text) {
    final eqRegex = RegExp(r'[^\n]*[=+\-*/][^\n]*=?[^\n]*');
    final match = eqRegex.firstMatch(text);
    return match?.group(0)?.trim() ?? '';
  }

  Future<String> _generateSmartExplanation(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    // Промпттан мәтінді алу
    final textMatch = RegExp(r'---\n([\s\S]*?)\n---').firstMatch(prompt);
    final scannedText = textMatch?.group(1)?.trim() ?? prompt;

    final subject = _detectSubject(scannedText);
    final numbers = _extractNumbers(scannedText);
    final equation = _extractEquation(scannedText);

    switch (subject) {
      case 'math':
        return _buildMathExplanation(scannedText, numbers, equation);
      case 'physics':
        return _buildPhysicsExplanation(scannedText, numbers);
      case 'chemistry':
        return _buildChemistryExplanation(scannedText);
      case 'biology':
        return _buildBiologyExplanation(scannedText);
      case 'history':
        return _buildHistoryExplanation(scannedText);
      case 'geography':
        return _buildGeographyExplanation(scannedText);
      case 'language':
        return _buildLanguageExplanation(scannedText);
      case 'cs':
        return _buildCSExplanation(scannedText);
      default:
        return _buildGeneralExplanation(scannedText);
    }
  }

  String _buildMathExplanation(
      String text, List<String> numbers, String equation) {
    final buf = StringBuffer();
    buf.writeln('## 📐 Тақырып: Математика');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 📊 Талдау');
    buf.writeln();

    if (equation.isNotEmpty) {
      buf.writeln('**Берілген өрнек/теңдеу:** `$equation`');
      buf.writeln();
    }

    if (numbers.isNotEmpty) {
      buf.writeln('**Мәтіндегі сандар:** ${numbers.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### 🔢 Шешу қадамдары');
    buf.writeln();
    buf.writeln('**1-қадам:** Берілген мәліметтерді анықтау');
    buf.writeln(
        '- Мәтіннен математикалық өрнектер мен сандарды бөліп алдық');
    buf.writeln();

    if (text.contains(RegExp(r'x\s*[\²2]|x\^2|квадрат|дискриминант'))) {
      buf.writeln('**2-қадам:** Квадрат теңдеуді шешу');
      buf.writeln('- Жалпы формула: `ax² + bx + c = 0`');
      buf.writeln('- Дискриминант: `D = b² - 4ac`');
      buf.writeln('- Түбірлер: `x = (-b ± √D) / 2a`');
      buf.writeln();
      buf.writeln('**3-қадам:** Мәндерді формулаға қою');
      if (numbers.length >= 3) {
        buf.writeln(
            '- a = ${numbers[0]}, b = ${numbers[1]}, c = ${numbers[2]}');
      }
    } else if (text.contains(RegExp(r'[+\-]\s*\d'))) {
      buf.writeln('**2-қадам:** Арифметикалық амалдарды орындау');
      buf.writeln('- Амалдар ретін сақтаңыз: жақша → дәреже → көбейту/бөлу → қосу/алу');
      buf.writeln();
      buf.writeln('**3-қадам:** Нәтижені тексеру');
      buf.writeln('- Кері амалмен тексеріңіз');
    } else {
      buf.writeln('**2-қадам:** Формуланы қолдану');
      buf.writeln('- Берілген мәндерді формулаға қойыңыз');
      buf.writeln();
      buf.writeln('**3-қадам:** Есептеу');
      buf.writeln('- Қадаммен есептеп, нәтижені алыңыз');
    }

    buf.writeln();
    buf.writeln('### 📐 Маңызды формулалар');
    buf.writeln('| Формула | Сипаттама |');
    buf.writeln('|---------|-----------|');
    buf.writeln('| `(a+b)² = a² + 2ab + b²` | Қысқаша көбейту |');
    buf.writeln('| `S = a × b` | Тіктөртбұрыш ауданы |');
    buf.writeln('| `P = 2(a + b)` | Периметр |');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln(
        'Бұл есепте математикалық амалдарды дұрыс ретпен орындау маңызды. '
        'Әрқашан берілгенді жазып, формуланы таңдап, қадаммен шешіңіз.');

    return buf.toString();
  }

  String _buildPhysicsExplanation(String text, List<String> numbers) {
    final buf = StringBuffer();
    buf.writeln('## ⚡ Тақырып: Физика');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 🔬 Талдау');
    buf.writeln();

    if (numbers.isNotEmpty) {
      buf.writeln('**Берілген шамалар:** ${numbers.join(', ')}');
      buf.writeln();
    }

    if (text.contains(RegExp(r'күш|сила|force|F\s*=|ньютон|newton'))) {
      buf.writeln('### 📏 Ньютон заңдары');
      buf.writeln();
      buf.writeln('**1-заң:** Инерция заңы — дене сыртқы күш әсерінсіз қозғалыс күйін сақтайды');
      buf.writeln();
      buf.writeln('**2-заң:** `F = m × a`');
      buf.writeln('- F — күш (Ньютон, Н)');
      buf.writeln('- m — масса (кг)');
      buf.writeln('- a — үдеу (м/с²)');
      buf.writeln();
      buf.writeln('**3-заң:** Әрекет = Қарсы әрекет');
    } else if (text.contains(RegExp(r'жылдамдық|скорость|velocity|v\s*='))) {
      buf.writeln('### 🏃 Қозғалыс');
      buf.writeln();
      buf.writeln('**Жылдамдық формуласы:** `v = s / t`');
      buf.writeln('- v — жылдамдық (м/с)');
      buf.writeln('- s — жол (м)');
      buf.writeln('- t — уақыт (с)');
      buf.writeln();
      buf.writeln('**Бірқалыпты үдемелі қозғалыс:**');
      buf.writeln('- `v = v₀ + at`');
      buf.writeln('- `s = v₀t + at²/2`');
    } else if (text.contains(RegExp(r'энергия|energy|E\s*='))) {
      buf.writeln('### ⚡ Энергия');
      buf.writeln();
      buf.writeln('**Кинетикалық энергия:** `Eк = mv²/2`');
      buf.writeln('**Потенциалдық энергия:** `Eп = mgh`');
      buf.writeln('**Энергияның сақталу заңы:** `Eк₁ + Eп₁ = Eк₂ + Eп₂`');
    } else {
      buf.writeln('### 📏 Негізгі формулалар');
      buf.writeln();
      buf.writeln('| Шама | Формула | Бірлік |');
      buf.writeln('|------|---------|--------|');
      buf.writeln('| Жылдамдық | v = s/t | м/с |');
      buf.writeln('| Күш | F = ma | Н |');
      buf.writeln('| Энергия | E = mc² | Дж |');
      buf.writeln('| Жұмыс | A = Fs | Дж |');
    }

    buf.writeln();
    buf.writeln('### 🔢 Шешу қадамдары');
    buf.writeln('1. Берілген шамаларды жазыңыз');
    buf.writeln('2. Тиісті формуланы таңдаңыз');
    buf.writeln('3. Мәндерді қойып есептеңіз');
    buf.writeln('4. Өлшем бірлігін тексеріңіз');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln(
        'Физикада есеп шығарған кезде бірлік жүйесін сақтау өте маңызды. '
        'СИ жүйесін қолданыңыз.');

    return buf.toString();
  }

  String _buildChemistryExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 🧪 Тақырып: Химия');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 🔬 Талдау');
    buf.writeln();

    // Жиі кездесетін химиялық формулалар
    final formulas = <String, String>{
      'H2O': 'Су — 2 сутек + 1 оттек атомы',
      'CO2': 'Көмірқышқыл газы — 1 көміртек + 2 оттек',
      'NaCl': 'Ас тұзы — натрий + хлор',
      'H2SO4': 'Күкірт қышқылы',
      'NaOH': 'Натрий гидроксиді (сілті)',
      'HCl': 'Тұз қышқылы',
      'CaCO3': 'Кальций карбонаты (бор)',
      'Fe2O3': 'Темір оксиді (тат)',
    };

    final found = <String>[];
    formulas.forEach((formula, desc) {
      if (text.contains(formula)) {
        found.add('- **$formula** — $desc');
      }
    });

    if (found.isNotEmpty) {
      buf.writeln('**Табылған заттар:**');
      for (final f in found) {
        buf.writeln(f);
      }
      buf.writeln();
    }

    if (text.contains(RegExp(r'→|⟶|реакция|reaction'))) {
      buf.writeln('### ⚗️ Химиялық реакция');
      buf.writeln();
      buf.writeln('**Реакция типтері:**');
      buf.writeln('1. **Қосылу:** A + B → AB');
      buf.writeln('2. **Ыдырау:** AB → A + B');
      buf.writeln('3. **Орын басу:** A + BC → AC + B');
      buf.writeln('4. **Алмасу:** AB + CD → AD + CB');
      buf.writeln();
      buf.writeln('**Маңызды:** Реакцияны теңестіру керек — '
          'екі жақта атом саны тең болуы тиіс!');
    } else {
      buf.writeln('### 🔬 Негізгі ұғымдар');
      buf.writeln();
      buf.writeln('- **Атом** — заттың ең кіші бөлшегі');
      buf.writeln('- **Молекула** — атомдар тобы');
      buf.writeln('- **Валенттілік** — атомның байланысу қабілеті');
      buf.writeln('- **Моль** — 6.022 × 10²³ бөлшек');
    }

    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln(
        'Химиялық формулаларды дұрыс жазу және реакцияларды теңестіру — '
        'химияның негізі.');

    return buf.toString();
  }

  String _buildBiologyExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 🧬 Тақырып: Биология');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 🔬 Талдау');
    buf.writeln();

    if (text.contains(RegExp(r'жасуша|клетка|cell'))) {
      buf.writeln('### 🔬 Жасуша құрылысы');
      buf.writeln();
      buf.writeln('**Негізгі бөліктері:**');
      buf.writeln('- **Ядро** — генетикалық ақпарат (ДНК) сақтайды');
      buf.writeln('- **Цитоплазма** — жасуша ішкі ортасы');
      buf.writeln('- **Мембрана** — жасушаны қоршайды, заттарды реттейді');
      buf.writeln('- **Митохондрия** — энергия өндіреді (жасуша "электростанциясы")');
      buf.writeln('- **Рибосома** — белок синтездейді');
    } else if (text.contains(RegExp(r'ДНК|DNA|ген|gene|тұқымқуалау'))) {
      buf.writeln('### 🧬 Генетика');
      buf.writeln();
      buf.writeln('**ДНК** — дезоксирибонуклеин қышқылы');
      buf.writeln('- Тұқымқуалау ақпаратын сақтайды');
      buf.writeln('- Қос спираль құрылымды');
      buf.writeln('- Нуклеотидтер: A-T, G-C жұптары');
      buf.writeln();
      buf.writeln('**Ген** — ДНК-ның белок кодтайтын бөлігі');
    } else {
      buf.writeln('**Мәтіндегі биологиялық ұғымдар талданды.**');
      buf.writeln();
      buf.writeln('### 📚 Негізгі ұғымдар');
      buf.writeln('- Тірі организмдер жасушалардан тұрады');
      buf.writeln('- Тіршіліктің негізгі белгілері: зат алмасу, көбею, өсу, тітіркенгіштік');
    }

    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Биология — тірі организмдер туралы ғылым. '
        'Жасуша деңгейінен бастап, экожүйеге дейін зерттейді.');

    return buf.toString();
  }

  String _buildHistoryExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 📜 Тақырып: Тарих');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 📊 Талдау');
    buf.writeln();

    // Жылдарды табу
    final yearRegex = RegExp(r'\b(\d{3,4})\s*(ж|г|год|year)?');
    final years = yearRegex.allMatches(text).map((m) => m.group(1)!).toList();

    if (years.isNotEmpty) {
      buf.writeln('**Мәтіндегі жылдар:** ${years.join(', ')}');
      buf.writeln();
    }

    buf.writeln('### 📖 Тарихи контекст');
    buf.writeln();
    buf.writeln('Бұл мәтінде тарихи оқиғалар немесе тұлғалар туралы айтылады.');
    buf.writeln();
    buf.writeln('**Талдау кезеңдері:**');
    buf.writeln('1. **Уақыт кезеңін** анықтау');
    buf.writeln('2. **Негізгі тұлғаларды** табу');
    buf.writeln('3. **Себеп-салдар** байланысын түсіну');
    buf.writeln('4. **Маңыздылығын** бағалау');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Тарихи оқиғаларды уақыт тізбегімен есте сақтау маңызды. '
        'Себеп-салдар байланысына назар аударыңыз.');

    return buf.toString();
  }

  String _buildGeographyExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 🌍 Тақырып: География');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 🗺️ Талдау');
    buf.writeln();
    buf.writeln('Бұл мәтінде географиялық ұғымдар немесе нысандар туралы айтылады.');
    buf.writeln();
    buf.writeln('**Негізгі географиялық ұғымдар:**');
    buf.writeln('- Материктер мен мұхиттар');
    buf.writeln('- Климат белдеулері');
    buf.writeln('- Табиғат зоналары');
    buf.writeln('- Халық пен шаруашылық');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Географияда карта оқу дағдысы мен табиғат процестерін түсіну маңызды.');

    return buf.toString();
  }

  String _buildLanguageExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 📝 Тақырып: Тіл білімі');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 📖 Грамматикалық талдау');
    buf.writeln();

    final wordCount = text.split(RegExp(r'\s+')).length;
    final sentenceCount = text.split(RegExp(r'[.!?]+')).length - 1;

    buf.writeln('- **Сөз саны:** ~$wordCount');
    if (sentenceCount > 0) {
      buf.writeln('- **Сөйлем саны:** ~$sentenceCount');
    }
    buf.writeln();
    buf.writeln('### 📚 Негізгі ережелер');
    buf.writeln();
    buf.writeln('**Сөз таптары:**');
    buf.writeln('- **Зат есім** — кім? не? (кітап, бала)');
    buf.writeln('- **Сын есім** — қандай? (үлкен, жақсы)');
    buf.writeln('- **Етістік** — не істеді? (оқыды, жазды)');
    buf.writeln('- **Үстеу** — қалай? қашан? (тез, бүгін)');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Грамматика ережелерін есте сақтау үшін көп мысал жасаңыз.');

    return buf.toString();
  }

  String _buildCSExplanation(String text) {
    final buf = StringBuffer();
    buf.writeln('## 💻 Тақырып: Информатика');
    buf.writeln();
    buf.writeln('### 📝 Сканерленген мәтін');
    buf.writeln('```');
    buf.writeln(text);
    buf.writeln('```');
    buf.writeln();
    buf.writeln('### 🔍 Талдау');
    buf.writeln();

    if (text.contains(RegExp(r'if|else|elif|switch'))) {
      buf.writeln('**Шартты оператор табылды.**');
      buf.writeln();
      buf.writeln('`if-else` — шарт тексеру операторы:');
      buf.writeln('- Шарт ақиқат (true) болса → бірінші блок орындалады');
      buf.writeln('- Шарт жалған (false) болса → else блогы орындалады');
    }
    if (text.contains(RegExp(r'for|while|loop'))) {
      buf.writeln('**Цикл табылды.**');
      buf.writeln();
      buf.writeln('Цикл — кодты қайталап орындау:');
      buf.writeln('- `for` — белгілі рет қайталау');
      buf.writeln('- `while` — шарт орындалғанша қайталау');
    }

    buf.writeln();
    buf.writeln('### 📚 Негізгі ұғымдар');
    buf.writeln('- **Айнымалы (variable)** — деректерді сақтау');
    buf.writeln('- **Функция (function)** — қайта қолданылатын код блогы');
    buf.writeln('- **Массив (array)** — деректер тізімі');
    buf.writeln('- **Цикл (loop)** — қайталау');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Программалау — алгоритмдік ойлауды дамытатын пән. '
        'Код жазу арқылы үйреніңіз!');

    return buf.toString();
  }

  String _buildGeneralExplanation(String text) {
    final buf = StringBuffer();
    final wordCount = text.split(RegExp(r'\s+')).length;

    buf.writeln('## 📚 Сканерленген мәтін талдауы');
    buf.writeln();
    buf.writeln('### 📝 Мәтін');
    buf.writeln('> $text');
    buf.writeln();
    buf.writeln('### 📊 Жалпы ақпарат');
    buf.writeln('- **Сөз саны:** ~$wordCount');
    buf.writeln();
    buf.writeln('### 📖 Түсіндірме');
    buf.writeln();
    buf.writeln('Бұл мәтінде берілген ақпаратты қарастырайық:');
    buf.writeln();

    // Мәтіннен негізгі сөйлемдерді алу
    final sentences = text.split(RegExp(r'[.!?\n]+')).where((s) => s.trim().length > 10).toList();
    if (sentences.isNotEmpty) {
      buf.writeln('**Негізгі ойлар:**');
      for (var i = 0; i < sentences.length && i < 5; i++) {
        buf.writeln('${i + 1}. ${sentences[i].trim()}');
      }
      buf.writeln();
    }

    buf.writeln('### 💡 Кеңестер');
    buf.writeln('- Мәтіннің негізгі ойын ажыратыңыз');
    buf.writeln('- Маңызды терминдерді белгілеңіз');
    buf.writeln('- Сұрақтар қойып, тереңірек түсініңіз');
    buf.writeln();
    buf.writeln('### ✅ Қорытынды');
    buf.writeln('Мәтінді мұқият оқып, негізгі ақпаратты бөліп алу маңызды. '
        'Қосымша сұрақтар қою үшін "Сұрақ" бөліміне өтіңіз.');

    return buf.toString();
  }

  /// Смарт follow-up жауап (демо режим)
  String _generateSmartFollowUp(
      String originalText, String explanation, String question) {
    final subject = _detectSubject(originalText);
    final lowerQ = question.toLowerCase();
    final buf = StringBuffer();

    // Сұрақ түрін анықтау
    if (lowerQ.contains(RegExp(r'мысал|пример|example'))) {
      buf.writeln('### 📌 Мысал');
      buf.writeln();
      _addExampleForSubject(buf, subject, originalText);
    } else if (lowerQ.contains(RegExp(r'формула|formula'))) {
      buf.writeln('### 📐 Формулалар');
      buf.writeln();
      _addFormulasForSubject(buf, subject);
    } else if (lowerQ.contains(RegExp(r'неге|почему|why|себеб'))) {
      buf.writeln('### 🤔 Түсіндірме');
      buf.writeln();
      buf.writeln('Жақсы сұрақ! Мұның себебі:');
      buf.writeln();
      buf.writeln('Сканерленген мәтіндегі ақпарат бойынша:');
      buf.writeln('> ${originalText.length > 100 ? originalText.substring(0, 100) : originalText}...');
      buf.writeln();
      buf.writeln('Бұл тақырыпты тереңірек түсіну үшін негізгі '
          'принциптерге назар аударыңыз.');
    } else if (lowerQ.contains(RegExp(r'қалай|как|how'))) {
      buf.writeln('### 📝 Қадаммен түсіндірме');
      buf.writeln();
      buf.writeln('Бұл процесс/әдіс былай жұмыс істейді:');
      buf.writeln();
      buf.writeln('1. **Бірінші қадам** — берілгенді анықтаңыз');
      buf.writeln('2. **Екінші қадам** — тиісті әдісті/формуланы таңдаңыз');
      buf.writeln('3. **Үшінші қадам** — қадаммен орындаңыз');
      buf.writeln('4. **Тексеру** — нәтижені растаңыз');
    } else {
      // Жалпы жауап
      buf.writeln('Сіздің сұрағыңыз: **$question**');
      buf.writeln();
      buf.writeln('Сканерленген мәтін бойынша жауап:');
      buf.writeln();

      switch (subject) {
        case 'math':
          buf.writeln('Математикалық тұрғыдан бұл тақырып маңызды. '
              'Формулаларды есте сақтау және мысалдар шығару арқылы тереңірек түсінуге болады.');
          break;
        case 'physics':
          buf.writeln('Физика заңдарын түсіну үшін тәжірибе жасап көріңіз. '
              'Күнделікті өмірдегі мысалдар физика заңдарын жақсы түсіндіреді.');
          break;
        case 'chemistry':
          buf.writeln('Химиялық процестерді түсіну үшін элементтердің қасиеттеріне '
              'назар аударыңыз. Периодтық кесте — сіздің жол көрсетушіңіз.');
          break;
        default:
          buf.writeln('Бұл тақырып бойынша қосымша ақпарат:');
          buf.writeln();
          buf.writeln('- Мәтіннің негізгі ойын ажыратыңыз');
          buf.writeln('- Белгісіз терминдерді іздеңіз');
          buf.writeln('- Практикалық мысалдар қараңыз');
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln('*Тағы сұрақ бар ма? Қоя беріңіз! 🎓*');

    return buf.toString();
  }

  void _addExampleForSubject(StringBuffer buf, String subject, String text) {
    switch (subject) {
      case 'math':
        buf.writeln('**Есеп мысалы:**');
        buf.writeln();
        buf.writeln('Берілгені: 2x + 5 = 15');
        buf.writeln();
        buf.writeln('Шешуі:');
        buf.writeln('1. 2x = 15 - 5');
        buf.writeln('2. 2x = 10');
        buf.writeln('3. x = 10 / 2');
        buf.writeln('4. **x = 5** ✅');
        break;
      case 'physics':
        buf.writeln('**Есеп мысалы:**');
        buf.writeln();
        buf.writeln('Автокөлік 2 сағатта 120 км жол жүрді. Жылдамдығы қанша?');
        buf.writeln();
        buf.writeln('Шешуі: v = s/t = 120/2 = **60 км/сағ** ✅');
        break;
      case 'chemistry':
        buf.writeln('**Реакция мысалы:**');
        buf.writeln();
        buf.writeln('`2H₂ + O₂ → 2H₂O`');
        buf.writeln();
        buf.writeln('2 молекула сутек + 1 молекула оттек = 2 молекула су');
        break;
      default:
        buf.writeln('Мәтіндегі ақпарат негізінде мысал:');
        buf.writeln();
        final sentences = text.split(RegExp(r'[.!?\n]+')).where((s) => s.trim().isNotEmpty).toList();
        if (sentences.isNotEmpty) {
          buf.writeln('> ${sentences.first.trim()}');
          buf.writeln();
          buf.writeln('Бұл мәтіннен басты ойды ажыратып, өз сөзіңізбен түсіндіріңіз.');
        }
    }
  }

  void _addFormulasForSubject(StringBuffer buf, String subject) {
    switch (subject) {
      case 'math':
        buf.writeln('| Формула | Атауы |');
        buf.writeln('|---------|-------|');
        buf.writeln('| `a² + b² = c²` | Пифагор теоремасы |');
        buf.writeln('| `D = b² - 4ac` | Дискриминант |');
        buf.writeln('| `x = (-b ± √D) / 2a` | Квадрат теңдеу |');
        buf.writeln('| `S = πr²` | Шеңбер ауданы |');
        break;
      case 'physics':
        buf.writeln('| Формула | Шама |');
        buf.writeln('|---------|------|');
        buf.writeln('| `F = ma` | Күш |');
        buf.writeln('| `v = s/t` | Жылдамдық |');
        buf.writeln('| `E = mc²` | Энергия |');
        buf.writeln('| `p = mv` | Импульс |');
        buf.writeln('| `A = Fs` | Жұмыс |');
        break;
      case 'chemistry':
        buf.writeln('| Формула | Зат |');
        buf.writeln('|---------|-----|');
        buf.writeln('| H₂O | Су |');
        buf.writeln('| CO₂ | Көмірқышқыл газ |');
        buf.writeln('| NaCl | Тұз |');
        buf.writeln('| n = m/M | Моль саны |');
        break;
      default:
        buf.writeln('Бұл тақырып бойынша нақты формулалар мәтінде табылмады. '
            'Мәтінді қайта сканерлеп көріңіз.');
    }
  }
}
