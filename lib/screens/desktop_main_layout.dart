import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/question.dart';
import '../widgets/desktop_question_card.dart';
import 'question_detail_screen.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/biometric_helper.dart';
import '../utils/crypto_helper.dart';
import 'chat_screen.dart';
import 'profile_edit_screen.dart';
import 'contact_list_screen.dart';
import 'user_profile_screen.dart';
import 'profile_hub_screen.dart';
import 'reels_screen.dart';
import 'library/library_main_screen.dart';
import 'about_us_screen.dart';
import 'admin/admin_panel_screen.dart';
import 'banned_screen.dart';
import 'login_screen.dart';
import '../config.dart';
import '../services/notification_service.dart';
import '../widgets/cached_image.dart';

class DesktopMainLayout extends StatefulWidget {
  final String myUserId;
  const DesktopMainLayout({super.key, required this.myUserId});

  @override
  State<DesktopMainLayout> createState() => _DesktopMainLayoutState();
}

class _DesktopMainLayoutState extends State<DesktopMainLayout> {
  int _selectedIndex = 0;
  final SocketService _socketService = SocketService();
  int myPoints = 0;
  List<dynamic> _leaderboardData = [];
  Map<String, dynamic>? _studentData;

  int _selectedAlgo = 0;

  StreamSubscription? _deleteSubscription;
  StreamSubscription? _roleSubscription;
  StreamSubscription? _bannedSubscription;
  StreamSubscription? _pointsSubscription;
  StreamSubscription? _questionSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _leaderboardSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchStudentData();
    _syncQuestionsFromServer();
    
    // Connect socket if not connected
    _socketService.connect(widget.myUserId);

    _setupSocketListeners();

