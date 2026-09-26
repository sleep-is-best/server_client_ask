import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_card.dart';
import 'members_management_screen.dart';
import 'reports_management_screen.dart';
import 'admin_logs_screen.dart';
import 'question_management_screen.dart';
import 'reel_management_screen.dart';
import '../library/admin_moderation_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final String myUserId;
  const AdminPanelScreen({super.key, required this.myUserId});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  Map<String, dynamic>? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => isLoading = true);
    final data = await ApiService.getAdminStats(widget.myUserId);
    if (mounted) {
      setState(() {
        stats = data;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'لوحة الإدارة',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadStats,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderStats(),
                      const SizedBox(height: 28),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'التحكم والإدارة',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildMenuGrid(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('الأعضاء', stats?['totalMembers']?.toString() ?? '0', Icons.people_rounded, Colors.blue),
        _buildStatCard('متصل الآن', stats?['onlineMembers']?.toString() ?? '0', Icons.online_prediction_rounded, Colors.green),
        _buildStatCard('الأسئلة', stats?['questionsCount']?.toString() ?? '0', Icons.quiz_rounded, AppColors.primary),
        _buildStatCard('الريلز', stats?['reelsCount']?.toString() ?? '0', Icons.video_collection_rounded, Colors.redAccent),
        _buildStatCard('البلاغات', stats?['reportsCount']?.toString() ?? '0', Icons.report_gmailerrorred_rounded, Colors.orange),
        _buildStatCard('طلبات النشر', stats?['pendingMaterialsCount']?.toString() ?? '0', Icons.pending_actions_rounded, Colors.cyan),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final items = [
      {'title': 'إدارة الأعضاء', 'icon': Icons.manage_accounts_rounded, 'screen': MembersManagementScreen(myUserId: widget.myUserId)},
      {'title': 'البلاغات', 'icon': Icons.gavel_rounded, 'screen': ReportsManagementScreen(myUserId: widget.myUserId)},
      {'title': 'إدارة الأسئلة', 'icon': Icons.question_answer_rounded, 'screen': QuestionManagementScreen(myUserId: widget.myUserId)},
      {'title': 'إدارة الريلز', 'icon': Icons.movie_filter_rounded, 'screen': ReelManagementScreen(myUserId: widget.myUserId)},
      {'title': 'مراجعة المواد', 'icon': Icons.library_books_rounded, 'screen': AdminModerationScreen(adminId: widget.myUserId)},
      {'title': 'سجل العمليات', 'icon': Icons.history_edu_rounded, 'screen': AdminLogsScreen(myUserId: widget.myUserId)},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          margin: EdgeInsets.zero,
          borderRadius: 18,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'] as Widget)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'] as IconData, color: AppColors.primary, size: 22),
            ),
            title: Text(
              item['title'] as String,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textHint,
              size: 16,
            ),
          ),
        );
      },
    );
  }
}
