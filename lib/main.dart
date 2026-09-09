import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'models/message.dart';
import 'screens/chat_screen.dart';
import 'screens/contact_list_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';
import 'services/contact_service.dart';
import 'services/database_service.dart';
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
  await NotificationService.init();
  // التأكد من تهيئة قاعدة البيانات عند بدء التشغيل
  await dbService.database;
  await initializeService();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'chat_messages',
      initialNotificationTitle: 'Chat Service',
      initialNotificationContent: 'Running...',
      foregroundServiceNotificationId: 888,
      // إضافة كافة أنواع الخدمات المطلوبة لتجنب الانهيار في أندرويد 14
      foregroundServiceTypes: [
        AndroidForegroundType.microphone, 
        AndroidForegroundType.camera,
        AndroidForegroundType.phoneCall
      ],
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

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final db = DatabaseService();
  await db.database;

  final prefs = await SharedPreferences.getInstance();
  String backgroundUserId = prefs.getString('user_phone') ?? "unknown";
  String? activeChatUserId;

  const String serverUrl = 'http://10.134.82.18:3000';

  final socket = socket_io.io(serverUrl, <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': true,
    'query': {'userId': backgroundUserId},
    'reconnection': true,
    'reconnectionAttempts': 10,
    'reconnectionDelay': 5000,
  });

  service.on('setUserId').listen((event) {
    if (event != null && event['userId'] != null) {
      String newUserId = event['userId'];
      if (newUserId != backgroundUserId) {
        backgroundUserId = newUserId;
        socket.io.options?['query'] = {'userId': backgroundUserId};
        socket.disconnect().connect();
        debugPrint('Background Service: Updated userId to $backgroundUserId and reconnected');
      }
    }
  });

  service.on('setActiveChat').listen((event) {
    if (event != null) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(event);
      activeChatUserId = data['userId'];
      debugPrint('Background Service: Active chat set to $activeChatUserId');
    }
  });

  socket.onConnect((_) {
    debugPrint('Background Service: Connected to server as $backgroundUserId');
    socket.emit('status', {'userId': backgroundUserId, 'online': true});
  });

  socket.onDisconnect((_) {
    debugPrint('Background Service: Disconnected from server');
  });

  socket.onConnectError((err) => debugPrint('Background Connect Error: $err'));

  socket.on('message', (data) async {
    if (data == null || data is! Map || data['targetId'] != backgroundUserId) return;
    if (data['senderId'] == null) return;
    
    final Map<String, dynamic> messageData = Map<String, dynamic>.from(data);
    final String senderId = messageData['senderId'].toString();
    debugPrint('Background Service: Received message from $senderId');

    if (activeChatUserId == senderId) {
      debugPrint('Background Service: Skipping DB save and notification for active chat');
      service.invoke('update', {'message': messageData});
      return;
    }

    String decryptedText = "";
    try {
      if (messageData['type'] == 'text' || messageData['type'] == null) {
         decryptedText = CryptoHelper.decrypt(messageData['text'] ?? "");
      } else {
         decryptedText = "[${messageData['type']}] ${messageData['fileName'] ?? ''}";
      }
    } catch (e) {
      decryptedText = "[رسالة مشفرة]";
    }
    
    try {
      final newMessage = Message(
        senderId: senderId,
        targetId: messageData['targetId'] ?? backgroundUserId,
        text: decryptedText,
        type: messageData['type'] ?? 'text',
        mediaUrl: messageData['mediaUrl'] is String ? messageData['mediaUrl'] : null,
        fileName: messageData['fileName'],
        senderMsgId: messageData['messageId'] is int ? messageData['messageId'] : null,
        timestamp: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
        isMe: false,
        status: MessageStatus.delivered,
      );
      await db.insertMessage(newMessage);
    } catch (e) {
      debugPrint('Error saving message to DB in background: $e');
    }

    String senderName = await ContactService.getContactName(senderId) ?? senderId;

    NotificationService.showNotification(
      id: DateTime.now().millisecond,
      title: 'رسالة جديدة من $senderName',
      body: decryptedText,
      payload: 'chat:$senderId',
    );

    if (messageData['messageId'] != null) {
      socket.emit('delivery_status', {
        'senderId': backgroundUserId,
        'targetId': senderId,
        'messageId': messageData['messageId'],
        'status': 'delivered',
      });
    }
    
    service.invoke('update', {'message': messageData});
  });

  socket.on('delivery_status', (data) async {
    if (data == null || data is! Map) return;
    service.invoke('delivery_status', Map<String, dynamic>.from(data));
  });

  socket.on('signaling', (data) async {
    try {
      if (data == null || data is! Map || data['payload'] == null) return;
      final Map<String, dynamic> sigPacket = Map<String, dynamic>.from(data);
      String encryptedPayload = sigPacket['payload'];
      String decryptedJson = CryptoHelper.decrypt(encryptedPayload);
      if (decryptedJson == "[Error]" || decryptedJson == "[خطأ]") return;
      
      Map<String, dynamic> signalingData = Map<String, dynamic>.from(json.decode(decryptedJson));
      String senderId = sigPacket['senderId'] ?? 'unknown';

      if (signalingData['type'] == 'offer') {
        signalingData['senderId'] = senderId;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_offer_$senderId', json.encode(signalingData));

        String senderName = await ContactService.getContactName(senderId) ?? senderId;

        const AndroidNotificationAction acceptAction = AndroidNotificationAction(
          'accept_call',
          'رد',
          showsUserInterface: true,
          cancelNotification: true,
        );

        const AndroidNotificationAction declineAction = AndroidNotificationAction(
          'decline_call',
          'رفض',
          showsUserInterface: false,
          cancelNotification: true,
        );

        NotificationService.showNotification(
          id: 999,
          title: 'مكالمة واردة',
          body: 'مكالمة فيديو من $senderName',
          payload: 'call:$senderId',
          actions: [acceptAction, declineAction],
        );
      }
    } catch (e) {
      print('Error handling signaling in background: $e');
    }
  });

  socket.on('typing', (data) {
    if (data != null && data is Map) {
      service.invoke('typing', Map<String, dynamic>.from(data));
    }
  });

  socket.on('status', (data) {
    if (data != null && data is Map) {
      service.invoke('status', Map<String, dynamic>.from(data));
    }
  });

  socket.on('get_call_request', (data) async {
    // This is a custom event to check if someone is calling me while I'm not in chat
    if (data == null || data is! Map) return;
    String senderId = data['senderId'] ?? 'unknown';
    String senderName = await ContactService.getContactName(senderId) ?? senderId;
    
    NotificationService.showNotification(
      id: 999,
      title: 'مكالمة واردة',
      body: 'مكالمة من $senderName',
      payload: 'call:$senderId',
    );
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
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        String? myId = snapshot.data!.getString('user_phone');
        return MaterialApp(
          title: 'WhatsApp Pro',
          debugShowCheckedModeBanner: false,
          themeMode: Provider.of<ThemeProvider>(context).themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD4AF37), // Gold
              primary: Colors.black,
              secondary: const Color(0xFF2196F3), // Blue
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Color(0xFFD4AF37), // Gold text/icons
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD4AF37),
              primary: Colors.black,
              secondary: const Color(0xFF2196F3),
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Color(0xFFD4AF37),
            ),
          ),
          home: myId != null ? MainNavigationScreen(myUserId: myId) : const LoginScreen(),
        );
      }
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _myIdController = TextEditingController();
  final TextEditingController _targetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    NotificationService.onNotificationClick.stream.listen((response) {
      if (response.payload != null) {
        if (response.payload!.startsWith('call:')) {
          String senderId = response.payload!.split(':')[1];
          if (response.actionId == 'accept_call') {
            _navigateToChat(senderId, autoAcceptCall: true);
          } else if (response.actionId == 'decline_call') {
            // You might want to emit a hangup signal here if possible
          } else {
            _navigateToChat(senderId);
          }
        } else if (response.payload!.startsWith('chat:')) {
          String senderId = response.payload!.split(':')[1];
          _navigateToChat(senderId);
        }
      }
    });
  }

  void _navigateToChat(String targetId, {bool autoAcceptCall = false}) async {
    final prefs = await SharedPreferences.getInstance();
    String? myId = prefs.getString('user_phone') ?? _myIdController.text;

    if (myId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(myUserId: myId),
          ),
        );
        if (autoAcceptCall || targetId != null) {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: myId,
                targetUserId: targetId ?? "",
                autoAcceptCall: autoAcceptCall,
              ),
            ),
          );
        }
      }
    }
  }

  void _startChat() async {
    if (_myIdController.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', _myIdController.text);
      
      // Notify background service of the new user ID
      FlutterBackgroundService().invoke('setUserId', {'userId': _myIdController.text});
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(
              myUserId: _myIdController.text,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال أرقام الهاتف للمتابعة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF000000), const Color(0xFF1A1A1A)] 
                : [const Color(0xFFF5F5F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 80,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'LUXURY CHAT',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Text(
                    'SECURE • ENCRYPTED • ELITE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 60),
                  TextField(
                    controller: _myIdController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'رقم هاتفك الخاص',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                      prefixIcon: const Icon(Icons.phone_android, color: Color(0xFFD4AF37)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.black.withOpacity(0.24) : Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _startChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: const Color(0xFFD4AF37),
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 10,
                      shadowColor: const Color(0xFFD4AF37).withOpacity(0.3),
                    ),
                    child: const Text(
                      'بدء التجربة الفاخرة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'تشفير طرف إلى طرف مفعل دائماً',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
