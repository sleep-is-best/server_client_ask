import 'package:flutter/material.dart';
import 'config.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'models/message.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'utils/app_theme.dart';

import 'utils/error_handler.dart';
import 'utils/crypto_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

final dbService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Do not block the first Flutter frame on optional background services.
  // SplashScreen performs the bounded initialization and handles failures.
  ErrorHandler.init().catchError((error, stackTrace) {
    debugPrint('Error logger initialization failed: $error');
    debugPrint(stackTrace.toString());
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'chat_messages',
      initialNotificationTitle: 'Platform Edu Service',
      initialNotificationContent: 'Syncing with Server...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

void _handleIncomingSignaling(Map<String, dynamic> sigMap, ServiceInstance service, String backgroundUserId) async {
  // Forward every signaling packet to the foreground. Offers additionally
  // trigger the incoming-call UI when the app is in the background.
  service.invoke('signaling', sigMap);

  if (sigMap['type'] == 'offer') {
    final senderData = await ApiService.getProfile(sigMap['senderId']);
    final senderName = senderData?['name'] ?? sigMap['senderId'];

    NotificationService.showNotification(
      id: 999,
      title: 'مكالمة واردة',
      body: 'اتصال من $senderName',
      payload: 'call:${jsonEncode(sigMap)}',
      isCall: true,
    );
    service.invoke('incoming_call', sigMap);
  } else if (sigMap['type'] == 'hangup') {
    NotificationService.cancelNotification(999);
    service.invoke('hangup', sigMap);
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.init();
  
  final db = DatabaseService();
  final prefs = await SharedPreferences.getInstance();
  
  String? savedUrl = prefs.getString('server_url');
  if (savedUrl != null) AppConfig.serverUrl = savedUrl;

  String backgroundUserId = prefs.getString('student_id') ?? "unknown";
  AppConfig.currentStudentId = backgroundUserId;
  String? activeChatUserId;

  final socket = socket_io.io(AppConfig.serverUrl, <String, dynamic>{
    'transports': ['websocket', 'polling'],
    'autoConnect': true,
    'query': {'studentId': backgroundUserId},
    'reconnection': true,
    'reconnectionAttempts': 99,
    'reconnectionDelay': 1000,
  });

  final imageSocket = socket_io.io(AppConfig.imageServerUrl, <String, dynamic>{
    'transports': ['websocket', 'polling'],
    'autoConnect': true,
    'query': {'studentId': backgroundUserId},
  });

  final audioSocket = socket_io.io(AppConfig.audioServerUrl, <String, dynamic>{
    'transports': ['websocket', 'polling'],
    'autoConnect': true,
    'query': {'studentId': backgroundUserId},
  });

  service.on('setUserId').listen((event) {
    if (event != null && event['userId'] != null) {
      backgroundUserId = event['userId'];
      socket.io.options?['query'] = {'studentId': backgroundUserId};
      socket.disconnect().connect();
      
      imageSocket.io.options?['query'] = {'studentId': backgroundUserId};
      imageSocket.disconnect().connect();
      
      audioSocket.io.options?['query'] = {'studentId': backgroundUserId};
      audioSocket.disconnect().connect();
    }
  });

  service.on('setActiveChat').listen((event) {
    if (event != null) activeChatUserId = event['userId'];
  });

  service.on('typing_start').listen((event) {
    if (event != null) socket.emit('typing_start', event);
  });

  service.on('typing_stop').listen((event) {
    if (event != null) socket.emit('typing_stop', event);
  });

  service.on('recording_start').listen((event) {
    if (event != null) socket.emit('recording_start', event);
  });

  service.on('recording_stop').listen((event) {
    if (event != null) socket.emit('recording_stop', event);
  });

  socket.onConnect((_) async {
    debugPrint('✅ Background Sync Active: $backgroundUserId');
    socket.emit('get_pending_messages');
    try {
      final queue = await db.getSyncQueue();
      // limit queue processing to prevent memory spikes
      if (queue.length > 100) {
        debugPrint('⚠️ Sync queue too large: ${queue.length} items. Processing first 100.');
      }
      final itemsToSync = queue.take(100).toList();
      for (var item in itemsToSync) {
        socket.emit(item['action'], jsonDecode(item['data']));
        await db.removeFromSyncQueue(item['id']);
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  });

  socket.on('receive_message', (data) async {
    try {
      if (data == null || data is! Map) return;
      final Map<String, dynamic> msgMap = Map<String, dynamic>.from(data);
      final String senderId = msgMap['senderId'];
      final bool isMe = senderId == backgroundUserId;

      final msg = Message(
        senderId: msgMap['senderId'],
        targetId: msgMap['receiverId'] ?? msgMap['targetId'],
        text: msgMap['text'] ?? "",
        type: msgMap['type'] ?? 'text',
        mediaUrl: msgMap['mediaUrl'],
        senderMsgId: msgMap['clientMsgId']?.toString() ?? msgMap['id']?.toString(),
        timestamp: DateTime.tryParse(msgMap['timestamp'] ?? "") ?? DateTime.now(),
        isMe: isMe,
        status: msgMap['status'] == 'read' ? MessageStatus.read : MessageStatus.delivered,
      );
      await db.insertMessage(msg);

      // Send ACK to server if it's an incoming message
      if (!isMe) {
          socket.emit('message_received_ack', {'clientMsgId': msg.senderMsgId, 'senderId': senderId});
      }

      if (activeChatUserId == senderId || isMe) {
        service.invoke('update', {'message': msgMap});
        return;
      }

      String decText = CryptoHelper.decrypt(msgMap['text'] ?? "");
      if (msgMap['type'] == 'image') decText = '📷 صورة';
      if (msgMap['type'] == 'file') decText = '📁 ملف';

      NotificationService.showNotification(
        id: DateTime.now().millisecond,
        title: 'رسالة جديدة',
        body: decText,
        payload: 'chat:$senderId',
      );
      service.invoke('update', {'message': msgMap});
    } catch (e) {
      debugPrint('Receive Message Error: $e');
    }
  });

  socket.on('message_status', (data) async {
    if (data != null) {
      final String clientMsgId = data['clientMsgId'];
      final String statusStr = data['status'];
      
      int statusIndex = MessageStatus.sent.index;
      if (statusStr == 'delivered') statusIndex = MessageStatus.delivered.index;
      if (statusStr == 'read') statusIndex = MessageStatus.read.index;
      
      await db.updateMessageStatus(clientMsgId, statusIndex);
      service.invoke('status_update', data);
    }
  });

  socket.on('new_question', (data) {
    if (data == null) return;
    service.invoke('update', {'question': data});
  });

  socket.on('update_points', (data) {
    if (data != null) service.invoke('update_points', data);
  });

  socket.on('leaderboard', (data) {
    if (data != null) service.invoke('leaderboard', {'data': data});
  });

  socket.on('status', (data) {
    if (data != null) service.invoke('status', data);
  });

  socket.on('typing', (data) {
    if (data != null) {
      final mapData = Map<String, dynamic>.from(data);
      mapData['event'] = 'typing';
      service.invoke('typing', mapData);
    }
  });

  socket.on('recording', (data) {
    if (data != null) {
      final mapData = Map<String, dynamic>.from(data);
      mapData['event'] = 'recording';
      service.invoke('typing', mapData);
    }
  });

  socket.on('chat_history', (data) {
    if (data != null) service.invoke('chat_history', {'history': data});
  });

  socket.on('new_answer', (data) {
    if (data != null) service.invoke('update', {'answer': data});
  });

  socket.on('best_answer_marked', (data) {
    if (data != null) service.invoke('best_answer_marked', data);
  });

  socket.on('role_updated', (data) {
    if (data != null) service.invoke('role_updated', data);
  });

  socket.on('banned', (data) {
    if (data != null) service.invoke('banned', data);
  });

  socket.on('user_blocked', (data) {
    if (data != null) service.invoke('user_blocked', data);
  });

  socket.on('question_deleted', (data) async {
    if (data != null) {
      String? qId;
      if (data is Map) {
        qId = data['questionId']?.toString();
      } else {
        qId = data.toString();
      }
      if (qId != null) {
        await db.deleteQuestion(qId);
        service.invoke('question_deleted', {'questionId': qId});
      }
    }
  });

  socket.on('signaling', (data) async {
    if (data == null) return;
    final Map<String, dynamic> sigMap = Map<String, dynamic>.from(data);
    _handleIncomingSignaling(sigMap, service, backgroundUserId);
  });

  service.on('send_message').listen((event) {
    if (event != null) socket.emit('send_message', event);
  });

  service.on('post_question').listen((event) {
    if (event != null) socket.emit('post_question', event);
  });

  service.on('post_answer').listen((event) {
    if (event != null) socket.emit('post_answer', event);
  });

  service.on('get_leaderboard').listen((event) {
    socket.emit('get_leaderboard');
  });

  service.on('get_chat_history').listen((event) {
    if (event != null) socket.emit('get_chat_history', event);
  });

  service.on('typing').listen((event) {
    if (event != null) socket.emit('typing', event);
  });

  service.on('mark_best_answer').listen((event) {
    if (event != null) socket.emit('mark_best_answer', event);
  });

  service.on('delete_question').listen((event) {
    if (event != null) socket.emit('delete_question', event);
  });

  service.on('send_signaling').listen((event) {
    if (event != null) {
      bool isVideo = event['video'] ?? true;
      if (isVideo) {
        imageSocket.emit('signaling', event);
      } else {
        audioSocket.emit('signaling', event);
      }
    }
  });

  imageSocket.on('signaling', (data) {
    if (data != null) {
      final Map<String, dynamic> sigMap = Map<String, dynamic>.from(data);
      _handleIncomingSignaling(sigMap, service, backgroundUserId);
    }
  });

  audioSocket.on('signaling', (data) {
    if (data != null) {
      final Map<String, dynamic> sigMap = Map<String, dynamic>.from(data);
      _handleIncomingSignaling(sigMap, service, backgroundUserId);
    }
  });

  service.on('unban_member').listen((event) {
    if (event != null) socket.emit('unban_member', event);
  });

  service.on('stopService').listen((event) {
    socket.disconnect();
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'PLATFORM EDU',
          debugShowCheckedModeBanner: false,
          themeMode: Provider.of<ThemeProvider>(context).themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.lightTheme,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
