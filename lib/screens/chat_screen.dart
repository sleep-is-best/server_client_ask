import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';
import '../services/audio_service.dart';
import '../utils/crypto_helper.dart';
import '../services/contact_service.dart';
import '../main.dart'; // To access global dbService

class ChatScreen extends StatefulWidget {
  final String userId;
  final String targetUserId;
  final bool autoAcceptCall;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.targetUserId,
    this.autoAcceptCall = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  late SocketService _socketService;
  late WebRTCService _webrtcService;
  final AudioService _audioService = AudioService();
  final ImagePicker _picker = ImagePicker();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _inCall = false;
  bool _isTargetTyping = false;
  bool _isTargetOnline = false;
  bool _isRecording = false;
  Timer? _typingTimer;

  bool _isMuted = false;
  bool _isVideoOff = false;
  String? _targetUserName;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _loadChatHistory();
    _initServices();
    _markAllAsRead();
    _loadTargetUserName();
    
    // إبلاغ الخدمة الخلفية بالمحادثة النشطة لتجنب التكرار في الإشعارات والحفظ
    FlutterBackgroundService().invoke('setActiveChat', {'userId': widget.targetUserId});
  }

  Future<void> _loadTargetUserName() async {
    String? name = await ContactService.getContactName(widget.targetUserId);
    if (mounted && name != null) {
      setState(() {
        _targetUserName = name;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    await dbService.markAsRead(widget.targetUserId);
    if (mounted) {
      _socketService.sendReadReceipt(widget.userId, widget.targetUserId, 0);
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _loadChatHistory() async {
    final history = await dbService.getMessages(widget.targetUserId);
    if (mounted) {
      setState(() {
        _messages.addAll(history);
      });
    }
  }

  void _initServices() {
    _socketService = SocketService(
      onMessageReceived: (data) async {
        final msg = Message.fromJson(data, widget.userId);
        // Update status to read because chat is currently open
        msg.status = MessageStatus.read;
        int localId = await dbService.insertMessage(msg);
        msg.id = localId;
        
        if (mounted) {
          setState(() {
            _messages.insert(0, msg);
          });
          _socketService.sendReadReceipt(widget.userId, widget.targetUserId, localId);
        }
      },
      onTypingStatusChanged: (userId, isTyping) {
        if (userId == widget.targetUserId) {
          setState(() => _isTargetTyping = isTyping);
        }
      },
      onUserStatusChanged: (userId, isOnline) {
        if (userId == widget.targetUserId) {
          setState(() => _isTargetOnline = isOnline);
        }
      },
      onMessageRead: (senderId, messageId) async {
        if (mounted) {
          setState(() {
            for (var m in _messages) {
              if (m.isMe && (messageId == 0 || m.id == messageId)) {
                m.status = MessageStatus.read;
                if (m.id != null) dbService.updateMessageStatus(m.id!, MessageStatus.read);
              }
            }
          });
        }
      },
      onDeliveryStatusChanged: (senderId, messageId, status) async {
        if (mounted) {
          setState(() {
            for (var m in _messages) {
              if (m.isMe && m.status != MessageStatus.read && (messageId == "all" || m.id.toString() == messageId)) {
                m.status = MessageStatus.delivered;
                if (m.id != null) dbService.updateMessageStatus(m.id!, MessageStatus.delivered);
              }
            }
          });
        }
      },
      onSignalingMessage: (data) async {
        switch (data['type']) {
          case 'offer':
            if (widget.autoAcceptCall) {
              await _acceptCall(data);
            } else {
              _showIncomingCallDialog(data);
            }
            break;
          case 'answer':
            await _webrtcService.handleAnswer(data);
            break;
          case 'candidate':
            await _webrtcService.handleCandidate(data);
            break;
          case 'hangup':
            _endCallLocally();
            break;
        }
      },
    );

    _webrtcService = WebRTCService(
      socketService: _socketService,
      onRemoteStream: (stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      },
    );

    _socketService.connect('http://10.134.82.18:3000', widget.userId);
    
    // الانتظار قليلاً لضمان تهيئة الـ Renderers قبل التحقق من المكالمات المعلقة
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
         _checkPendingOffer();
         // Send a call request if not in call yet to notify the other side
         // This is a workaround for signaling issues when target is not in chat
         _socketService.checkUserStatus(widget.targetUserId);
      }
    });

    FlutterBackgroundService().on('typing').listen((event) {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        if (data['userId'] == widget.targetUserId) {
          setState(() => _isTargetTyping = data['isTyping'] == true);
        }
      }
    });

    FlutterBackgroundService().on('status').listen((event) {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        if (data['userId'] == widget.targetUserId) {
          setState(() => _isTargetOnline = data['online'] == true);
        }
      }
    });

    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event['message'] != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event['message']);
        if (data['senderId'] == widget.targetUserId) {
          _socketService.onMessageReceived(data);
        }
      }
    });

    FlutterBackgroundService().on('delivery_status').listen((event) {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        _socketService.onDeliveryStatusChanged?.call(
          data['senderId'].toString(),
          data['messageId']?.toString() ?? '',
          data['status']?.toString() ?? 'sent'
        );
      }
    });

    FlutterBackgroundService().on('read').listen((event) {
      if (event != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        _socketService.onMessageRead(
          data['senderId'].toString(),
          data['messageId'] ?? 0
        );
      }
    });
    
    // طلب حالة الطرف الآخر عند بدء الاتصال
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _socketService.checkUserStatus(widget.targetUserId);
    });
    
    _checkPendingOffer();
  }

  Future<void> _checkPendingOffer() async {
    final prefs = await SharedPreferences.getInstance();
    String? pendingOfferJson = prefs.getString('pending_offer_${widget.targetUserId}');
    if (pendingOfferJson != null) {
      await prefs.remove('pending_offer_${widget.targetUserId}');
      Map<String, dynamic> data = json.decode(pendingOfferJson);
      if (widget.autoAcceptCall) {
        await _acceptCall(data);
      } else {
        _showIncomingCallDialog(data);
      }
    }
  }

  void _showIncomingCallDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('مكالمة واردة'),
        content: Text('رقم الهاتف ${widget.targetUserId} يتصل بك...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socketService.sendSignaling({'type': 'hangup', 'target': widget.targetUserId});
            },
            child: const Text('رفض', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptCall(data);
            },
            child: const Text('رد'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCall(Map<String, dynamic> data) async {
    bool isVideo = data['video'] == true;
    
    List<Permission> permissions = [Permission.microphone, Permission.bluetoothConnect];
    if (isVideo) permissions.add(Permission.camera);

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    if (statuses[Permission.microphone]!.isGranted && 
        (!isVideo || (statuses[Permission.camera]?.isGranted ?? false))) {
      await _webrtcService.openUserMedia(_localRenderer, _remoteRenderer, video: isVideo);
      await _webrtcService.handleOffer(data);
      setState(() {
        _inCall = true;
        _isVideoOff = !isVideo;
      });
    }
  }

  void _hangUp() {
    _socketService.sendSignaling({'type': 'hangup', 'target': widget.targetUserId});
    _endCallLocally();
  }

  void _endCallLocally() {
    _webrtcService.hangUp();
    if (mounted) {
      setState(() {
        _inCall = false;
        _isVideoOff = false;
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      });
    }
    // Log the call
    dbService.insertCallLog({
      'callerId': widget.userId,
      'receiverId': widget.targetUserId,
      'timestamp': DateTime.now().toIso8601String(),
      'duration': 0, // Placeholder
      'type': _isVideoOff ? 'audio' : 'video',
      'status': 'completed',
    });
  }

  Future<void> _startCall({bool video = true}) async {
    List<Permission> permissions = [Permission.microphone, Permission.bluetoothConnect];
    if (video) permissions.add(Permission.camera);

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    if (statuses[Permission.microphone]!.isGranted && 
        (!video || (statuses[Permission.camera]?.isGranted ?? false))) {
      try {
        await _webrtcService.openUserMedia(_localRenderer, _remoteRenderer, video: video);
        await _webrtcService.call(widget.targetUserId, video: video);
        setState(() {
          _inCall = true;
          _isVideoOff = !video;
        });
      } catch (e) {
        debugPrint("Error starting call: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل بدء المكالمة: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء منح الصلاحيات اللازمة للمكالمة')),
        );
      }
    }
  }

  @override
  void dispose() {
    // إزالة المحادثة النشطة عند الخروج
    FlutterBackgroundService().invoke('setActiveChat', {'userId': null});
    _typingTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _socketService.disconnect();
    _audioService.dispose();
    super.dispose();
  }

  void _onTyping() {
    _socketService.sendTyping(widget.userId, widget.targetUserId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socketService.sendTyping(widget.userId, widget.targetUserId, false);
    });
  }

  void _sendMessage({String type = 'text', String? mediaUrl, String? fileName}) async {
    String text = type == 'text' ? _messageController.text : '[$type]';
    if (text.isNotEmpty || mediaUrl != null) {
      String encryptedText = type == 'text' ? CryptoHelper.encrypt(text) : text;
      final msg = Message(
        senderId: widget.userId,
        targetId: widget.targetUserId,
        text: text, // Store plain text locally
        type: type,
        mediaUrl: mediaUrl,
        fileName: fileName,
        timestamp: DateTime.now(),
        isMe: true,
        status: MessageStatus.pending,
      );

      int id = await dbService.insertMessage(msg);
      msg.id = id;
      
      _socketService.sendMessage(encryptedText, widget.userId, widget.targetUserId,
          type: type, mediaUrl: mediaUrl, fileName: fileName, messageId: id);
      
      if (mounted) {
        setState(() {
          _messages.insert(0, msg);
        });
      }
      _messageController.clear();
      _socketService.sendTyping(widget.userId, widget.targetUserId, false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      List<int> encryptedBytes = CryptoHelper.encryptBytes(imageBytes);
      // استخدام Uint8List لتحويل الـ bytes إلى String بشكل آمن للنقل
      String encryptedString = base64Encode(encryptedBytes);
      _sendMessage(type: 'image', mediaUrl: encryptedString, fileName: image.name);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      List<int> fileBytes = await file.readAsBytes();
      List<int> encryptedBytes = CryptoHelper.encryptBytes(fileBytes);
      String encryptedString = base64Encode(encryptedBytes);
      _sendMessage(
        type: 'file',
        mediaUrl: encryptedString,
        fileName: result.files.single.name,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openMedia(Message msg) async {
    if (msg.mediaUrl == null) return;
    
    try {
      List<int> encryptedBytes = base64Decode(msg.mediaUrl!);
      List<int> decryptedBytes = CryptoHelper.decryptBytes(encryptedBytes);
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${msg.fileName ?? "temp_file"}');
      await tempFile.writeAsBytes(decryptedBytes);
      
      await OpenFilex.open(tempFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح الملف: $e')),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      String? path = await _audioService.stopRecording();
      if (path != null) {
        List<int> audioBytes = await File(path).readAsBytes();
        List<int> encryptedBytes = CryptoHelper.encryptBytes(audioBytes);
        String encryptedString = base64Encode(encryptedBytes);
        _sendMessage(type: 'audio', mediaUrl: encryptedString, fileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.aac');
      }
      setState(() => _isRecording = false);
    } else {
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خدمات الموقع معطلة')));
         }
         return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      String locationData = "${position.latitude},${position.longitude}";
      String encryptedLocation = CryptoHelper.encrypt(locationData);
      _sendMessage(type: 'location', mediaUrl: encryptedLocation);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحصول على الموقع')),
        );
      }
    }
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 12, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.grey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE5DDD5),
      appBar: AppBar(
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(Icons.arrow_back),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade400,
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _targetUserName ?? widget.targetUserId,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _isTargetTyping
                  ? 'يكتب الآن...'
                  : (_isTargetOnline ? 'متصل الآن' : 'غير متصل'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFFD4AF37)),
            onPressed: () => _startCall(video: true),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFFD4AF37)),
            onPressed: () => _startCall(video: false),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_inCall) _buildCallOverlay(),
              Expanded(child: _buildMessageList()),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallOverlay() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: const Color(0xFFD4AF37), width: 1)),
      ),
      child: Stack(
        children: [
          if (!_isVideoOff)
            Row(
              children: [
                Expanded(child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                Expanded(child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
              ],
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFD4AF37),
                    child: Icon(Icons.person, size: 60, color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _targetUserName ?? widget.targetUserId,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text("مكالمة صوتية نشطة", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        _webrtcService.toggleAudio(!_isMuted);
                      },
                    ),
                  ),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      onPressed: _hangUp,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                      onPressed: () {
                        setState(() => _isVideoOff = !_isVideoOff);
                        _webrtcService.toggleVideo(!_isVideoOff);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = msg.isMe;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFDCF8C6))
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
              border: isMe ? Border.all(color: const Color(0xFFD4AF37), width: 0.5) : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, right: 10),
                  child: _buildMessageContent(msg),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.timestamp.toString().substring(11, 16),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(msg.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(Message msg) {
    final bool isMe = msg.isMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMe 
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white : Colors.black);

    if (msg.type == 'image' && msg.mediaUrl != null) {
      try {
        List<int> encryptedBytes = base64Decode(msg.mediaUrl!);
        List<int> decryptedBytes = CryptoHelper.decryptBytes(encryptedBytes);
        return GestureDetector(
          onTap: () => _openMedia(msg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(Uint8List.fromList(decryptedBytes), width: 200, fit: BoxFit.cover),
          ),
        );
      } catch (e) {
        return const Text('[خطأ في فك تشفير الصورة]', style: TextStyle(color: Colors.red));
      }
    } else if (msg.type == 'audio' && msg.mediaUrl != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
            onPressed: () async {
              try {
                List<int> encryptedBytes = base64Decode(msg.mediaUrl!);
                List<int> decryptedBytes = CryptoHelper.decryptBytes(encryptedBytes);
                final tempDir = await getTemporaryDirectory();
                final tempFile = File('${tempDir.path}/temp_audio_${msg.timestamp.millisecondsSinceEpoch}.m4a');
                await tempFile.writeAsBytes(decryptedBytes);
                await _audioService.playAudio(tempFile.path);
              } catch (e) {
                debugPrint("Audio play error: $e");
              }
            },
          ),
          const Text("رسالة صوتية", style: TextStyle(color: Colors.white)),
        ],
      );
    } else if (msg.type == 'file' && msg.mediaUrl != null) {
      return InkWell(
        onTap: () => _openMedia(msg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg.fileName ?? "ملف مشفر",
                style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      );
    } else if (msg.type == 'location' && msg.mediaUrl != null) {
      return InkWell(
        onTap: () async {
          try {
            String decryptedLocation = CryptoHelper.decrypt(msg.mediaUrl!);
            final coords = decryptedLocation.split(',');
            if (coords.length == 2) {
              final lat = coords[0];
              final lng = coords[1];
              final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('فشل فتح الموقع'))
              );
            }
          }
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 8),
            Text("مشاركة الموقع", style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    return Text(msg.text, style: TextStyle(color: msg.isMe ? Colors.white : Colors.black));
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade600),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (text) {
                        _onTyping();
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        hintText: 'رسالة',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _buildAttachmentMenu(),
                      );
                    },
                  ),
                  if (_messageController.text.isEmpty)
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.grey.shade600),
                      onPressed: _pickImage,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {
              if (_messageController.text.trim().isNotEmpty) {
                _sendMessage();
              } else if (_isRecording) {
                _toggleRecording();
              }
            },
            onLongPress: () {
              if (_messageController.text.isEmpty && !_isRecording) {
                _toggleRecording();
              }
            },
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFD4AF37),
              child: Icon(
                _messageController.text.isNotEmpty ? Icons.send : (_isRecording ? Icons.stop : Icons.mic),
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentItem(Icons.insert_drive_file, "مستند", Colors.indigo, _pickFile),
              _buildAttachmentItem(Icons.camera_alt, "كاميرا", Colors.pink, () {}),
              _buildAttachmentItem(Icons.image, "معرض", Colors.purple, _pickImage),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentItem(Icons.headphones, "صوت", Colors.orange, () {}),
              _buildAttachmentItem(Icons.location_on, "الموقع", Colors.green, _shareLocation),
              _buildAttachmentItem(Icons.person, "جهة اتصال", Colors.blue, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: color,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
