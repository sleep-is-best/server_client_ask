import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'login_screen.dart';
import 'reels_screen.dart';
import 'create_reel_screen.dart';
import 'chat_screen.dart';
import 'contact_list_screen.dart';
import 'library/library_main_screen.dart';
import 'notifications_screen.dart';
import 'question_detail_screen.dart';
import 'settings_screen.dart';
import 'profile_hub_screen.dart';
import 'leaderboard_screen.dart';
import '../models/answer.dart';
import '../models/message.dart';
import '../models/question.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../utils/app_colors.dart';
import '../utils/crypto_helper.dart';
import '../widgets/category_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/search_field.dart';
import '../widgets/question_card.dart';
import '../widgets/user_avatar.dart';

class MainNavigationScreen extends StatefulWidget {
  final String myUserId;
  const MainNavigationScreen({super.key, required this.myUserId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  // إزالة الـ GlobalKey لأنه قد يسبب مشاكل Re-parenting عند الرجوع
  final DatabaseService _dbService = DatabaseService();
  final SocketService _socketService = SocketService();
  int myPoints = 0;
  int _currentTabIndex = 0;
  Map<String, dynamic>? myProfile;

  late Stream<List<Message>> _recentChatsStream;

  StreamSubscription? _notificationSubscription;
  StreamSubscription? _questionSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _pointsSubscription;
  StreamSubscription? _bestAnswerSubscription;

  String _selectedCategory = 'الكل';
  final List<String> _categories = ['الكل', 'رياضيات', 'فيزياء', 'كيمياء', 'أدب', 'تقنية'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);
    _currentTabIndex = _tabController.index;
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        if (mounted) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
        }
      }
    });
    _recentChatsStream = _dbService.getRecentChatsStream(widget.myUserId);
    _socketService.connect(widget.myUserId);
    _setupNotificationListener();
    _setupSocketListeners();
    _loadProfile();
    _syncQuestionsFromServer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    _questionSubscription?.cancel();
    _answerSubscription?.cancel();
    _pointsSubscription?.cancel();
    _bestAnswerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getProfile(widget.myUserId);
    if (mounted && profile != null) {
      setState(() {
        myProfile = profile;
      });
    }

  }

  Future<void> _syncQuestionsFromServer() async {
    try {
      final data = await ApiService.getQuestions();
      if (data.isEmpty) return;

      final questions = data
          .map((item) => Question.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      if (questions.isNotEmpty) {
        await _dbService.replaceQuestions(questions);
      }
    } catch (e) {
      // Keep the cached questions when the server is unavailable.
      debugPrint('Question sync failed: $e');
    }
  }

  void _setupSocketListeners() {
    _questionSubscription = _socketService.questionStream.listen((data) async {
      final q = Question.fromMap(data);
      await _dbService.insertQuestion(q);
      if (mounted) setState(() {});
    });

    _answerSubscription = _socketService.answerStream.listen((data) async {
      final answer = Answer.fromMap(data);
      await _dbService.insertAnswer(answer);
      if (mounted) _showLuxurySnackBar('إجابة جديدة على سؤال!');
    });

    _pointsSubscription = _socketService.pointsStream.listen((data) {
      if (mounted) {
        setState(() {
          myPoints = data['points'] ?? 0;
        });
      }
    });

    _bestAnswerSubscription = _socketService.bestAnswerStream.listen((data) async {
      await _dbService.markBestAnswer(data['questionId'], data['answerId']);
      if (mounted) setState(() {});
    });
  }

  void _showLuxurySnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService.onNotificationClick.stream.listen((response) {
      if (!mounted) return;
      if (response.payload != null) {
         if (response.payload!.startsWith('chat:')) {
          String senderId = response.payload!.split(':')[1];
          if (senderId.isEmpty || senderId == widget.myUserId) return;
          
          // استخدام SchedulerBinding لضمان أن الواجهة جاهزة للملاحة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    userId: widget.myUserId,
                    targetUserId: senderId,
                  ),
                ),
              );
            }
          });
        }
      }
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DatabaseService().clearAllData();
    FlutterBackgroundService().invoke('stopService');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الرئيسية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(myUserId: widget.myUserId),
                ),
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen(myUserId: widget.myUserId)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen(myUserId: widget.myUserId)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeScreen(),
          ReelsScreen(myUserId: widget.myUserId),
          LibraryMainScreen(
            myUserId: widget.myUserId,
            myName: myProfile?['name'] ?? '',
            myRole: myProfile?['role'],
          ),
          ProfileHubScreen(
            myUserId: widget.myUserId,
            studentData: myProfile,
            onLogout: _logout,
            onProfileUpdate: (newData) {
              if (mounted) setState(() => myProfile = newData);
            },
          ),
          LeaderboardScreen(myUserId: widget.myUserId),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'الرئيسية'),
                _buildNavItem(1, Icons.play_circle_filled_rounded, Icons.play_circle_outline, 'ريلز'),
                const Opacity(opacity: 0, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add, size: 26))),
                _buildNavItem(2, Icons.menu_book_rounded, Icons.menu_book_outlined, 'المكتبة'),
                _buildNavItem(4, Icons.leaderboard_rounded, Icons.leaderboard_outlined, 'الصدارة'),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: widget.myUserId == 'guest' ? null : FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFab(),
      drawer: Drawer(
        child: _buildChatList(),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (widget.myUserId == 'guest') return null;
    final myRole = myProfile?['role'];
    final isMainAdmin = myRole == 'admin' || widget.myUserId == 'STU-527174';
    final isAssistant = myRole == 'assistant_admin';
    final points = myProfile?['points'] ?? 0;
    
    // Check which tab is selected using _currentTabIndex which is updated via listener
    final isReelsTab = _currentTabIndex == 1;

    return FloatingActionButton(
      onPressed: () {
        if (isReelsTab) {
          if (isMainAdmin || isAssistant || points >= 1000) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CreateReelScreen(myUserId: widget.myUserId)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عذراً، يجب أن يكون لديك 1000 نقطة على الأقل لنشر الريلز', style: TextStyle(fontFamily: 'Cairo')),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          _showAddQuestionDialog();
        }
      },
      backgroundColor: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 8,
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProfile();
        if (mounted) setState(() {});
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        name: myProfile?['name'] ?? 'User',
                        imageUrl: myProfile?['profilePicture'],
                        radius: 25,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك،',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            myProfile?['name'] ?? 'طالبنا العزيز',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildPointsCard(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SearchField(hintText: 'ابحث عن سؤال أو موضوع...'),
                  const SizedBox(height: 24),
                  _buildBanner(),
                  const SizedBox(height: 24),
                  const Text(
                    'التصنيفات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return CategoryChip(
                          label: cat,
                          isSelected: _selectedCategory == cat,
                          onTap: () {
                            if (mounted) setState(() => _selectedCategory = cat);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'أسئلة شائعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('عرض الكل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<Question>>(
            stream: _dbService.questionsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              var questions = snapshot.data!;
              if (_selectedCategory != 'الكل') {
                // In a real app, questions would have a category field.
                // For now, we'll simulate filtering or assume content contains keywords.
                questions = questions.where((q) => q.content.contains(_selectedCategory)).toList();
              }

              if (questions.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == 'الكل' ? 'لا توجد أسئلة بعد' : 'لا توجد أسئلة في قسم $_selectedCategory',
                          style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final q = questions[index];
                    return QuestionCard(
                      question: q,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestionDetailScreen(
                              question: q,
                              myUserId: widget.myUserId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: questions.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 4),
          Text(
            '$myPoints نقطة',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تعلم اليوم\nواجعل إنجازك أكبر غداً',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(2); // Navigate to Library
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('اكتشف الآن'),
          ),
        ],
      ),
    );
  }

  void _openChat(String targetId) {
    if (widget.myUserId == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول لبدء محادثة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (targetId.isEmpty || targetId == widget.myUserId) return;
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(userId: widget.myUserId, targetUserId: targetId),
      ),
    );
  }

  void _showAddQuestionDialog() {
    final controller = TextEditingController();
    final List<String> selectedMedia = [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'اسأل سؤالاً جديداً',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اطرح سؤالك وسيقوم زملاؤك أو المعلمون بالإجابة عليه.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Cairo'
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                maxLines: 5,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك هنا بالتفصيل...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  fillColor: AppColors.background,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedMedia.isNotEmpty)
                Container(
                  height: 90,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedMedia.length,
                    itemBuilder: (context, index) => Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(File(selectedMedia[index])),
                              fit: BoxFit.cover
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                        Positioned(
                          left: 5, top: 5,
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedMedia.removeAt(index)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.error,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setModalState(() => selectedMedia.addAll(images.map((e) => e.path)));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'أرفق صوراً',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    width: 140,
                    text: 'نشر الآن',
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty) {
                        List<String> uploadedUrls = [];
                        for (String path in selectedMedia) {
                          String? url = await ApiService.uploadFile(path, widget.myUserId);
                          if (url != null) uploadedUrls.add(url);
                        }
                        _socketService.postQuestion(controller.text.trim(), mediaUrls: uploadedUrls);
                        Navigator.pop(context);
                        _showLuxurySnackBar('تم نشر سؤالك بنجاح ✨');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showAnswerDialog(Question q) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة إجابة'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'اكتب إجابتك هنا...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _socketService.postAnswer(q.id!, controller.text);
                controller.dispose();
                Navigator.pop(context);
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            color: AppColors.primary,
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'المحادثات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _recentChatsStream,
              builder: (chatContext, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final chats = snapshot.data!;
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 80, color: AppColors.textHint.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد محادثات بعد',
                          style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  itemBuilder: (listContext, index) {
                    final lastMsg = chats[index];
                    return _RecentChatTile(
                      lastMsg: lastMsg,
                      myUserId: widget.myUserId,
                      onTap: (peerId) {
                        Navigator.of(listContext).pop(); // Close drawer safely
                        _openChat(peerId);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatelessWidget {
  final String myUserId;

  const MessagesScreen({super.key, required this.myUserId});

  void _openChat(BuildContext context, String targetId) {
    if (targetId.isEmpty || targetId == myUserId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: myUserId,
          targetUserId: targetId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = DatabaseService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'الرسائل',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: myUserId == 'guest'
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactListScreen(myUserId: myUserId),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: StreamBuilder<List<Message>>(
        stream: database.getRecentChatsStream(myUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? <Message>[];
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 80,
                      color: AppColors.textHint.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد رسائل بعد',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (myUserId != 'guest')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContactListScreen(myUserId: myUserId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('ابدأ محادثة'),
                      ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final message = chats[index];
              final peerId =
                  message.isMe ? message.targetId : message.senderId;
              final peerName = message.isMe
                  ? (message.targetName ?? message.targetPhone ?? peerId)
                  : (message.senderName ?? message.senderPhone ?? peerId);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    peerName.isEmpty ? '?' : peerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  peerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                subtitle: Text(
                  message.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _openChat(context, peerId),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecentChatTile extends StatefulWidget {
  final Message lastMsg;
  final String myUserId;
  final Function(String) onTap;

  const _RecentChatTile({
    required this.lastMsg,
    required this.myUserId,
    required this.onTap,
  });

  @override
  State<_RecentChatTile> createState() => _RecentChatTileState();
}

class _RecentChatTileState extends State<_RecentChatTile> {
  Future<Map<String, dynamic>?>? _profileFuture;
  late String _peerId;

  @override
  void initState() {
    super.initState();
    _updatePeerInfo();
  }

  @override
  void didUpdateWidget(_RecentChatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastMsg.senderId != widget.lastMsg.senderId || 
        oldWidget.lastMsg.targetId != widget.lastMsg.targetId) {
      _updatePeerInfo();
    }
  }

  void _updatePeerInfo() {
    _peerId = widget.lastMsg.isMe ? widget.lastMsg.targetId : widget.lastMsg.senderId;
    _profileFuture = ApiService.getProfile(_peerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?['name'] ?? _peerId;
        final imageUrl = profile?['profilePicture'];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            onTap: () => widget.onTap(_peerId),
            leading: UserAvatar(
              name: name,
              imageUrl: imageUrl,
              radius: 24,
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Cairo',
              ),
            ),
            subtitle: Text(
              widget.lastMsg.text.startsWith('[') 
                  ? widget.lastMsg.text 
                  : CryptoHelper.decrypt(widget.lastMsg.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: widget.lastMsg.status != MessageStatus.read && !widget.lastMsg.isMe
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  )
                : null,
          ),
        );
      },
    );
  }
}
