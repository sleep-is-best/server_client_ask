import 'package:isar/isar.dart';

part 'chat_message.g.dart';

@collection
class ChatMessage {
  Id id = Isar.autoIncrement;

  @Index()
  String senderId = '';
  
  @Index()
  String receiverId = '';
  
  String text = '';
  
  DateTime timestamp = DateTime.now();
  
  bool isMe = false;

  String? type; // 'text', 'image', 'audio', 'file', 'location'
  String? mediaUrl;
  String? fileName;
  String? localPath;
  
  @Index()
  String? senderMsgId;

  int status = 1; // 0: pending, 1: sent, 2: delivered, 3: read, 4: failed
  
  int? burnDuration;
  DateTime? burnAt;

  ChatMessage();

  ChatMessage.create({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
    this.localPath,
    this.senderMsgId,
    this.status = 1,
    this.burnDuration,
    this.burnAt,
  });
}
