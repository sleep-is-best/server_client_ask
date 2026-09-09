import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  static String get baseUrl => AppConfig.serverUrl;
  static Map<String, dynamic>? _cachedProfile;

  static Future<Map<String, dynamic>?> register(String name, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Register Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> login({String? phone, String? studentId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'studentId': studentId}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Login Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/student/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Update Profile Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getProfile(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/student/profile/$studentId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cached = _cachedProfile;
        if (cached != null && cached['studentId'] == studentId) {
          _cachedProfile = data;
        }
        return data;
      }
    } catch (e) {
      debugPrint('API Get Profile Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentProfile(String studentId) async {
    final cached = _cachedProfile;
    if (cached != null && (cached['studentId'] == studentId || cached['id']?.toString() == studentId)) {
      return cached;
    }
    _cachedProfile = await getProfile(studentId);
    return _cachedProfile;
  }

  static Future<String?> uploadFile(String filePath, String studentId, {String type = 'file', bool isTemp = false}) async {
    try {
      String uploadUrl = '$baseUrl/api/upload';
      if (type == 'audio') uploadUrl = AppConfig.audioUploadUrl;
      else if (type == 'image') uploadUrl = AppConfig.imageUploadUrl;

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers['x-student-id'] = studentId;
      request.fields['studentId'] = studentId;
      request.fields['type'] = type;
      request.fields['isTemp'] = isTemp.toString();
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var data = jsonDecode(respStr);
        return data['url'];
      }
    } catch (e) {
      debugPrint('API Upload Error ($type): $e');
    }
    return null;
  }

  static Future<bool> deleteTempFile(String url, String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/upload/temp'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({'url': url}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Delete Temp File Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getQuestions({int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/questions?page=$page&limit=$limit'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Questions Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getMyQuestions(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/questions/my/$studentId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get My Questions Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/leaderboard'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Leaderboard Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getAnswers(String questionId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/questions/$questionId/answers'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Answers Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getStudentAnswers(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/student/$studentId/answers'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Student Answers Error: $e');
    }
    return [];
  }

  // --- Admin API ---
  static Future<Map<String, dynamic>> getAdminStats(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/stats'),
        headers: {'x-student-id': adminId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Admin Stats Error: $e');
    }
    return {};
  }

  static Future<List<dynamic>> getAdminMembers(String studentId, {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/members?page=$page&limit=$limit'),
        headers: {'x-student-id': studentId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Admin Members Error: $e');
    }
    return [];
  }

  static Future<bool> promoteMember(String adminId, String targetId, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/promote'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': adminId,
        },
        body: jsonEncode({'targetId': targetId, 'role': role}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Promote Member Error: $e');
      return false;
    }
  }

  static Future<bool> banMember(String adminId, String targetId, String reason, String duration) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/ban'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': adminId,
        },
        body: jsonEncode({
          'targetId': targetId,
          'reason': reason,
          'duration': duration, // In minutes, or 'permanent'
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Ban Member Error: $e');
      return false;
    }
  }

  static Future<bool> unbanMember(String adminId, String targetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/unban'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': adminId,
        },
        body: jsonEncode({'targetId': targetId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Unban Member Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAdminLogs(String adminId, {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/logs?page=$page&limit=$limit'),
        headers: {'x-student-id': adminId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Admin Logs Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getReports(String adminId, {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/reports?page=$page&limit=$limit'),
        headers: {'x-student-id': adminId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Reports Error: $e');
    }
    return [];
  }

  static Future<bool> submitReport(String studentId, String targetType, String targetId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/report'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({
          'targetType': targetType,
          'targetId': targetId,
          'reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Submit Report Error: $e');
      return false;
    }
  }

  static Future<bool> reportActivity(String studentId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/activity/report'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({'action': action}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Report Activity Error: $e');
      return false;
    }
  }

  static Future<bool> resolveReport(String adminId, String reportId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/reports/$reportId/resolve'),
        headers: {'x-student-id': adminId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Resolve Report Error: $e');
      return false;
    }
  }

  static Future<bool> deleteReportedContent(String adminId, String reportId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/reports/$reportId/content'),
        headers: {'x-student-id': adminId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Delete Reported Content Error: $e');
      return false;
    }
  }

  static Future<bool> deleteQuestion(String adminId, String questionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/questions/$questionId'),
        headers: {'x-student-id': adminId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Delete Question Error: $e');
      return false;
    }
  }

  static Future<bool> deleteReel(String adminId, String reelId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/reels/$reelId'),
        headers: {'x-student-id': adminId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Delete Reel Error: $e');
      return false;
    }
  }

  // --- Reels API ---
  static Future<List<dynamic>> getReels(String studentId, {int page = 1, int limit = 10, String type = 'feed', String? userId}) async {
    try {
      String url = '$baseUrl/api/reels?page=$page&limit=$limit&type=$type';
      if (userId != null) url += '&userId=$userId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-student-id': studentId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Reels Error: $e');
    }
    return [];
  }

  static Future<bool> likeReel(String studentId, String reelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reels/$reelId/like'),
        headers: {'x-student-id': studentId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Like Reel Error: $e');
      return false;
    }
  }

  static Future<bool> unlikeReel(String studentId, String reelId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/reels/$reelId/like'),
        headers: {'x-student-id': studentId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Unlike Reel Error: $e');
      return false;
    }
  }

  static Future<bool> reportReelView(String studentId, String reelId, int duration, double completionRate) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reels/$reelId/view'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({'duration': duration, 'completionRate': completionRate}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Report Reel View Error: $e');
      return false;
    }
  }

  static Future<bool> postReel(String studentId, Map<String, dynamic> reelData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reels/create'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({
          'userId': studentId,
          'videoUrl': reelData['video_url'],
          'title': reelData['title'] ?? '',
          'caption': reelData['caption'],
          'thumbnail': reelData['thumbnail'] ?? '',
          'reference': reelData['reference'] ?? '',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Post Reel Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getReelComments(String reelId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/reels/$reelId/comments'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Reel Comments Error: $e');
    }
    return [];
  }

  static Future<bool> postReelComment(String studentId, String reelId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reels/$reelId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({'content': content}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Post Reel Comment Error: $e');
      return false;
    }
  }

  static Future<bool> deleteReelComment(String studentId, String reelId, String commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/reels/$reelId/comments/$commentId'),
        headers: {'x-student-id': studentId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Delete Reel Comment Error: $e');
      return false;
    }
  }

  // --- Educational Materials API ---
  static Future<List<dynamic>> getSpecializations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/materials/specializations'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Specializations Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getLevels(int specializationId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/materials/levels/$specializationId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Levels Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getSubjects(int levelId, int semesterId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/materials/subjects?levelId=$levelId&semesterId=$semesterId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Subjects Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getMaterials({
    required int subjectId,
    required String type, // 'summary', 'malzam', 'exam_model'
    String? subjectName,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url = '$baseUrl/api/materials?subjectId=$subjectId&type=$type&page=$page&limit=$limit';
      if (subjectName != null) url += '&subjectName=${Uri.encodeComponent(subjectName)}';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Materials Error: $e');
    }
    return [];
  }

  static Future<bool> uploadEducationalMaterial(String studentId, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/materials'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Upload Material Error: $e');
      return false;
    }
  }

  static Future<bool> reportMaterialView(String materialId) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/materials/$materialId/view'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Report Material View Error: $e');
      return false;
    }
  }

  static Future<bool> reportMaterialDownload(String materialId) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/materials/$materialId/download'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Report Material Download Error: $e');
      return false;
    }
  }

  // Admin Materials Management
  static Future<List<dynamic>> getPendingMaterials(String adminId, {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/materials/pending?page=$page&limit=$limit'),
        headers: {'x-student-id': adminId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Pending Materials Error: $e');
    }
    return [];
  }

  static Future<bool> updateMaterialStatus(String adminId, String materialId, String status, {String? reason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/materials/$materialId/status'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': adminId,
        },
        body: jsonEncode({'status': status, 'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Update Material Status Error: $e');
      return false;
    }
  }

  static Future<bool> followUser(String myId, String targetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/student/follow/$targetId'),
        headers: {'x-student-id': myId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Follow Error: $e');
      return false;
    }
  }

  static Future<bool> unfollowUser(String myId, String targetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/student/follow/$targetId'),
        headers: {'x-student-id': myId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Unfollow Error: $e');
      return false;
    }
  }

  static Future<bool> blockUser(String myId, String targetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/student/block/$targetId'),
        headers: {'x-student-id': myId},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API Block Error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/student/find-by-phone?phone=$phone'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Find User By Phone Error: $e');
    }
    return null;
  }

  // --- Search API ---
  static Future<Map<String, dynamic>> search(String query, {String type = 'all', int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/search?q=${Uri.encodeComponent(query)}&type=$type&page=$page&limit=$limit'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Search Error: $e');
    }
    return {'results': [], 'total': 0};
  }

  // --- Feed API ---
  static Future<List<dynamic>> getFeed(String studentId, {int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feed?page=$page&limit=$limit'),
        headers: {'x-student-id': studentId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Feed Error: $e');
    }
    return [];
  }

  // --- Reputation & Badges API ---
  static Future<List<dynamic>> getBadges(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/student/$studentId/badges'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Badges Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getReputationHistory(String studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/student/$studentId/reputation'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Reputation History Error: $e');
    }
    return [];
  }

  // --- Bookmarks API ---
  static Future<List<dynamic>> getBookmarks(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/bookmarks'),
        headers: {'x-student-id': studentId},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Get Bookmarks Error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> toggleBookmark(String studentId, String targetType, String targetId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookmarks/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'x-student-id': studentId,
        },
        body: jsonEncode({
          'targetType': targetType,
          'targetId': targetId,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('API Toggle Bookmark Error: $e');
    }
    return null;
  }
}
