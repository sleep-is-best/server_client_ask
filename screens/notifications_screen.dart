import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  final String myUserId;
  const NotificationsScreen({super.key, required this.myUserId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // In a real app, these would come from a service/database
  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'answer',
      'title': 'إجابة جديدة',
      'body': 'قام أحمد بالرد على سؤالك في مادة الرياضيات.',
      'time': 'منذ ٥ دقائق',
      'isRead': false,
      'senderName': 'أحمد محمد',
    },
    {
      'type': 'like',
      'title': 'إعجاب جديد',
      'body': 'أعجب سارة بالريل الذي قمت بنشره مؤخراً.',
      'time': 'منذ ساعة',
      'isRead': true,
      'senderName': 'سارة علي',
    },
    {
      'type': 'points',
      'title': 'نقاط إضافية',
      'body': 'لقد حصلت على ١٠ نقاط لاختيار إجابتك كأفضل إجابة!',
      'time': 'منذ ساعتين',
      'isRead': true,
      'senderName': 'النظام',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.myUserId == 'guest') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('التنبيهات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off_outlined, size: 80, color: AppColors.textHint.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                'يجب تسجيل الدخول لرؤية التنبيهات',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التنبيهات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
            },
            child: const Text('تحديد الكل كمقروء', style: TextStyle(color: AppColors.primary, fontFamily: 'Cairo', fontSize: 12)),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.zero,
      color: isRead ? AppColors.surface : AppColors.primary.withOpacity(0.05),
      onTap: () {},
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(
          name: notification['senderName'] ?? 'U',
          radius: 24,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification['title'] ?? '',
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Text(
              notification['time'] ?? '',
              style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontFamily: 'Cairo'),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            notification['body'] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
              fontFamily: 'Cairo',
              height: 1.4,
            ),
          ),
        ),
        trailing: !isRead 
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: AppColors.textHint.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد تنبيهات حالياً',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}
