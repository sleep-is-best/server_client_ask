import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/answer.dart';
import '../services/database_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../config.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class QuestionDetailScreen extends StatefulWidget {
  final Question question;
  final String myUserId;

  const QuestionDetailScreen({
    super.key,
    required this.question,
    required this.myUserId,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  final SocketService _socketService = SocketService();
  final TextEditingController _answerController = TextEditingController();

  bool _isPosting = false;
  bool _isBookmarked = false;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _bestAnswerSubscription;
  StreamSubscription? _deleteSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _checkBookmarkStatus();
  }

  Future<void> _checkBookmarkStatus() async {
    if (widget.myUserId == 'guest') return;
    final bookmarks = await ApiService.getBookmarks(widget.myUserId);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarks.any((b) => b['targetType'] == 'question' && b['targetId'] == widget.question.id);
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.myUserId == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجل الدخول لحفظ الأسئلة')));
      return;
    }
    final res = await ApiService.toggleBookmark(widget.myUserId, 'question', widget.question.id!);
    if (res != null && mounted) {
      setState(() {
        _isBookmarked = res['bookmarked'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isBookmarked ? 'تمت الإضافة للمحفوظات' : 'تمت الإزالة من المحفوظات')),
      );
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerSubscription?.cancel();
    _bestAnswerSubscription?.cancel();
    _deleteSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    _answerSubscription = _socketService.answerStream.listen((data) async {
      final answer = Answer.fromMap(data);
      if (answer.questionId == widget.question.id) {
        await _dbService.insertAnswer(answer);
        CacheService().cacheAnswerMedia(answer);
        if (mounted) setState(() {});
      }
    });

    _bestAnswerSubscription = _socketService.bestAnswerStream.listen((data) async {
      final qId = data['questionId']?.toString();
      final aId = data['answerId']?.toString();
      if (qId == widget.question.id && aId != null) {
        await _dbService.markBestAnswer(qId!, aId);
        if (mounted) setState(() {});
      }
    });

    _deleteSubscription = _socketService.questionDeletedStream.listen((questionId) {
      if (questionId == widget.question.id && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف هذا السؤال من قبل الناشر')),
        );
      }
    });

    _refreshAnswers();
  }

  Future<void> _refreshAnswers() async {
    final serverAnswers = await ApiService.getAnswers(widget.question.id!);
    for (var a in serverAnswers) {
      final answer = Answer.fromMap(Map<String, dynamic>.from(a));
      await _dbService.insertAnswer(answer);
      CacheService().cacheAnswerMedia(answer);
    }
    if (mounted) setState(() {});
  }

  Future<void> _postAnswer() async {
    final text = _answerController.text.trim();
    if (text.isNotEmpty && !_isPosting) {
      setState(() => _isPosting = true);
      try {
        _socketService.postAnswer(widget.question.id!, text);
        await ApiService.reportActivity(widget.myUserId, 'post_answer').timeout(const Duration(seconds: 5));
        
        _answerController.clear();
        if (mounted) {
          FocusScope.of(context).unfocus();
          setState(() => _isPosting = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isPosting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إرسال الإجابة، يرجى التحقق من الاتصال')),
          );
        }
      }
    }
  }

  void _markAsBest(Answer answer) {
    if (widget.question.userId == widget.myUserId && !answer.isBest) {
      _socketService.markBestAnswer(widget.question.id!, answer.id!);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السؤال؟'),
        content: const Text('هل أنت متأكد من حذف هذا السؤال نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socketService.deleteQuestion(widget.question.id!);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(String targetType, String targetId) {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إبلاغ عن محتوى'),
        content: TextField(
          controller: reportController,
          decoration: const InputDecoration(
            hintText: 'سبب الإبلاغ...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final reason = reportController.text.trim();
              if (reason.isNotEmpty) {
                final success = await ApiService.submitReport(
                  widget.myUserId,
                  targetType,
                  targetId,
                  reason,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'تم إرسال الإبلاغ بنجاح' : 'فشل إرسال الإبلاغ')),
                  );
                }
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'المدير العام';
      case 'assistant_admin': return 'مساعد مدير';
      case 'doctor': return 'دكتور';
      case 'teacher': return 'أستاذ';
      case 'premium_member': return 'عضو مميز';
      default: return 'عضو';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
      case 'assistant_admin':
        return const Color(0xFFD4AF37);
      case 'doctor':
        return Colors.deepPurple;
      case 'teacher':
        return Colors.orange;
      case 'premium_member':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    return await ApiService.getProfile(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل السؤال'),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: AppColors.primary),
            onPressed: _toggleBookmark,
          ),
          if (widget.question.userId == widget.myUserId)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _confirmDelete(),
            )
          else if (widget.myUserId != 'guest')
            IconButton(
              icon: const Icon(Icons.report_problem_outlined, color: AppColors.textHint),
              onPressed: () => _showReportDialog('question', widget.question.id!),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: _getUserData(widget.question.userId),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data;
                        final name = userData?['name'] ?? widget.question.userId;
                        final role = userData?['role'] ?? 'member';
                        final profileImage = userData?['profileImage'];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserProfileScreen(userId: widget.question.userId, myUserId: widget.myUserId),
                                    ),
                                  ),
                                  child: UserAvatar(
                                    name: name,
                                    imageUrl: profileImage,
                                    radius: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (role != 'member') ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(role).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getRoleName(role),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getRoleColor(role),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        '${widget.question.timestamp.day}/${widget.question.timestamp.month} • ${widget.question.points} نقطة',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.question.content,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.6,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (widget.question.mediaUrls != null && widget.question.mediaUrls!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.question.mediaUrls!.length,
                                  itemBuilder: (context, index) {
                                    final rawUrl = widget.question.mediaUrls![index];
                                    final url = AppConfig.parseMediaUrl(rawUrl);
                                    return Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      width: 300,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: (widget.question.localPaths != null && 
                                                widget.question.localPaths!.length > index && 
                                                File(widget.question.localPaths![index]).existsSync())
                                            ? Image.file(File(widget.question.localPaths![index]), fit: BoxFit.cover)
                                            : (rawUrl.startsWith('http')
                                                ? Image.network(url, fit: BoxFit.cover)
                                                : Image.file(File(rawUrl), fit: BoxFit.cover)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.forum_rounded, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'الإجابات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  FutureBuilder<List<Answer>>(
                    future: _dbService.getAnswersForQuestion(widget.question.id!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final answers = snapshot.data!;
                      if (answers.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(60.0),
                            child: Column(
                              children: [
                                Icon(Icons.comment_bank_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                const Text(
                                  'لا توجد إجابات بعد. كن أول من يجيب!',
                                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: answers.length,
                        itemBuilder: (context, index) {
                          final answer = answers[index];
                          return AppCard(
                            color: answer.isBest ? AppColors.secondary.withValues(alpha: 0.05) : AppColors.surface,
                            borderRadius: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(16),
                            child: FutureBuilder<Map<String, dynamic>?>(
                              future: _getUserData(answer.userId),
                              builder: (context, ansUserSnapshot) {
                                final ansUserData = ansUserSnapshot.data;
                                final ansName = ansUserData?['name'] ?? answer.userId;
                                final ansRole = ansUserData?['role'] ?? 'member';
                                final ansProfileImage = ansUserData?['profileImage'];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => UserProfileScreen(userId: answer.userId, myUserId: widget.myUserId),
                                            ),
                                          ),
                                          child: UserAvatar(
                                            name: ansName,
                                            imageUrl: ansProfileImage,
                                            radius: 16
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  ansName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (ansRole != 'member') ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: _getRoleColor(ansRole).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    _getRoleName(ansRole),
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: _getRoleColor(ansRole),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (answer.isBest)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondary,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white, size: 14),
                                                SizedBox(width: 4),
                                                Text('أفضل إجابة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                              ],
                                            ),
                                          )
                                        else if (widget.question.userId == widget.myUserId)
                                          TextButton(
                                            onPressed: () => _markAsBest(answer),
                                            style: TextButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                            child: const Text('اختيار كأفضل', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        if (answer.userId != widget.myUserId && widget.myUserId != 'guest')
                                          IconButton(
                                            icon: const Icon(Icons.report_outlined, size: 18, color: AppColors.textHint),
                                            onPressed: () => _showReportDialog('answer', answer.id!),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      answer.content,
                                      style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary),
                                    ),
                                    if (answer.mediaUrls != null && answer.mediaUrls!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 100,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: answer.mediaUrls!.length,
                                          itemBuilder: (context, index) {
                                            final rawUrl = answer.mediaUrls![index];
                                            final hasLocal = answer.localPaths != null && 
                                                            answer.localPaths!.length > index &&
                                                            File(answer.localPaths![index]).existsSync();
                                            
                                            return Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              width: 100,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                image: DecorationImage(
                                                  image: hasLocal
                                                      ? FileImage(File(answer.localPaths![index])) as ImageProvider
                                                      : NetworkImage(AppConfig.parseMediaUrl(rawUrl)),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Reply Bar
          if (widget.myUserId != 'guest')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        enabled: !_isPosting,
                        decoration: InputDecoration(
                          hintText: 'اكتب إجابتك هنا...',
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _postAnswer,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isPosting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

