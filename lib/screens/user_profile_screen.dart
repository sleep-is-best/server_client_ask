import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/primary_button.dart';
import '../models/reel.dart';
import '../config.dart';
import 'settings_screen.dart';
import 'reels_screen.dart';
import 'chat_screen.dart';

import 'storage_management_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String myUserId;

  const UserProfileScreen({super.key, required this.userId, required this.myUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  List<dynamic> _questions = [];
  List<dynamic> _answers = [];
  List<dynamic> _reels = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getProfile(widget.userId),
      ApiService.getMyQuestions(widget.userId),
      ApiService.getStudentAnswers(widget.userId),
      ApiService.getReels(widget.myUserId, type: 'user', userId: widget.userId),
    ]);

    if (mounted) {
      setState(() {
        _userData = results[0] as Map<String, dynamic>?;
        _questions = results[1] as List<dynamic>;
        _answers = results[2] as List<dynamic>;
        _reels = results[3] as List<dynamic>;
        
        if (_userData != null && _userData!['followers'] != null) {
          _isFollowing = (_userData!['followers'] as List).contains(widget.myUserId);
        }
        
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.myUserId == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول للمتابعة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final success = _isFollowing 
        ? await ApiService.unfollowUser(widget.myUserId, widget.userId)
        : await ApiService.followUser(widget.myUserId, widget.userId);
    
    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        // Optionally update followers count locally if you display it
      });
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
            title: const Text('إبلاغ عن هذا المستخدم', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.pop(context);
              _showReportDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_flipped, color: Colors.red),
            title: const Text('حظر المستخدم', style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showBlockDialog();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إبلاغ', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'سبب الإبلاغ...', hintStyle: TextStyle(fontFamily: 'Cairo')),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                final success = await ApiService.submitReport(widget.myUserId, 'user', widget.userId, reasonController.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'تم إرسال البلاغ بنجاح' : 'فشل إرسال البلاغ')));
                }
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حظر مستخدم', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد أنك تريد حظر هذا المستخدم؟ لن تتمكن من رؤية محتواه أو مراسلته.', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ApiService.blockUser(widget.myUserId, widget.userId);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  Navigator.pop(context); // Close profile screen
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر المستخدم')));
                }
              }
            },
            child: const Text('حظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMe = widget.userId == widget.myUserId;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي')),
        body: const Center(child: Text('تعذر العثور على بيانات المستخدم')),
      );
    }

    final profileImage = _userData!['profileImage'];
    final backgroundImage = _userData!['backgroundImage'];
    final name = _userData!['name'] ?? 'مستخدم';
    final points = _userData!['points'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isMe) ...[
                IconButton(
                  icon: const Icon(Icons.storage_rounded, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StorageManagementScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen(myUserId: widget.myUserId)),
                    );
                  },
                ),
              ],
              if (!isMe)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showOptions(context),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: backgroundImage != null && backgroundImage.isNotEmpty
                  ? Image.network(AppConfig.parseMediaUrl(backgroundImage), fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 70),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          _userData!['phone'] ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'النقاط',
                                value: points.toString(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: StatCard(
                                label: 'الرتبة',
                                value: _getRank(points),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (!isMe) ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PrimaryButton(
                                  text: _isFollowing ? 'متابع' : 'متابعة',
                                  onPressed: _toggleFollow,
                                  color: _isFollowing ? AppColors.secondary : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    if (widget.myUserId == 'guest') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('يجب تسجيل الدخول للمراسلة', style: TextStyle(fontFamily: 'Cairo')),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ChatScreen(userId: widget.myUserId, targetUserId: widget.userId)),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'عن الطالب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          margin: EdgeInsets.zero,
                          child: Text(
                            _userData!['bio'] ?? 'عضو نشط في المنصة التعليمية. يساهم في حل الأسئلة ومساعدة زملائه.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.6,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildActivityTabs(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: UserAvatar(
                      name: name,
                      imageUrl: profileImage,
                      radius: 55,
                      showBorder: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            tabs: [
              Tab(text: 'الريلز'),
              Tab(text: 'الأسئلة'),
              Tab(text: 'الإجابات'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _buildReelsGrid(),
                _buildActivityList(_questions, 'لم يقم بطرح أي أسئلة', Icons.help_outline),
                _buildActivityList(_answers, 'لم يقم بتقديم أي إجابات', Icons.comment_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelsGrid() {
    if (_reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('لم يقم بنشر أي ريلز بعد', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reelData = _reels[index];
        final reel = Reel.fromMap(reelData);
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelsScreen(
                  myUserId: widget.myUserId,
                  initialReels: _reels.map((e) => Reel.fromMap(e)).toList(),
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              image: reel.thumbnail != null && reel.thumbnail!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(AppConfig.parseMediaUrl(reel.thumbnail!)), fit: BoxFit.cover)
                  : null,
            ),
            child: Stack(
              children: [
                if (reel.thumbnail == null || reel.thumbnail!.isEmpty)
                  const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 30)),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${reel.views}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityList(List<dynamic> items, String emptyMsg, IconData emptyIcon) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(emptyMsg, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isQuestion = item.containsKey('points');
        
        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['timestamp'] != null 
                          ? DateTime.parse(item['timestamp']).toString().substring(0, 16)
                          : '',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              if (isQuestion) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item['points']} نقطة',
                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getRank(int points) {
    if (points > 5000) return 'خبير';
    if (points > 2000) return 'مميز';
    if (points > 1000) return 'مجتهد';
    return 'مبتدئ';
  }
}
