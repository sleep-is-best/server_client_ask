import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../config.dart';
import 'profile_edit_screen.dart';
import 'about_us_screen.dart';
import 'user_list_screen.dart';
import 'activity_timeline_screen.dart';
import 'leaderboard_screen.dart';
import 'bookmarks_screen.dart';
import 'dart:async';

class ProfileHubScreen extends StatefulWidget {
  final String myUserId;
  final Map<String, dynamic>? studentData;
  final VoidCallback onLogout;
  final Function(Map<String, dynamic>) onProfileUpdate;

  const ProfileHubScreen({
    super.key,
    required this.myUserId,
    this.studentData,
    required this.onLogout,
    required this.onProfileUpdate,
  });

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  StreamSubscription? _pointsSubscription;

  @override
  void initState() {
    super.initState();
    _data = widget.studentData;
    if (_data == null) {
      _refreshData();
    }
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _pointsSubscription = SocketService().pointsStream.listen((event) {
      if (mounted && event['points'] != null) {
        setState(() {
          if (_data != null) {
            _data!['points'] = event['points'];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final newData = await ApiService.getProfile(widget.myUserId);
    if (mounted && newData != null) {
      setState(() {
        _data = newData;
        _isLoading = false;
      });
      widget.onProfileUpdate(newData);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGuest = widget.myUserId == 'guest';

    if (_isLoading && _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(colorScheme),
              const SizedBox(height: 24),
              _buildStatsRow(colorScheme),
              const SizedBox(height: 24),
              _buildActionsList(colorScheme, isGuest),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final name = _data?['name'] ?? (widget.myUserId == 'guest' ? 'زائر' : widget.myUserId);
    final phone = _data?['phone'] ?? '';
    final profileImage = _data?['profileImage'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF4A6572).withValues(alpha: 0.1),
            backgroundImage: profileImage != null ? NetworkImage(AppConfig.parseMediaUrl(profileImage)) : null,
            child: profileImage == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4A6572)))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                if (phone.isNotEmpty)
                  Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                if (widget.myUserId != 'guest')
                  ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileEditScreen(studentData: _data!)),
                      );
                      if (updated != null) {
                        _refreshData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6572),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('تعديل الحساب', style: TextStyle(fontFamily: 'Cairo')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme colorScheme) {
    final points = _data?['points'] ?? 0;
    final followers = _data?['followers'] as List? ?? [];
    final following = _data?['following'] as List? ?? [];

    return Row(
      children: [
        _buildStatCard('النقاط', points.toString(), Icons.stars, const Color(0xFFD4AF37), 
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(myUserId: widget.myUserId),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'متابِعون',
          followers.length.toString(),
          Icons.people_outline,
          const Color(0xFF4A6572),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserListScreen(
                title: 'المتابِعون',
                userIds: List<String>.from(followers),
                myUserId: widget.myUserId,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'متابَعون',
          following.length.toString(),
          Icons.person_add_outlined,
          const Color(0xFF8EAC9D),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserListScreen(
                title: 'المتابَعون',
                userIds: List<String>.from(following),
                myUserId: widget.myUserId,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsList(ColorScheme colorScheme, bool isGuest) {
    return Column(
      children: [
        if (!isGuest) ...[
          _buildActionTile(
            icon: Icons.history,
            title: 'سجل النشاط والسمعة',
            subtitle: 'تتبع نقاطك وإنجازاتك',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityTimelineScreen(studentId: widget.myUserId),
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.bookmark_outline,
            title: 'محفوظاتي',
            subtitle: 'الأسئلة والملفات المحفوظة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookmarksScreen(myUserId: widget.myUserId),
              ),
            ),
          ),
        ],
        _buildActionTile(
          icon: Icons.help_outline,
          title: 'المساعدة والدعم',
          subtitle: 'تواصل معنا ، الأسئلة الشائعة',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen())),
        ),
        _buildActionTile(
          icon: Icons.info_outline,
          title: 'حول المنصة',
          subtitle: 'الإصدار 1.0.2 • سياسة الخصوصية',
          onTap: () {},
        ),
        if (!isGuest) ...[
          const SizedBox(height: 20),
          _buildActionTile(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            subtitle: 'سيتم مسح الجلسة الحالية',
            color: Colors.redAccent,
            onTap: _confirmLogout,
          ),
        ] else ...[
          const SizedBox(height: 20),
          _buildActionTile(
            icon: Icons.login_rounded,
            title: 'تسجيل الدخول',
            subtitle: 'للحصول على كامل المميزات',
            color: const Color(0xFF4A6572),
            onTap: widget.onLogout,
          ),
        ],
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF4A6572)).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? const Color(0xFF4A6572)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
