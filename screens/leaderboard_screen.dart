import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  final String myUserId;

  const LeaderboardScreen({
    super.key,
    required this.myUserId,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with AutomaticKeepAliveClientMixin {
  List<dynamic> _leaders = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final data = await ApiService.getLeaderboard();

    if (!mounted) return;

    final sorted = List<dynamic>.from(data)
      ..sort((a, b) => _getPoints(b).compareTo(_getPoints(a)));

    setState(() {
      _leaders = sorted.take(50).toList();
      _isLoading = false;
    });
  }

  int _getPoints(dynamic user) {
    if (user is! Map) return 0;

    final value = user['points'] ?? user['score'] ?? 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _getUserName(dynamic user) {
    if (user is! Map) return 'مستخدم';
    return user['name'] ?? user['phone'] ?? 'مستخدم';
  }

  String _getUserImage(dynamic user) {
    if (user is! Map) return '';
    return user['profileImage']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'الصدارة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadLeaderboard,
                color: AppColors.primary,
                child: _leaders.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد نقاط حتى الآن',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _leaders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _leaders[index];
                          final rank = index + 1;
                          final points = _getPoints(user);
                          final isTop3 = rank <= 3;
                          final colors = [
                            const Color(0xFFFFD54F),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ];

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isTop3
                                    ? colors[rank - 1].withValues(alpha: 0.4)
                                    : AppColors.border,
                                width: 1,
                              ),
                              boxShadow: AppColors.softShadow,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    '#$rank',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isTop3 ? colors[rank - 1] : AppColors.textSecondary,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                UserAvatar(
                                  name: _getUserName(user),
                                  imageUrl: _getUserImage(user),
                                  radius: 24,
                                  showBorder: isTop3,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getUserName(user),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.stars_rounded,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$points نقطة',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.myUserId == (user['studentId'] ?? user['id'] ?? ''))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'أنت',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                      ),
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
