import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ar_ai_smart_study/utils/app_theme.dart';
import 'package:ar_ai_smart_study/utils/constants.dart';
import 'package:ar_ai_smart_study/services/scan_history_service.dart';
import 'package:ar_ai_smart_study/models/scan_result.dart';
import 'package:ar_ai_smart_study/screens/result_screen.dart';
import 'dart:io';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.historyTitle),
        actions: [
          Consumer<ScanHistoryService>(
            builder: (context, history, _) {
              if (history.history.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => _showClearDialog(context, history),
              );
            },
          ),
        ],
      ),
      body: Consumer<ScanHistoryService>(
        builder: (context, historyService, _) {
          final history = historyService.history;

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Тарих бос',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Сканерлеген материалдар осында көрінеді',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryCard(context, item, historyService);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    ScanResult item,
    ScanHistoryService historyService,
  ) {
    final preview = item.recognizedText.length > 80
        ? '${item.recognizedText.substring(0, 80)}...'
        : item.recognizedText;

    final timeAgo = _formatTimeAgo(item.createdAt);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => historyService.removeResult(item.id),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(result: item),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              if (item.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(item.imagePath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.text_snippet, color: AppTheme.primaryColor),
                ),

              const SizedBox(width: 14),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Time
              Text(
                timeAgo,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Қазір';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return '${diff.inHours} сағ';
    if (diff.inDays < 7) return '${diff.inDays} күн';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showClearDialog(BuildContext context, ScanHistoryService history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Тарихты тазалау'),
        content: const Text('Барлық сканерлеу тарихын жоясыз ба?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жоқ'),
          ),
          TextButton(
            onPressed: () {
              history.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Иә', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
