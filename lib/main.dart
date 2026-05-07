import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ar_ai_smart_study/services/ai_service.dart';
import 'package:ar_ai_smart_study/services/scan_history_service.dart';
import 'package:ar_ai_smart_study/screens/home_screen.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartStudyApp());
}

class SmartStudyApp extends StatelessWidget {
  const SmartStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AIService()),
        ChangeNotifierProvider(create: (_) => ScanHistoryService()),
      ],
      child: MaterialApp(
        title: 'AR+AI Smart Study',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
