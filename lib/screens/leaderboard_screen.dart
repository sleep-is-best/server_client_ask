import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final String myUserId;
  const LeaderboardScreen({super.key, required this.myUserId});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getLeaderboard();
      setState(() {
        _users = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الصدارة', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final rank = index + 1;
                  
                  Color? rankColor;
                  if (rank == 1) rankColor = Colors.amber;
                  else if (rank == 2) rankColor = Colors.grey[400];
                  else if (rank == 3) rankColor = Colors.brown[300];

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: user['studentId'] == widget.myUserId 
                          ? AppColors.primary.withValues(alpha: 0.1) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              myUserId: widget.myUserId,
                              userId: user['studentId'],
                            ),
                          ),
                        );
                      },
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            alignment: Alignment.center,
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rankColor ?? AppColors.textSecondary,
                                fontSize: rank <= 3 ? 20 : 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          UserAvatar(
                            name: user['name'] ?? '',
                            imageUrl: user['profileImage'],
                          ),
                        ],
                      ),
                      title: Text(
                        user['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      subtitle: Text('${user['points'] ?? 0} نقطة'),
                      trailing: rank <= 3 
                        ? Icon(Icons.emoji_events, color: rankColor)
                        : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
