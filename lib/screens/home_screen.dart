import 'package:flutter/material.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';
import 'package:ar_ai_smart_study/utils/constants.dart';
import 'package:ar_ai_smart_study/screens/camera_screen.dart';
import 'package:ar_ai_smart_study/screens/history_screen.dart';
import 'package:ar_ai_smart_study/screens/gallery_scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Logo & Title
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 50,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                AppConstants.homeSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
              ),

              const SizedBox(height: 48),

              // Scan Button
              _buildMainButton(
                context,
                icon: Icons.camera_alt_rounded,
                label: AppConstants.scanButton,
                subtitle: 'Камерамен сканерле',
                gradient: const [AppTheme.primaryColor, Color(0xFF5A52E0)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // Gallery Button
              _buildMainButton(
                context,
                icon: Icons.photo_library_rounded,
                label: AppConstants.galleryButton,
                subtitle: 'Суретті таңда',
                gradient: const [AppTheme.secondaryColor, Color(0xFF00B894)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScanScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // History Button
              _buildMainButton(
                context,
                icon: Icons.history_rounded,
                label: AppConstants.historyTitle,
                subtitle: 'Бұрынғы сканерлер',
                gradient: const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),

              const SizedBox(height: 40),

              // How it works
              _buildHowItWorks(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    final steps = [
      {'icon': Icons.camera_alt, 'text': 'Камераны бағытта'},
      {'icon': Icons.text_fields, 'text': 'Мәтін танылады'},
      {'icon': Icons.psychology, 'text': 'AI түсіндіреді'},
      {'icon': Icons.view_in_ar, 'text': 'AR-де көрсетеді'},
    ];

    return Column(
      children: [
        Text(
          'Қалай жұмыс істейді?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: steps.map((step) {
            return Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    step['icon'] as IconData,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    step['text'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
