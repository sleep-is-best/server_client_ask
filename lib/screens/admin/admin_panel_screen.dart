import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('لوحة الإدارة', 
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : RefreshIndicator(
                onRefresh: _loadStats,
                color: colorScheme.primary,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderStats(colorScheme),
                      const SizedBox(height: 32),
                      Text(
                        'التحكم والإدارة',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuGrid(colorScheme),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderStats(ColorScheme colorScheme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('الأعضاء', stats?['totalMembers']?.toString() ?? '0', Icons.people_rounded, Colors.blue, colorScheme),
        _buildStatCard('متصل الآن', stats?['onlineMembers']?.toString() ?? '0', Icons.online_prediction_rounded, Colors.green, colorScheme),
        _buildStatCard('الأسئلة', stats?['questionsCount']?.toString() ?? '0', Icons.quiz_rounded, colorScheme.primary, colorScheme),
        _buildStatCard('الريلز', stats?['reelsCount']?.toString() ?? '0', Icons.video_collection_rounded, Colors.redAccent, colorScheme),
        _buildStatCard('البلاغات', stats?['reportsCount']?.toString() ?? '0', Icons.report_gmailerrorred_rounded, Colors.orange, colorScheme),
        _buildStatCard('طلبات النشر', stats?['pendingMaterialsCount']?.toString() ?? '0', Icons.pending_actions_rounded, Colors.cyan, colorScheme),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          Text(title, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(ColorScheme colorScheme) {
    final items = [
      {'title': 'إدارة الأعضاء', 'icon': Icons.manage_accounts_rounded, 'screen': MembersManagementScreen(myUserId: widget.myUserId)},
      {'title': 'البلاغات', 'icon': Icons.gavel_rounded, 'screen': ReportsManagementScreen(myUserId: widget.myUserId)},
      {'title': 'إدارة الأسئلة', 'icon': Icons.question_answer_rounded, 'screen': QuestionManagementScreen(myUserId: widget.myUserId)},
      {'title': 'إدارة الريلز', 'icon': Icons.movie_filter_rounded, 'screen': ReelManagementScreen(myUserId: widget.myUserId)},
      {'title': 'مراجعة المواد', 'icon': Icons.library_books_rounded, 'screen': AdminModerationScreen(adminId: widget.myUserId)},
      {'title': 'سجل العمليات', 'icon': Icons.history_edu_rounded, 'screen': AdminLogsScreen(myUserId: widget.myUserId)},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'] as IconData, color: colorScheme.primary, size: 24),
            ),
            title: Text(
              item['title'] as String,
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.onSurface.withValues(alpha: 0.2), size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'] as Widget)),
          ),
        );
      },
    );
  }
}
