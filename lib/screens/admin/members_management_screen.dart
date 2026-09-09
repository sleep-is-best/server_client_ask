import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../user_profile_screen.dart';
import '../../config.dart';

class MembersManagementScreen extends StatefulWidget {
  final String myUserId;
  const MembersManagementScreen({super.key, required this.myUserId});

  @override
  State<MembersManagementScreen> createState() => _MembersManagementScreenState();
}

class _MembersManagementScreenState extends State<MembersManagementScreen> {
  List<dynamic> members = [];
  List<dynamic> filteredMembers = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadMoreRunning = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredMembers = members.where((m) {
        final name = m['name']?.toString().toLowerCase() ?? '';
        final phone = m['phone']?.toString().toLowerCase() ?? '';
        final query = _searchController.text.toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadMoreRunning &&
        _hasMore &&
        _searchController.text.isEmpty) {
      _loadMoreMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final data = await ApiService.getAdminMembers(widget.myUserId, page: 1);
    if (mounted) {
      setState(() {
        members = data;
        filteredMembers = data;
        isLoading = false;
        if (data.length < 20) _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreMembers() async {
    setState(() => _isLoadMoreRunning = true);
    _currentPage++;
    final data = await ApiService.getAdminMembers(widget.myUserId, page: _currentPage);
    if (mounted) {
      if (data.isNotEmpty) {
        setState(() {
          members.addAll(data);
          filteredMembers = members;
          if (data.length < 20) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
      setState(() => _isLoadMoreRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);
    const darkBg = Color(0xFF0A0A0A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          title: const Text('إدارة الأعضاء', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو رقم الهاتف...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo'),
                  prefixIcon: const Icon(Icons.search, color: goldColor),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: goldColor))
                  : filteredMembers.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadMembers,
                          color: goldColor,
                          child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredMembers.length + (_isLoadMoreRunning ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredMembers.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(color: goldColor)),
                              );
                            }
                            return _buildMemberCard(filteredMembers[index]);
                          },
                        ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text('لا يوجد أعضاء حالياً', style: TextStyle(color: Colors.white70, fontSize: 18, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final bool isOnline = member['online'] ?? false;
    final bool isBanned = member['isBanned'] ?? false;
    final String role = member['role'] ?? 'member';
    final String studentId = member['studentId'] ?? '';
    final String phone = member['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: isBanned ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF333333),
              backgroundImage: member['profileImage'] != null ? NetworkImage(AppConfig.parseMediaUrl(member['profileImage'])) : null,
              child: member['profileImage'] == null ? Text(member['name']?[0] ?? '?', style: const TextStyle(color: Colors.white, fontSize: 20)) : null,
            ),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(member['name'] ?? 'بدون اسم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'))),
                _buildRoleBadge(role, studentId),
              ],
            ),
            const SizedBox(height: 4),
            Text(phone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Icon(Icons.stars, color: const Color(0xFFD4AF37), size: 14),
              const SizedBox(width: 4),
              Text('${member['points'] ?? 0} نقطة', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo')),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.white70),
          onPressed: () => _showMemberActions(member),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, String studentId) {
    Color color = Colors.grey;
    String label = 'عضو';
    if (studentId == 'STU-527174') {
      color = const Color(0xFFD4AF37); label = 'المدير العام';
    } else {
      switch (role) {
        case 'admin': color = const Color(0xFFD4AF37); label = 'مدير'; break;
        case 'assistant_admin': color = Colors.blue; label = 'مساعد'; break;
        case 'teacher': color = Colors.orange; label = 'أستاذ'; break;
        case 'doctor': color = Colors.purple; label = 'دكتور'; break;
        case 'premium_member': color = Colors.amber; label = 'مميز'; break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  void _showMemberActions(Map<String, dynamic> member) {
    final bool isMainAdmin = member['studentId'] == 'STU-527174';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(member['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const Divider(color: Colors.white12, height: 30),
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.blue),
                title: const Text('عرض الملف الشخصي', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: member['studentId'], myUserId: widget.myUserId)));
                },
              ),
              if (!isMainAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.edit_attributes, color: Colors.amber),
                  title: const Text('تغيير الرتبة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  onTap: () { Navigator.pop(context); _showRolePicker(member); },
                ),
                ListTile(
                  leading: Icon(member['isBanned'] == true ? Icons.check_circle : Icons.block, color: member['isBanned'] == true ? Colors.green : Colors.red),
                  title: Text(member['isBanned'] == true ? 'إلغاء الحظر' : 'حظر العضو', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  onTap: () {
                    Navigator.pop(context);
                    if (member['isBanned'] == true) {
                      _unbanMember(member['studentId']);
                    } else {
                      _showBanDialog(member);
                    }
                  },
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('هذا الحساب محمي كمدير عام', style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRolePicker(Map<String, dynamic> member) {
    final roles = [
      {'id': 'member', 'name': 'عضو'},
      {'id': 'premium_member', 'name': 'مميز'},
      {'id': 'teacher', 'name': 'أستاذ'},
      {'id': 'doctor', 'name': 'دكتور'},
      {'id': 'assistant_admin', 'name': 'مساعد مدير'},
      {'id': 'admin', 'name': 'مدير'},
    ];
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('اختر الرتبة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((r) => ListTile(
              title: Text(r['name']!, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
              trailing: member['role'] == r['id'] ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () async {
                Navigator.pop(context);
                final success = await ApiService.promoteMember(widget.myUserId, member['studentId'], r['id']!);
                if (success) { _loadMembers(); _showSnackBar('تم تحديث الرتبة بنجاح'); }
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _unbanMember(String targetId) async {
    final success = await ApiService.unbanMember(widget.myUserId, targetId);
    if (success) { _loadMembers(); _showSnackBar('تم فك الحظر'); }
  }

  void _showBanDialog(Map<String, dynamic> member) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('حظر عضو', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'سبب الحظر...', hintStyle: TextStyle(color: Colors.grey)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final success = await ApiService.banMember(widget.myUserId, member['studentId'], reasonController.text, 'permanent');
                if (success) { _loadMembers(); _showSnackBar('تم حظر العضو'); }
              },
              child: const Text('حظر'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))));
  }
}
