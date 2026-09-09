import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/question_card.dart';
import '../models/question.dart';
import '../models/educational_material.dart';
import 'question_detail_screen.dart';
import 'library/material_detail_screen.dart';


class BookmarksScreen extends StatefulWidget {
  final String myUserId;
  const BookmarksScreen({super.key, required this.myUserId});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<dynamic> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getBookmarks(widget.myUserId);
    if (mounted) {
      setState(() {
        _bookmarks = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'محفوظاتي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchBookmarks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = _bookmarks[index];
                      return _buildBookmarkItem(bookmark);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد عناصر محفوظة بعد',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(Map<String, dynamic> bookmark) {
    final type = bookmark['targetType'];
    final data = bookmark['data'];
    if (data == null) return const SizedBox.shrink();

    switch (type) {
      case 'question':
        final q = Question.fromMap(data);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: QuestionCard(
            question: q,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QuestionDetailScreen(question: q, myUserId: widget.myUserId)),
            ),
          ),
        );
      case 'material':
        final m = EducationalMaterial.fromMap(data);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.description, color: Colors.white),
            ),
            title: Text(m.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            subtitle: Text('${m.subjectName} - ${_getTypeLabel(m.materialType)}', style: const TextStyle(fontFamily: 'Cairo')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: m, myUserId: widget.myUserId)),
            ),
          ),
        );
      case 'reel':
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                image: data['thumbnail'] != null 
                  ? DecorationImage(image: NetworkImage(data['thumbnail']), fit: BoxFit.cover)
                  : null,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            title: Text(data['title'] ?? 'فيديو ريلز', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            subtitle: Text('بواسطة: ${data['creatorName'] ?? 'غير معروف'}', style: const TextStyle(fontFamily: 'Cairo')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to reels screen
            },
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'summary': return 'ملخص';
      case 'malzam': return 'ملزمة';
      case 'exam_model': return 'نموذج اختبار';
      default: return 'ملف';
    }
  }
}
