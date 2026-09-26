import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../utils/crypto_helper.dart';
import '../utils/app_colors.dart';
import '../widgets/user_avatar.dart';

import 'call_screen.dart';
import '../widgets/cached_image.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String targetUserId;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.targetUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final DatabaseService dbService = DatabaseService();
  final AudioService _audioService = AudioService();
  late SocketService _socketService;
  final Set<String> _showEncryptedMessages = {}; // تتبع الرسائل التي تعرض النص المشفر بواسطة ID أو Timestamp
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _historySubscription;
  bool _isTargetOnline = false;
  bool _isTargetTyping = false;
  bool _isTargetRecording = false;
  String? _targetUserName;
  Timer? _typingTimer;

  bool _isRecording = false;

  Map<String, dynamic>? _targetData;

  @override
  void initState() {
    super.initState();
    // Guard: Prevent initialization with invalid user IDs
    if (widget.targetUserId.isEmpty || widget.targetUserId == widget.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _loadTargetData();
    _loadChatHistory();
    _initServices();
    _markAllAsRead();
    FlutterBackgroundService().invoke('setActiveChat', {'userId': widget.targetUserId});
    _setupBackgroundListener();
  }

  void _setupBackgroundListener() {
    // We already have a centralized listener in _initServices via _socketService.
    // However, if we want to ensure events are captured even when this screen is not the primary listener:
    // But since _socketService is now just a bridge to FlutterBackgroundService, it should be fine.
  }

  void _showIncomingCallDialog(Map<String, dynamic> offer) async {
    String displayName = offer['senderId']; // Fallback
    final senderProfile = await ApiService.getProfile(offer['senderId']);
    if (senderProfile != null) {
      displayName = senderProfile['name'] ?? senderProfile['phone'] ?? offer['senderId'];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("اتصال وارد"),
        content: Text("لديك اتصال ${offer['video'] == true ? 'فيديو' : 'صوتي'} من $displayName"),
        actions: [
          TextButton(
            child: const Text("رفض"),
            onPressed: () {
              Navigator.pop(dialogContext);
              SocketService().sendSignaling({'type': 'hangup', 'targetId': widget.targetUserId}, isVideo: offer['video'] == true);
            },
          ),
          ElevatedButton(
            child: const Text("قبول"),
            onPressed: () {
              Navigator.pop(dialogContext);
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    userId: widget.userId,
                    targetUserId: widget.targetUserId,
                    isVideo: offer['video'] == true,
                    isIncoming: true,
                    initialOffer: offer,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() async {
    await dbService.markAllAsRead(widget.targetUserId);
  }

  void _loadTargetData() async {
    final data = await ApiService.getProfile(widget.targetUserId);
    if (mounted) {
      setState(() {
        _targetData = data;
        _targetUserName = data?['name'];
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _statusSubscription?.cancel();
    _signalingSubscription?.cancel();
    _historySubscription?.cancel();
    _typingTimer?.cancel();
    _audioService.dispose();
    FlutterBackgroundService().invoke('setActiveChat', {'userId': null});
    super.dispose();
  }

  void _initServices() {
    _socketService = SocketService();
    _socketService.connect(widget.userId);

    _messageSubscription = _socketService.messageStream.listen((data) async {
      final msg = Message(
        senderId: data['senderId'],
        targetId: data['targetId'],
        text: data['text'], // حفظ النص مشفراً كما هو
        type: data['type'] ?? 'text',
        mediaUrl: data['mediaUrl'],
        senderMsgId: data['messageId']?.toString() ?? data['id']?.toString(),
        timestamp: DateTime.parse(data['timestamp']),
        isMe: data['senderId'] == widget.userId,
        status: MessageStatus.delivered,
      );

      // تجنب تكرار الرسالة إذا كانت مرسلة من هذا الجهاز أو موجودة مسبقاً
      bool alreadyInList = _messages.any((m) =>
        (m.senderMsgId != null && m.senderMsgId == msg.senderMsgId) ||
        (m.text == msg.text && m.timestamp.difference(msg.timestamp).inSeconds.abs() < 2)
      );

      if (alreadyInList) {
        // يمكن هنا تحديث حالة الرسالة إلى 'delivered' في القائمة إذا لزم الأمر
        return;
      }

      await dbService.insertMessage(msg);

      if (msg.senderId == widget.targetUserId || msg.isMe) {
        if (mounted) {
          setState(() {
            _messages.insert(0, msg);
          });
        }
      }
    });

    _typingSubscription = _socketService.typingStream.listen((data) {
      if (data['studentId'] == widget.targetUserId && mounted) {
        setState(() {
          if (data['event'] == 'typing') {
            _isTargetTyping = data['isTyping'];
          } else if (data['event'] == 'recording') {
            _isTargetRecording = data['isRecording'];
          }
        });
      }
    });

    _statusSubscription = _socketService.statusStream.listen((data) {
      if (data['studentId'] == widget.targetUserId && mounted) {
        setState(() => _isTargetOnline = data['online']);
      }
    });

    _signalingSubscription = _socketService.signalingStream.listen((data) {
      if (data['type'] == 'offer' && data['senderId'] == widget.targetUserId) {
        _showIncomingCallDialog(data);
      }
    });

    _historySubscription = _socketService.chatHistoryStream.listen((history) async {
      if (mounted) {
        final List<Message> remoteMessages = history.map<Message>((m) => Message(
          senderId: m['senderId'],
          targetId: m['targetId'],
          text: m['text'], // حفظ النص مشفراً
          type: m['type'] ?? 'text',
          mediaUrl: m['mediaUrl'],
          senderMsgId: m['messageId']?.toString() ?? m['id']?.toString(),
          timestamp: DateTime.parse(m['timestamp']),
          isMe: m['senderId'] == widget.userId,
          status: MessageStatus.delivered
        )).toList();

        // Update local DB with remote history
        for (var msg in remoteMessages) {
          await dbService.insertMessage(msg);
        }

        // Refresh UI from local DB
        final updatedHistory = await dbService.getMessages(widget.userId, widget.targetUserId);
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(updatedHistory);
          });
        }
      }
    });

    _socketService.getChatHistory(widget.targetUserId);
  }

  void _loadChatHistory() async {
    // 1. Load from Local DB first for instant UI
    final localHistory = await dbService.getMessages(widget.userId, widget.targetUserId);
    if (mounted && localHistory.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(localHistory);
      });
    }

    // 2. Request history from server via Socket to sync
    _socketService.requestChatHistory(widget.targetUserId);
  }

  void _startCall(bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          userId: widget.userId,
          targetUserId: widget.targetUserId,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    // 1. توليد معرف مؤقت وتشفير النص مرة واحدة فقط
    final String tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final encryptedText = await CryptoHelper.encrypt(text);
    if (!mounted) return;

    final msg = Message(
      senderId: widget.userId,
      targetId: widget.targetUserId,
      text: encryptedText,
      senderMsgId: tempId,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    // 2. تحديث الواجهة فوراً (Optimistic UI) قبل أي عمليات انتظار
    if (mounted) {
      setState(() {
        _messages.insert(0, msg);
        _messageController.clear();
      });
      _socketService.sendTyping(widget.targetUserId, false);
    }

    // 3. إرسال النص المشفر مسبقاً للسيرفر لتجنب اختلاف الـ IV عند الارتداد
    _socketService.sendMessage(widget.targetUserId, encryptedText, messageId: tempId);

    // 4. الحفظ في قاعدة البيانات في الخلفية
    await dbService.insertMessage(msg);
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'المدير العام';
      case 'assistant_admin': return 'مساعد مدير';
      case 'doctor': return 'دكتور';
      case 'teacher': return 'أستاذ';
      case 'premium_member': return 'عضو مميز';
      default: return 'عضو';
    }
  }

  Color _getRoleColor(String role, ColorScheme colorScheme) {
    switch (role) {
      case 'admin':
      case 'assistant_admin':
        return const Color(0xFFD4AF37);
      case 'doctor':
        return Colors.deepPurple;
      case 'teacher':
        return Colors.orange;
      case 'premium_member':
        return colorScheme.tertiary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            // Navigator to profile could go here
          },
          child: Row(
            children: [
              UserAvatar(
                name: _targetUserName ?? _targetData?['phone'] ?? '...',
                imageUrl: _targetData?['profileImage'],
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _targetUserName ?? _targetData?['phone'] ?? 'جاري التحميل...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_targetData?['role'] != null && _targetData?['role'] != 'member') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _getRoleColor(_targetData!['role'], Theme.of(context).colorScheme).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getRoleName(_targetData!['role']),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(_targetData!['role'], Theme.of(context).colorScheme),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isTargetOnline ? AppColors.secondary : AppColors.textHint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isTargetOnline ? 'متصل الآن' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isTargetOnline ? AppColors.secondary : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            onPressed: () => _startCall(true),
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            onPressed: () => _startCall(false),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isTargetTyping || _isTargetRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                _isTargetTyping ? "يكتب الآن..." : "يسجل مقطع صوتي...",
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg.isMe;
        final msgKey = msg.senderMsgId ?? msg.timestamp.toIso8601String();

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: AppColors.softShadow,
                  border: isMe ? null : Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (msg.type == 'image' && (msg.mediaUrl != null || msg.localPath != null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (msg.localPath != null && File(msg.localPath!).existsSync())
                              ? Image.file(File(msg.localPath!), fit: BoxFit.cover)
                              : (msg.mediaUrl != null ? CachedImage(imageUrl: msg.mediaUrl!, fit: BoxFit.cover) : const SizedBox()),
                        ),
                      ),
                    if (msg.type == 'audio')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white24 : AppColors.secondary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.play_arrow, color: isMe ? Colors.white : AppColors.secondary),
                                onPressed: () => _audioService.playAudio(msg.localPath ?? ''),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "رسالة صوتية",
                              style: TextStyle(
                                color: isMe ? Colors.white.withOpacity(0.9) : AppColors.textSecondary,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_showEncryptedMessages.contains(msgKey)) {
                            _showEncryptedMessages.remove(msgKey);
                          } else {
                            _showEncryptedMessages.add(msgKey);
                          }
                        });
                      },
                      child: Text(
                        _showEncryptedMessages.contains(msgKey)
                            ? (msg.type == 'text' ? CryptoHelper.getRawCipherText(msg.text) : msg.text)
                            : (msg.type == 'text' ? CryptoHelper.decrypt(msg.text) : msg.text),
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.status == MessageStatus.read ? Icons.done_all : Icons.done,
                            size: 12,
                            color: msg.status == MessageStatus.read ? AppColors.accent : Colors.white70,
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
              if (msg.type == 'text')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_showEncryptedMessages.contains(msgKey)) {
                          _showEncryptedMessages.remove(msgKey);
                        } else {
                          _showEncryptedMessages.add(msgKey);
                        }
                      });
                    },
                    child: Icon(
                      _showEncryptedMessages.contains(msgKey) ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                onPressed: _showAttachmentMenu,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                  decoration: const InputDecoration(
                    hintText: "اكتب رسالة...",
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14, fontFamily: 'Cairo'),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {});
                    _socketService.sendTyping(widget.targetUserId, val.isNotEmpty);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onLongPressStart: (_) async {
                HapticFeedback.heavyImpact();
                setState(() => _isRecording = true);
                _socketService.sendRecording(widget.targetUserId, true);
                await _audioService.startRecording();
              },
              onLongPressEnd: (_) async {
                setState(() => _isRecording = false);
                _socketService.sendRecording(widget.targetUserId, false);
                String? path = await _audioService.stopRecording();
                if (path != null) _sendMediaMessage(path, 'audio');
              },
              onTap: () {
                if (_messageController.text.isNotEmpty) {
                  _sendMessage();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRecording ? AppColors.error : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppColors.error : AppColors.primary).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.mic : (_messageController.text.isEmpty ? Icons.mic_none : Icons.send_rounded),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: "صورة",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.file_present_rounded,
                  label: "ملف",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: "كاميرا",
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.camera);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }


  Future<void> _pickMedia(ImageSource source) async {
     final picker = ImagePicker();
     final pickedFile = await picker.pickImage(source: source);
     if (!mounted) return;
     if (pickedFile != null) _sendMediaMessage(pickedFile.path, 'image');
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (!mounted) return;
    if (result != null) _sendMediaMessage(result.files.single.path!, 'file', fileName: result.files.single.name);
  }

  Future<void> _sendMediaMessage(String filePath, String type, {String? fileName}) async {
    HapticFeedback.mediumImpact();
    
    // الرفع أولاً إلى السيرفر المخصص
    String? url = await ApiService.uploadFile(filePath, widget.userId, type: type);
    if (!mounted) return;
    if (url == null) return;

    final String tempId = DateTime.now().millisecondsSinceEpoch.toString();
    String textPlaceholder = type == 'image' ? '[صورة]' : (type == 'audio' ? '[رسالة صوتية]' : '[ملف]');
    
    // تشفير النص البديل للاتساق
    final encryptedText = await CryptoHelper.encrypt(textPlaceholder);
    if (!mounted) return;

    final msg = Message(
      senderId: widget.userId,
      targetId: widget.targetUserId,
      text: encryptedText,
      type: type,
      mediaUrl: url,
      localPath: filePath,
      fileName: fileName,
      senderMsgId: tempId,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    // تحديث الواجهة تفاؤلياً
    if (mounted) {
      setState(() => _messages.insert(0, msg));
    }

    // إرسال للسيرفر مع المعرف المؤقت
    _socketService.sendMessage(widget.targetUserId, encryptedText, type: type, mediaUrl: url, messageId: tempId);

    // الحفظ في قاعدة البيانات
    await dbService.insertMessage(msg);
  }
}
