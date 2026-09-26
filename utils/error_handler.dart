import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ErrorHandler {
  static File? _logFile;

  static Future<void> init() async {
    await _initLogFile();

    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack);
    };

    // Handle asynchronous errors not caught by Flutter
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _logError(error, stack);
      return true;
    };

    // Custom Error Widget for UI build errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ غير متوقع',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Try to recover or restart
                  },
                  child: const Text('إعادة المحاولة'),
                )
              ],
            ),
          ),
        ),
      );
    };
  }

  static Future<void> _initLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/error_logs.txt');
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
    } catch (e) {
      debugPrint('Failed to initialize log file: $e');
    }
  }

  static void _logError(Object error, StackTrace? stack) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] ERROR: $error\nSTACKTRACE: $stack\n----------------------------------------\n';
    
    debugPrint('--- GLOBAL ERROR ---');
    debugPrint(error.toString());
    if (stack != null) debugPrint(stack.toString());
    debugPrint('--------------------');

    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      }
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  static Future<String> getLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return 'No logs found.';
  }

  static Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
