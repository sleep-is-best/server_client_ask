import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final List<String> userIds;
  final String myUserId;

  const UserListScreen({
    super.key,
    required this.title,
    required this.userIds,
    required this.myUserId,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final phone = (user['phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    for (String id in widget.userIds) {
      final profile = await ApiService.getProfile(id);
      if (profile != null) {
        _users.add(profile);
      }
    }
    if (mounted) {
      setState(() {
        _filteredUsers = List.from(_users);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث عن مستخدم...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty ? 'لا يوجد مستخدمون' : 'لم يتم العثور على نتائج',
                    style: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: user['studentId'],
                              myUserId: widget.myUserId,
                            ),
                          ),
                        );
                      },
                      leading: UserAvatar(
                        name: user['name'] ?? '',
                        imageUrl: user['profileImage'],
                        radius: 20,
                      ),
                      title: Text(
                        user['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      subtitle: Text(
                        user['phone'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    );
                  },
                ),
    );
  }
}
