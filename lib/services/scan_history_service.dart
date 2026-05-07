import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ar_ai_smart_study/models/scan_result.dart';

class ScanHistoryService extends ChangeNotifier {
  static const String _storageKey = 'scan_history';
  List<ScanResult> _history = [];

  List<ScanResult> get history => List.unmodifiable(_history);

  ScanHistoryService() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _history = jsonList
          .map((json) => ScanResult.fromJson(json as Map<String, dynamic>))
          .toList();
      _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
  }

  Future<void> addResult(ScanResult result) async {
    _history.insert(0, result);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeResult(String id) async {
    _history.removeWhere((r) => r.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_history.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }
}
