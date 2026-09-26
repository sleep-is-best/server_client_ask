import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../utils/crypto_helper.dart';

enum SocketConnectionState { connecting, connected, disconnected, reconnecting }

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState => _connectionStateController.stream;

  // Streams for better multi-listener support
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _questionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get questionStream => _questionController.stream;

  final _answerController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get answerStream => _answerController.stream;

  final _pointsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pointsStream => _pointsController.stream;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  final _statusUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusUpdateStream => _statusUpdateController.stream;

  final _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signalingStream => _signalingController.stream;

  final _questionDeletedController = StreamController<String>.broadcast();
  Stream<String> get questionDeletedStream => _questionDeletedController.stream;

  final _roleUpdatedController = StreamController<String>.broadcast();
  Stream<String> get roleUpdatedStream => _roleUpdatedController.stream;

  final _bannedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bannedStream => _bannedController.stream;

  final _userBlockedController = StreamController<String>.broadcast();
  Stream<String> get userBlockedStream => _userBlockedController.stream;

  final _bestAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bestAnswerStream => _bestAnswerController.stream;

  final _leaderboardController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get leaderboardStream => _leaderboardController.stream;

  final _chatHistoryController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get chatHistoryStream => _chatHistoryController.stream;

  bool _isServiceListenerSet = false;

  void connect(String studentId) {
    if (_isServiceListenerSet) return;
    _isServiceListenerSet = true;

    final service = FlutterBackgroundService();

    service.on('role_updated').listen((event) {
      if (event != null) {
        _roleUpdatedController.add(event['role']);
      }
    });

    service.on('banned').listen((event) {
      if (event != null) {
        _bannedController.add(Map<String, dynamic>.from(event));
      }
    });

    service.on('user_blocked').listen((event) {
      if (event != null && event['blockedUserId'] != null) {
        _userBlockedController.add(event['blockedUserId'].toString());
      }
    });

    service.on('update').listen((event) {
      if (event == null) return;
      if (event['message'] != null) {
        final data = Map<String, dynamic>.from(event['message']);
        _messageController.add(data);
      }
      if (event['question'] != null) {
        final data = Map<String, dynamic>.from(event['question']);
        _questionController.add(data);
      }
      if (event['answer'] != null) {
        final data = Map<String, dynamic>.from(event['answer']);
        _answerController.add(data);
      }
    });

    service.on('best_answer_marked').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _bestAnswerController.add(data);
      }
    });

    service.on('question_deleted').listen((event) {
      if (event != null) {
        String? qId;
        qId = event['questionId']?.toString();
              
        if (qId != null) {
          _questionDeletedController.add(qId);
        }
      }
    });

    service.on('update_points').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _pointsController.add(data);
      }
    });

    service.on('leaderboard').listen((event) {
      if (event != null && event['data'] != null) {
        _leaderboardController.add(List<dynamic>.from(event['data']));
      }
    });

    service.on('status').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _statusController.add(data);
      }
    });

    service.on('typing').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _typingController.add(data);
      }
    });

    service.on('status_update').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _statusUpdateController.add(data);
      }
    });

    service.on('chat_history').listen((event) {
      if (event != null && event['history'] != null) {
        _chatHistoryController.add(List<dynamic>.from(event['history']));
      }
    });

    service.on('signaling').listen((event) {
      if (event != null) {
        final data = Map<String, dynamic>.from(event);
        _signalingController.add(data);
      }
    });
  }

  void getLeaderboard() {
    FlutterBackgroundService().invoke('get_leaderboard');
  }

  Future<void> sendMessage(String targetId, String text, {String type = 'text', String? mediaUrl, String? messageId}) async {
    // نرسل النص كما هو (سواء كان مشفراً بالفعل أو نصاً عادياً)
    // إذا لم يكن مشفراً (لا يحتوي على علاماتنا)، نقوم بتشفيره
    String textToSend = text;
    if (type == 'text' && !text.contains('|') && !text.contains(':')) {
      textToSend = await CryptoHelper.encrypt(text);
    }
    
    final data = {
      'targetId': targetId,
      'text': textToSend,
      'type': type,
      'mediaUrl': mediaUrl,
      'messageId': messageId,
    };
    FlutterBackgroundService().invoke('send_message', data);
  }

  void postQuestion(String content, {List<String>? mediaUrls}) {
    final data = {'content': content, 'mediaUrls': mediaUrls ?? []};
    FlutterBackgroundService().invoke('post_question', data);
  }

  void postAnswer(String questionId, String content) {
    final data = {'questionId': questionId, 'content': content};
    FlutterBackgroundService().invoke('post_answer', data);
  }

  void requestChatHistory(String targetId) {
    FlutterBackgroundService().invoke('get_chat_history', {'targetId': targetId});
  }

  void getChatHistory(String targetId) => requestChatHistory(targetId);

  void sendTyping(String targetId, bool isTyping) {
    FlutterBackgroundService().invoke(isTyping ? 'typing_start' : 'typing_stop', {'targetId': targetId});
  }

  void sendRecording(String targetId, bool isRecording) {
    FlutterBackgroundService().invoke(isRecording ? 'recording_start' : 'recording_stop', {'targetId': targetId});
  }

  void markBestAnswer(String questionId, String answerId) {
    final data = {'questionId': questionId, 'answerId': answerId};
    FlutterBackgroundService().invoke('mark_best_answer', data);
  }

  void deleteQuestion(String questionId) {
    FlutterBackgroundService().invoke('delete_question', {'questionId': questionId});
  }

  void sendSignaling(Map<String, dynamic> data, {required bool isVideo}) {
    data['video'] = isVideo;
    FlutterBackgroundService().invoke('send_signaling', data);
  }

  void unbanMember(String targetId) {
    FlutterBackgroundService().invoke('unban_member', {'targetId': targetId});
  }

  void disconnect() => FlutterBackgroundService().invoke('stopService');
}
