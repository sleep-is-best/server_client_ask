import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Future<String?> downloadToPublicStorage({
    required String url,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      // 1. Request Storage Permissions (for older Android versions, SAF doesn't need this but good to have)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        // Note: On Android 13+, this might be always denied, and we should use media permissions
        // But SAF (FilePicker) doesn't strictly need it for saving.
      }

      // 2. Start Download
      final response = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final contentLength = response.contentLength ?? 0;
      
      List<int> bytes = [];
      final stream = response.stream;
      
      await for (var chunk in stream) {
        bytes.addAll(chunk);
        if (contentLength > 0 && onProgress != null) {
          onProgress(bytes.length / contentLength);
        }
      }

      final Uint8List uint8list = Uint8List.fromList(bytes);

      // 3. Use SAF to save the file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ الملف',
        fileName: fileName,
        bytes: uint8list,
      );

      return outputFile;
    } catch (e) {
      debugPrint('Download Error: $e');
      return null;
    }
  }

  Future<File?> downloadToCache(String url, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) return file;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('Cache Download Error: $e');
    }
    return null;
  }
}
