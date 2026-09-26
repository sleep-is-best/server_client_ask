import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<File?> getFile(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = md5.convert(utf8.encode(url)).toString();
    final filePath = '${directory.path}/cache/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      return file;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      print('Cache Error: $e');
    }
    return null;
  }
}
