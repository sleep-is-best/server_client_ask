import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<NotificationResponse> onNotificationClick =
      StreamController<NotificationResponse>.broadcast();

  static Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onNotificationClick.add(response);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create a notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'This channel is used for chat message notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      print("Notification init error: $e");
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
    bool isCall = false,
  }) async {
    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'This channel is used for chat message notifications.',
        importance: Importance.max,
        priority: Priority.high,
        actions: actions,
        fullScreenIntent: isCall,
        category: isCall ? AndroidNotificationCategory.call : null,
        ongoing: isCall,
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      print("Error cancelling notification: $e");
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      print("Error cancelling all notifications: $e");
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background notification tap
  if (notificationResponse.actionId == 'decline_call') {
    // We can't easily communicate back to the background service from here 
    // without using another mechanism like method channels or a shared database/prefs.
    // However, the background service is already running a socket.
    // A better way is to invoke a method that the background service can pick up.
  }
}