    // Initial fetch
    _socketService.getLeaderboard();
  }

  @override
  void dispose() {
    _deleteSubscription?.cancel();
    _roleSubscription?.cancel();
    _bannedSubscription?.cancel();
    _pointsSubscription?.cancel();
    _questionSubscription?.cancel();
    _answerSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    _pointsSubscription = _socketService.pointsStream.listen((data) {
      if (mounted) setState(() => myPoints = data['points'] ?? 0);
    });

    _questionSubscription = _socketService.questionStream.listen((data) async {
      final q = Question.fromMap(data);
      await DatabaseService().insertQuestion(q);
    });

    _answerSubscription = _socketService.answerStream.listen((data) async {
      final questionId = data['questionId']?.toString();
      if (questionId == null) return;
      
      final questions = await DatabaseService().getQuestions();
      final qIdx = questions.indexWhere((q) => q.id == questionId);
      if (qIdx != -1) {
        questions[qIdx].answerCount++;
        await DatabaseService().insertQuestion(questions[qIdx]);
      }
    });

    _leaderboardSubscription = _socketService.leaderboardStream.listen((data) {
      if (mounted) setState(() => _leaderboardData = data);
    });

    _statusSubscription = _socketService.statusStream.listen((data) {
      _socketService.getLeaderboard();
    });

    _deleteSubscription = _socketService.questionDeletedStream.listen((questionId) async {
      await DatabaseService().deleteQuestion(questionId);
      if (mounted) setState(() {});
    });

    _roleSubscription = _socketService.roleUpdatedStream.listen((newRole) {
      if (mounted) {
        _fetchStudentData(); // Re-fetch to update UI badges/permissions
        NotificationService.showNotification(
          id: 100,
          title: 'تحديث الرتبة',
          body: 'تم تغيير رتبتك إلى: $newRole',
        );
      }
    });

    _bannedSubscription = _socketService.bannedStream.listen((data) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BannedScreen(
              reason: data['reason'] ?? 'مخالفة سياسات التطبيق',
              expiresAt: data['expiresAt'] != null ? DateTime.tryParse(data['expiresAt']) : null,
            ),
          ),
          (route) => false,
        );
      }
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Clear local database to prevent data leakage between sessions
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

  void _loadSettings() async {
    _selectedAlgo = await CryptoHelper.getSelectedAlgorithm();
    if (mounted) setState(() {});
  }

  void _showEncryptionSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إعدادات التشفير العالمي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                value: CryptoHelper.ALGO_AES,
                groupValue: _selectedAlgo,
                title: const Text('AES (افتراضي - قوي)'),
                onChanged: (val) async {
                  if (val != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('encryption_algorithm', val);
                    CryptoHelper.updateCache(val);
                    setDialogState(() => _selectedAlgo = val);
                    setState(() {});
                  }
                },
              ),
              RadioListTile<int>(
                value: CryptoHelper.ALGO_SALSA20,
                groupValue: _selectedAlgo,
                title: const Text('Salsa20 (سريع)'),
                onChanged: (val) async {
                  if (val != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('encryption_algorithm', val);
                    CryptoHelper.updateCache(val);
                    setDialogState(() => _selectedAlgo = val);
                    setState(() {});
                  }
                },
              ),
              RadioListTile<int>(
                value: CryptoHelper.ALGO_FERNET,
                groupValue: _selectedAlgo,
                title: const Text('Fernet (أمان عالي)'),
                onChanged: (val) async {
                  if (val != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('encryption_algorithm', val);
                    CryptoHelper.updateCache(val);
                    setDialogState(() => _selectedAlgo = val);
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchStudentData() async {
    final data = await ApiService.getProfile(widget.myUserId);
    if (mounted && data != null) {
      setState(() {
        _studentData = data;
        myPoints = data['points'] ?? 0;
      });
    }
  }

  Future<void> _updateStudentImage(bool isProfile) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final String? url = await ApiService.uploadFile(image.path, widget.myUserId);
      if (url != null) {
        final updatedData = await ApiService.updateProfile({
          'studentId': widget.myUserId,
          isProfile ? 'profileImage' : 'backgroundImage': url,
        });
        if (updatedData != null) {
          setState(() {
            _studentData = updatedData;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 700;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: isMobile ? AppBar(
            backgroundColor: const Color(0xFF4A6572),
            elevation: 0,
            title: const Text('PLATFORM EDU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [_buildPointsBadge(), const SizedBox(width: 10)],
          ) : null,
          drawer: isMobile ? _buildDrawer() : null,
          bottomNavigationBar: isMobile ? _buildBottomNav() : null,
          floatingActionButton: isMobile && _selectedIndex == 0 && widget.myUserId != 'guest'
              ? FloatingActionButton(
                  backgroundColor: const Color(0xFFD4AF37),
                  onPressed: () => _showCreateQuestionDialog(),
                  child: const Icon(Icons.add, color: Colors.black),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile) _buildSidebar(constraints.maxWidth < 1100),
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile) _buildDesktopHeader(),
                    Expanded(child: _buildMainContent()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPointsBadge() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, color: colorScheme.tertiary, size: 18),
          const SizedBox(width: 8),
          Text(
            '$myPoints نقطة',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Cairo'
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDesktopHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              color: colorScheme.onSurface,
              fontFamily: 'Cairo'
            ),
          ),
          const Spacer(),
          _buildPointsBadge(),
          if (widget.myUserId != 'guest') ...[
            const SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreateQuestionDialog(),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('سؤال جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }


  String _getPageTitle() {
    return ['الرئيسية', 'الفيديوهات', 'المكتبة', 'المتصدرين', 'حسابي', 'المحادثات', 'أسئلتي', 'الإعدادات', 'لوحة الإدارة'][_selectedIndex];
  }

  bool get _isAdmin {
    // التحقق المطلق من المعرف STU-527174 - تجاهل المسافات وحالة الأحرف
    final String currentId = widget.myUserId.trim().toUpperCase();
    if (currentId == 'STU-527174') return true;
    
    final String? studentId = _studentData?['studentId']?.toString().trim().toUpperCase();
    if (studentId == 'STU-527174') return true;
    
    final String role = _studentData?['role']?.toString() ?? 'member';
    return role == 'admin' || role == 'assistant_admin';
  }

  Widget _buildSidebar(bool collapsed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: collapsed ? 90 : 280,
      decoration: const BoxDecoration(
        color: Color(0xFF4A6572),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(5, 0)),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarProfile(collapsed),
          const SizedBox(height: 20),
          _buildSidebarItem(0, Icons.dashboard_rounded, 'الرئيسية', collapsed),
          _buildSidebarItem(1, Icons.video_library_rounded, 'الفيديوهات', collapsed),
          _buildSidebarItem(5, Icons.chat_bubble_rounded, 'المحادثات', collapsed),
          _buildSidebarItem(2, Icons.menu_book_rounded, 'المكتبة', collapsed),
          _buildSidebarItem(3, Icons.leaderboard_rounded, 'لوحة الصدارة', collapsed),
          _buildSidebarItem(6, Icons.live_help_rounded, 'أسئلتي', collapsed),
          _buildSidebarItem(4, Icons.person_rounded, 'حسابي', collapsed),
          if (_isAdmin)
            _buildSidebarItem(8, Icons.admin_panel_settings_rounded, 'لوحة الإدارة', collapsed),
          const Spacer(),
          _buildSidebarItem(9, Icons.logout_rounded, 'تسجيل الخروج', collapsed),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSidebarProfile(bool collapsed) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileImage = _studentData?['profileImage'];
    final backgroundImage = _studentData?['backgroundImage'];
    final role = _studentData?['role'] ?? 'member';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: backgroundImage != null
          ? BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(AppConfig.parseMediaUrl(backgroundImage)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(const Color(0xFF4A6572).withValues(alpha: 0.8), BlendMode.srcOver),
              ),
            )
          : null,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.tertiary, width: 2),
                ),
                child: CircleAvatar(
                  radius: collapsed ? 20 : 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: profileImage != null ? NetworkImage(AppConfig.parseMediaUrl(profileImage)) : null,
                  child: profileImage == null
                      ? Text(widget.myUserId[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: collapsed ? 18 : 30,
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo'))
                      : null,
                ),
              ),
              if (!collapsed)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () => _updateStudentImage(true),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: colorScheme.tertiary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          if (!collapsed) ...[
            const SizedBox(height: 15),
            Text(_studentData?['name'] ?? widget.myUserId,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
            Text(_getRoleName(role),
                style: TextStyle(
                    color: role == 'admin' || role == 'assistant_admin' ? const Color(0xFFD4AF37) : colorScheme.tertiary,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _updateStudentImage(false),
              icon: const Icon(Icons.wallpaper, size: 14, color: Colors.white70),
              label: const Text('تغيير الخلفية', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo')),
            ),
          ]
        ],
      ),
    );
  }


  String _getRoleName(String role) {
    if (widget.myUserId.trim().toUpperCase() == 'STU-527174') return 'المدير العام';
    switch (role) {
      case 'admin': return 'المدير العام';
      case 'assistant_admin': return 'مساعد مدير';
      case 'doctor': return 'دكتور';
      case 'teacher': return 'أستاذ';
      case 'premium_member': return 'عضو مميز';
      default: return 'عضو';
    }
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, bool collapsed) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (index == 9) {
          _logout();
          return;
        }
        setState(() => _selectedIndex = index);
        if (index == 3) _socketService.getLeaderboard(); // تحديث لوحة الصدارة عند فتحها
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: collapsed ? 0 : 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) : null,
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon, 
              color: isSelected ? colorScheme.tertiary : Colors.white.withValues(alpha: 0.7), 
              size: 26
            ),
            if (!collapsed) ...[
              const SizedBox(width: 18),
              Text(
                title, 
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7), 
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                  letterSpacing: 0.5
                )
              ),
            ]
          ],
        ),
      ),
    );
  }


  Widget _buildBottomNav() {
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
      const BottomNavigationBarItem(icon: Icon(Icons.video_library_outlined), activeIcon: Icon(Icons.video_library), label: 'الريلز'),
      const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'الدردشات'),
      const BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'المكتبة'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
    ];

    int currentIndex = 0;
    if (_selectedIndex == 0) currentIndex = 0;
    else if (_selectedIndex == 1) currentIndex = 1;
    else if (_selectedIndex == 5) currentIndex = 2;
    else if (_selectedIndex == 2) currentIndex = 3;
    else if (_selectedIndex == 4) currentIndex = 4;
    else currentIndex = 0;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        int targetIndex = 0;
        if (index == 0) targetIndex = 0;
        else if (index == 1) targetIndex = 1;
        else if (index == 2) targetIndex = 5;
        else if (index == 3) targetIndex = 2;
        else if (index == 4) targetIndex = 4;
        
        setState(() => _selectedIndex = targetIndex);
        if (targetIndex == 3) _socketService.getLeaderboard();
      },
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF4A6572),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: items,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF4A6572),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF374F5A)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xFFE0A96D),
              child: Text(widget.myUserId[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white)),
            ),
            accountName: Text(_studentData?['name'] ?? widget.myUserId, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            accountEmail: Text('$myPoints PTS', style: const TextStyle(color: Color(0xFFE0A96D))),
          ),
          if (_isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
              title: const Text('لوحة الإدارة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 8);
              },
            ),
          ListTile(
            leading: const Icon(Icons.live_help_rounded, color: Colors.white70),
            title: const Text(' أسئلتي', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 6);
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')),
            onTap: () => _logout(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0: return _buildHomeFeed();
      case 1: return ReelsScreen(myUserId: widget.myUserId);
      case 2: return LibraryMainScreen(
        myUserId: widget.myUserId, 
        myName: _studentData?['name'] ?? widget.myUserId,
        myRole: _studentData?['role'],
      );
      case 3: return _buildLeaderboard();
      case 4: return ProfileHubScreen(
        myUserId: widget.myUserId,
        studentData: _studentData,
        onLogout: _logout,
        onProfileUpdate: (newData) {
          setState(() => _studentData = newData);
        },
      );
      case 5: return _buildChatList();
      case 6: return _buildMyQuestions();
      case 7: return _buildSettings();
      case 8: return AdminPanelScreen(myUserId: widget.myUserId);
      default: return _buildHomeFeed();
    }
  }

  Widget _buildMyQuestions() {
    return RefreshIndicator(
      onRefresh: _syncQuestionsFromServer,
      child: StreamBuilder<List<Question>>(
        stream: DatabaseService().questionsStream,
        initialData: const [],
        builder: (context, snapshot) {
          final allQuestions = snapshot.data ?? [];
          final myQuestions = allQuestions.where((q) => q.userId == widget.myUserId).toList();
          
          if (myQuestions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.question_mark_rounded, size: 80, color: Color(0xFF8EAC9D)),
                  const SizedBox(height: 20),
                  const Text('لم تقم بطرح أي أسئلة بعد', style: TextStyle(color: Color(0xFF333333), fontSize: 18, fontFamily: 'Cairo')),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showCreateQuestionDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6572),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('اطرح سؤالك الأول', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: myQuestions.length,
            itemBuilder: (context, index) {
              final q = myQuestions[index];
              return DesktopQuestionCard(
                key: ValueKey('mq_${q.id}_${q.answerCount}'),
                question: q,
                myUserId: widget.myUserId,
                onTap: () => _openQuestionDetails(q),
                onAnswer: () => _openQuestionDetails(q),
                onProfileTap: () => _openProfile(q.userId),
                onDelete: () => _socketService.deleteQuestion(q.id!),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaderboard() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_leaderboardData.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _leaderboardData.length,
      itemBuilder: (context, index) {
        final user = _leaderboardData[index];
        final isTop3 = index < 3;
        final rankColors = [colorScheme.tertiary, colorScheme.secondary, colorScheme.primary.withValues(alpha: 0.5)];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isTop3 ? rankColors[index].withValues(alpha: 0.3) : colorScheme.onSurface.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isTop3 ? rankColors[index] : Colors.grey,
                    ),
                  ),
                ),
                Stack(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        image: user['profileImage'] != null ? DecorationImage(
                          image: NetworkImage(AppConfig.parseMediaUrl(user['profileImage'])),
                          fit: BoxFit.cover
                        ) : null,
                      ),
                      child: user['profileImage'] == null ? Center(
                        child: Text(
                          (user['name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ) : null,
                    ),
                    if (user['online'] == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            title: Text(
              user['name'] ?? user['phone'] ?? 'مستخدم',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontFamily: 'Cairo'),
            ),
            subtitle: Text(
              '${user['phone'] ?? ''} • ${(user['points'] ?? 0) > 1000 ? 'طالب متميز' : 'طالب مجتهد'}',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12, fontFamily: 'Cairo'),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${user['points'] ?? 0}',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Cairo'
                  ),
                ),
                Text(
                  'نقطة',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontFamily: 'Cairo'
                  ),
                ),
              ],
            ),
            onTap: () => _openProfile(user['studentId'] ?? user['userId']),
          ),
        );
      },
    );
  }


  Widget _buildSettings() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: colorScheme.surface,
          child: Row(
            children: [
              CachedImage(
                imageUrl: AppConfig.parseMediaUrl(_studentData?['profileImage'] ?? ''),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primaryContainer,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_studentData?['name'] ?? 'طالب', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    Text(_studentData?['phone'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 8),
                    Text('نقطة $myPoints', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(30),
            children: [
              if (_studentData != null)
                _buildSettingsSection('الملف الشخصي', [
                  _buildSettingsTile(
                    Icons.person_outline, 
                    'تعديل البيانات', 
                    'الاسم، الهاتف، الصور',
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileEditScreen(studentData: _studentData!)),
                      );
                      if (updated != null) {
                        setState(() => _studentData = updated);
                      }
                    },
                  ),
                ]),
              const SizedBox(height: 20),
              _buildSettingsSection('الحساب والخصوصية', [
                _buildSettingsTile(Icons.lock_outline, 'تغيير مفتاح التشفير', 'AES-256 Active', onTap: () {}),
                _buildSettingsTile(
                  Icons.fingerprint, 
                  'البصمة الحيوية', 
                  'مفعلة للحماية',
                  onTap: () async {
                    bool authenticated = await BiometricHelper.authenticate();
                    if (authenticated) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحقق بنجاح')));
                    }
                  },
                ),
              ]),
              const SizedBox(height: 20),
              _buildSettingsSection('التطبيق', [
                _buildSettingsTile(
                  Icons.dark_mode_outlined, 
                  'المظهر', 
                  Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark ? 'الوضع الداكن' : 'الوضع الفاتح',
                  onTap: () {
                    final provider = Provider.of<ThemeProvider>(context, listen: false);
                    provider.toggleTheme(provider.themeMode != ThemeMode.dark);
                  },
                ),
                _buildSettingsTile(Icons.language, 'اللغة', 'العربية', onTap: () {}),
              ]),
              const SizedBox(height: 20),
              _buildSettingsSection('حول', [
                _buildSettingsTile(
                  Icons.info_outline,
                  'من نحن',
                  'معلومات المطور والتطبيق',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A6572), fontFamily: 'Cairo')),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF4A6572)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333), fontFamily: 'Cairo')),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildHomeFeed() {
    return RefreshIndicator(
      onRefresh: _syncQuestionsFromServer,
      child: StreamBuilder<List<Question>>(
        stream: DatabaseService().questionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4A6572)),
                  SizedBox(height: 10),
                  Text('جاري تحميل الأسئلة...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('لا توجد أسئلة حالياً', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: _syncQuestionsFromServer,
                    child: const Text('تحديث الصفحة'),
                  )
                ],
              ),
            );
          }
          return _buildQuestionList(questions);
        },
      ),
    );
  }

  Widget _buildQuestionList(List<Question> questions) {
    if (questions.isEmpty) {
      return const Center(child: Text('لا توجد أسئلة حالياً', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return DesktopQuestionCard(
          key: ValueKey('q_${q.id}_${q.answerCount}'),
          question: q,
          myUserId: widget.myUserId,
          onTap: () => _openQuestionDetails(q),
          onAnswer: widget.myUserId == 'guest' ? null : () => _openQuestionDetails(q),
          onProfileTap: () => _openProfile(q.userId),
          onDelete: q.userId == widget.myUserId ? () => _confirmDeleteQuestion(q.id!) : null,
        );
      },
    );
  }

  void _confirmDeleteQuestion(String questionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السؤال؟', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد من حذف هذا السؤال نهائياً؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socketService.deleteQuestion(questionId);
              ApiService.reportActivity(widget.myUserId, 'delete_question');
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isGuest = widget.myUserId == 'guest';
    return Column(
      children: [
        if (!isGuest)
          Padding(
            padding: const EdgeInsets.all(20),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContactListScreen(myUserId: widget.myUserId))),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'بدء محادثة جديدة',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder(
            stream: DatabaseService().getRecentChatsStream(widget.myUserId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              final chats = snapshot.data!;
              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد محادثات سابقة',
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final peerId = chat.isMe ? chat.targetId : chat.senderId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: colorScheme.secondary.withValues(alpha: 0.1),
                        child: Text(
                          (chat.isMe 
                            ? (chat.targetName ?? chat.targetId) 
                            : (chat.senderName ?? chat.senderId))[0].toUpperCase(),
                          style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      title: Text(
                        chat.isMe ? (chat.targetName ?? chat.targetPhone ?? chat.targetId) : (chat.senderName ?? chat.senderPhone ?? chat.senderId),
                        style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontFamily: 'Cairo'),
                      ),
                      subtitle: Text(
                        chat.text.startsWith('[') ? chat.text : CryptoHelper.decrypt(chat.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withValues(alpha: 0.2)),
                      onTap: () => _openChat(peerId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  void _showStartChatDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ابدأ محادثة', style: TextStyle(color: Color(0xFF4A6572), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'أدخل رقم هاتف المستخدم',
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8EAC9D))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4A6572))),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final phone = controller.text.trim();
                final user = await ApiService.findUserByPhone(phone);
                if (user != null && user['studentId'] != widget.myUserId) {
                  Navigator.pop(context);
                  _openChat(user['studentId']);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('المستخدم غير موجود أو هذا رقمك الشخصي')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6572)),
            child: const Text('بدء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openQuestionDetails(Question q) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => QuestionDetailScreen(question: q, myUserId: widget.myUserId)));
  }

  Future<void> _syncQuestionsFromServer() async {
    try {
      final List<dynamic> data = await ApiService.getQuestions();
      final questions = data.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
      await DatabaseService().replaceQuestions(questions);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error syncing questions: $e');
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId, myUserId: widget.myUserId),
      ),
    );
  }

  void _openChat(String targetId) {
    if (targetId == widget.myUserId) return;
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => ChatScreen(userId: widget.myUserId, targetUserId: targetId)
      )
    ).then((_) {
      // Refresh state when coming back from chat
      setState(() {});
    });
  }

  void _showCreateQuestionDialog() {
    final controller = TextEditingController();
    String? selectedFilePath;
    String? mediaType;
    bool isPublishing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('اسأل سؤالاً جديداً', style: TextStyle(color: Color(0xFF4A6572), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 3,
                enabled: !isPublishing,
                style: const TextStyle(color: Color(0xFF333333)),
                decoration: const InputDecoration(
                  hintText: 'اكتب سؤالك هنا...',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8EAC9D))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4A6572))),
                ),
              ),
              const SizedBox(height: 10),
              if (selectedFilePath != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8EAC9D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(mediaType == 'image' ? Icons.image : Icons.insert_drive_file, color: const Color(0xFF8EAC9D), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم اختيار: ${selectedFilePath!.split('/').last}',
                          style: const TextStyle(color: Color(0xFF4A6572), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isPublishing)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 16),
                          onPressed: () => setDialogState(() {
                            selectedFilePath = null;
                            mediaType = null;
                          }),
                        )
                    ],
                  ),
                ),
              if (!isPublishing)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_outlined, color: Color(0xFF4A6572)),
                      tooltip: 'إضافة صورة',
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setDialogState(() {
                            selectedFilePath = image.path;
                            mediaType = 'image';
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file_outlined, color: Color(0xFF4A6572)),
                      tooltip: 'إرفاق ملف',
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();
                        if (result != null && result.files.single.path != null) {
                          setDialogState(() {
                            selectedFilePath = result.files.single.path;
                            mediaType = 'file';
                          });
                        }
                      },
                    ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: Color(0xFF4A6572)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isPublishing ? null : () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
              ElevatedButton(
                onPressed: isPublishing || controller.text.trim().isEmpty
                    ? null
                    : () async {
                        setDialogState(() => isPublishing = true);
                        try {
                          String? uploadedUrl;
                          if (selectedFilePath != null) {
                            uploadedUrl =
                                await ApiService.uploadFile(selectedFilePath!, widget.myUserId).timeout(const Duration(seconds: 30));

                            if (uploadedUrl == null) {
                              throw Exception('فشل رفع الملف. يرجى المحاولة مرة أخرى.');
                            }
                          }

                          _socketService.postQuestion(controller.text.trim(), mediaUrls: uploadedUrl != null ? [uploadedUrl] : null);

                          // Run activity reporting in background
                          ApiService.reportActivity(widget.myUserId, 'post_question');

                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() => isPublishing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: ${e.toString().replaceAll('Exception: ', '')}')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6572)),
                child: Text(isPublishing ? 'جاري النشر...' : 'نشر', style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

}
