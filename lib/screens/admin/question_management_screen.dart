import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../services/api_service.dart';
import '../../widgets/desktop_question_card.dart';

class QuestionManagementScreen extends StatefulWidget {
  final String myUserId;
  const QuestionManagementScreen({super.key, required this.myUserId});

  @override
  State<QuestionManagementScreen> createState() => _QuestionManagementScreenState();
}

class _QuestionManagementScreenState extends State<QuestionManagementScreen> {
  List<dynamic> questions = [];
  bool isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _fetchQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadMoreRunning &&
        _hasMore) {
      _loadMoreQuestions();
    }
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getQuestions(page: 1);
    if (mounted) {
      setState(() {
        questions = data;
        isLoading = false;
        if (data.length < 20) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreQuestions() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getQuestions(page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          questions.addAll(data);
          if (data.length < 20) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
      setState(() => _isLoadMoreRunning = false);
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('حذف السؤال', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا السؤال نهائياً؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteQuestion(widget.myUserId, questionId);
      if (success) {
        _fetchQuestions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف السؤال بنجاح'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل حذف السؤال'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = const Color(0xFFD4AF37);
    final darkBg = const Color(0xFF0A0A0A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          title: const Text('إدارة الأسئلة', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        Text('لا توجد أسئلة حالياً', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'Cairo')
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchQuestions,
                    color: goldColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: questions.length + (_isLoadMoreRunning ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == questions.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: goldColor)),
                          );
                        }
                        final qMap = questions[index];
                        final q = Question.fromMap(Map<String, dynamic>.from(qMap));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Stack(
                            children: [
                              DesktopQuestionCard(
                                question: q,
                                myUserId: widget.myUserId,
                                onAnswer: () {},
                                onProfileTap: () {},
                                onTap: () {},
                                onDelete: q.id == null ? null : () => _deleteQuestion(q.id!),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    if (q.id != null) {
                                      _deleteQuestion(q.id!);
                                    }
                                  },
                                  tooltip: 'حذف السؤال',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
