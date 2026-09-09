import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../utils/crypto_helper.dart';

class SocketService {
  socket_io.Socket? _socket;
  final Function(Map<String, dynamic>) onMessageReceived;
  final Function(Map<String, dynamic>) onSignalingMessage;
  final Function(String, bool) onTypingStatusChanged;
  final Function(String, bool) onUserStatusChanged;
  final Function(String, int) onMessageRead;
  final Function(String, String, String)? onDeliveryStatusChanged;

  SocketService({
    required this.onMessageReceived,
    required this.onSignalingMessage,
    required this.onTypingStatusChanged,
    required this.onUserStatusChanged,
    required this.onMessageRead,
    this.onDeliveryStatusChanged,
  });

  bool get isConnected => _socket != null && _socket!.connected;

  void connect(String url, String userId) {
    if (_socket != null) return;

    print('Connecting to socket: $url with userId: $userId');
    _socket = socket_io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'userId': userId},
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 2000,
    });

    _socket?.connect();

    _socket?.onConnect((_) {
      print('✅ Socket Connected');
      _socket?.emit('status', {'userId': userId, 'online': true});
    });

    _socket?.onConnectError((err) => print('❌ Socket Connect Error: $err'));

    _socket?.on('message', (data) {
      if (data == null || data is! Map) return;
      try {
        Map<String, dynamic> msgData = Map<String, dynamic>.from(data);
        if (msgData['text'] != null && msgData['text'] is String) {
          String decrypted = CryptoHelper.decrypt(msgData['text']);
          if (decrypted != "[Error]" && decrypted != "[خطأ]") {
            msgData['text'] = decrypted;
          }
        }
        // إرسال إيصال الاستلام تلقائياً عند استلام الرسالة في المقدمة
        if (msgData['messageId'] != null) {
          sendDeliveryReceipt(
            msgData['targetId']?.toString() ?? '', 
            msgData['senderId']?.toString() ?? '', 
            msgData['messageId'].toString()
          );
        }
        onMessageReceived(msgData);
      } catch (e) {
        print('Message handling error: $e');
      }
    });

    _socket?.on('signaling', (data) {
      if (data == null || data is! Map || data['payload'] == null) return;
      try {
        final Map<String, dynamic> sigPacket = Map<String, dynamic>.from(data);
        String decryptedJson = CryptoHelper.decrypt(sigPacket['payload']);
        if (decryptedJson == "[Error]" || decryptedJson == "[خطأ]") return;
        
        Map<String, dynamic> signalingData = Map<String, dynamic>.from(jsonDecode(decryptedJson));
        signalingData['senderId'] = sigPacket['senderId'] ?? 'unknown';
        onSignalingMessage(signalingData);
      } catch (e) {
        print('Signaling decryption error: $e');
      }
    });

    _socket?.on('typing', (data) {
      if (data != null && data is Map) {
        final Map<String, dynamic> typedData = Map<String, dynamic>.from(data);
        if (typedData['userId'] != null) {
          onTypingStatusChanged(typedData['userId'].toString(), typedData['isTyping'] == true);
        }
      }
    });

    _socket?.on('status', (data) {
      if (data != null && data is Map) {
        final Map<String, dynamic> statusData = Map<String, dynamic>.from(data);
        if (statusData['userId'] != null) {
          onUserStatusChanged(statusData['userId'].toString(), statusData['online'] == true);
        }
      }
    });

    _socket?.on('read', (data) {
      if (data != null && data is Map) {
        final Map<String, dynamic> readData = Map<String, dynamic>.from(data);
        if (readData['senderId'] != null) {
          onMessageRead(readData['senderId'].toString(), readData['messageId'] ?? 0);
        }
      }
    });

    _socket?.on('delivery_status', (data) {
      if (data != null && data is Map) {
        final Map<String, dynamic> delivData = Map<String, dynamic>.from(data);
        if (delivData['senderId'] != null) {
          onDeliveryStatusChanged?.call(
            delivData['senderId'].toString(), 
            delivData['messageId']?.toString() ?? '', 
            delivData['status']?.toString() ?? 'sent'
          );
        }
      }
    });
  }

  void checkUserStatus(String targetId) {
    if (isConnected) _socket?.emit('get_user_status', {'targetId': targetId});
  }

  void sendTyping(String senderId, String targetId, bool isTyping) {
    if (isConnected) {
      _socket?.emit('typing', {'userId': senderId, 'targetId': targetId, 'isTyping': isTyping});
    }
  }

  void sendMessage(String encryptedText, String senderId, String targetId, {
    String type = 'text', String? mediaUrl, String? fileName, int? messageId,
  }) {
    if (isConnected) {
      final payload = {
        'messageId': messageId,
        'senderId': senderId,
        'targetId': targetId,
        'text': encryptedText,
        'type': type,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 1,
      };
      print('Sending message: $payload');
      _socket?.emit('message', payload);
    }
  }

  void sendDeliveryReceipt(String senderId, String targetId, String messageId) {
    if (isConnected) {
      _socket?.emit('delivery_status', {
        'senderId': senderId,
        'targetId': targetId,
        'messageId': messageId,
        'status': 'delivered',
      });
    }
  }

  void sendReadReceipt(String senderId, String targetId, int messageId) {
    if (isConnected) {
      _socket?.emit('read', {
        'senderId': senderId,
        'targetId': targetId,
        'messageId': messageId,
        'status': 'read',
      });
    }
  }

  void sendSignaling(Map<String, dynamic> data) {
    if (isConnected) {
      String? targetId = data['targetId'] ?? data['target'];
      if (targetId == null) return;
      String encryptedPayload = CryptoHelper.encrypt(jsonEncode(data));
      _socket?.emit('signaling', {'payload': encryptedPayload, 'targetId': targetId});
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
