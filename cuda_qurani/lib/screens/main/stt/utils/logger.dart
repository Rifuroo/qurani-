// lib\screens\main\stt\utils\logger.dart

import 'package:flutter/foundation.dart';

// A simple logger class to handle logging throughout the app.
class AppLogger {
  final ValueNotifier<List<String>> _logsNotifier = ValueNotifier([]);
  ValueListenable<List<String>> get logs => _logsNotifier;

  void log(String category, String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    final logMessage = '[$timestamp] $category: $message';

    // Print to console for debugging
    print(logMessage);

    // Add to in-app log list
    final currentLogs = _logsNotifier.value;
    currentLogs.add(logMessage);
    if (currentLogs.length > 500) {
      // Keep log capacity
      currentLogs.removeAt(0);
    }
    _logsNotifier.value = List.from(currentLogs);
  }

  void clear() {
    _logsNotifier.value = [];
  }

  void dispose() {
    _logsNotifier.dispose();
  }
}



