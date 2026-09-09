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

  String? type; // 'text', 'image', 'audio'
  String? mediaUrl;
  
  bool isRead = false;

  ChatMessage();

  ChatMessage.create({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type = 'text',
    this.mediaUrl,
    this.isRead = false,
  });
}
