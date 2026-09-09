import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_card.dart';

class NotificationsScreen extends StatefulWidget {
  final String myUserId;
  const NotificationsScreen({super.key, required this.myUserId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SocketService _socketService = SocketService();
  List<dynamic> _notifications = [];
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _newNotificationSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.myUserId != 'guest') {
      _setupListeners();
      _socketService.getNotifications();
    }
  }

  void _setupListeners() {
    _notificationsSubscription = _socketService.notificationsListStream.listen((data) {
      if (mounted) {
        setState(() {
          _notifications = data;
          // Sort by timestamp descending
          _notifications.sort((a, b) {
            final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
            final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
        });
      }
    });

    _newNotificationSubscription = _socketService.notificationStream.listen((notif) {
      if (mounted) {
        setState(() {
          // Remove if already exists (sync by id)
          _notifications.removeWhere((n) => n['id'] == notif['id']);
          _notifications.insert(0, notif);
        });
      }
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _newNotificationSubscription?.cancel();
    super.dispose();
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';
    
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

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
              Icon(Icons.notifications_off_outlined, size: 80, color: AppColors.textHint.withValues(alpha: 0.3)),
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
          if (_notifications.any((n) => !(n['isRead'] ?? false)))
            TextButton(
              onPressed: () {
                for (var n in _notifications) {
                  if (!(n['isRead'] ?? false)) {
                    _socketService.markNotificationRead(n['id']);
                  }
                }
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
      body: RefreshIndicator(
        onRefresh: () async {
          _socketService.getNotifications();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: _notifications.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _buildNotificationItem(notification);
                },
              ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.zero,
      color: isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.05),
      onTap: () {
        if (!isRead) {
          _socketService.markNotificationRead(notification['id']);
          setState(() {
            notification['isRead'] = true;
          });
        }
        // Handle navigation based on type
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification['type']).withValues(alpha: 0.1),
          child: Icon(_getNotificationIcon(notification['type']), color: _getNotificationColor(notification['type']), size: 20),
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
              _getTimeAgo(notification['timestamp']),
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

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'summary_approved': return Icons.check_circle_outline;
      case 'summary_rejected': return Icons.error_outline;
      case 'summary_pending': return Icons.hourglass_empty;
      case 'message': return Icons.chat_outlined;
      case 'audio_call': return Icons.call;
      case 'video_call': return Icons.videocam;
      default: return Icons.notifications_none;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'summary_approved': return Colors.green;
      case 'summary_rejected': return Colors.red;
      case 'summary_pending': return Colors.orange;
      case 'message': return AppColors.primary;
      case 'audio_call': return Colors.blue;
      case 'video_call': return Colors.purple;
      default: return AppColors.textHint;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: AppColors.textHint.withValues(alpha: 0.3)),
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
