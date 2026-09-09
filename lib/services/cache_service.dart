import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import '../models/question.dart';
import '../models/answer.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final _dbService = DatabaseService();

  Future<void> cacheQuestionMedia(Question question) async {
    if (question.mediaUrls == null || question.mediaUrls!.isEmpty) return;
    
    List<String> localPaths = [];
    for (var url in question.mediaUrls!) {
      final file = await getFile(url);
      if (file != null) {
        localPaths.add(file.path);
      }
    }
    
    if (localPaths.isNotEmpty && question.id != null) {
      await _dbService.updateQuestionLocalPaths(question.id!, localPaths);
    }
  }

  Future<void> cacheAnswerMedia(Answer answer) async {
    if (answer.mediaUrls == null || answer.mediaUrls!.isEmpty) return;
    
    List<String> localPaths = [];
    for (var url in answer.mediaUrls!) {
      final file = await getFile(url);
      if (file != null) {
        localPaths.add(file.path);
      }
    }
    
    if (localPaths.isNotEmpty && answer.id != null) {
      await _dbService.updateAnswerLocalPaths(answer.id!, localPaths);
    }
  }

  Future<File?> getFile(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = md5.convert(utf8.encode(url)).toString();
    final extension = p.extension(url).split('?').first;
    final filePath = '${directory.path}/cache/$fileName$extension';
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
