enum MessageStatus { pending, sent, delivered, read }

class Message {
  int? id;
  final String senderId;
  final String targetId;
  final String text;
  final String type; // 'text', 'image', 'audio', 'file', 'location'
  final dynamic mediaData;
  final String? mediaUrl;
  final String? fileName;
  String? localPath;
  final int? senderMsgId; // معرف الرسالة لدى المرسل لغرض عدم التكرار
  final DateTime timestamp;
  final bool isMe;
  MessageStatus status;

  Message({
    this.id,
    required this.senderId,
    required this.targetId,
    required this.text,
    this.type = 'text',
    this.mediaData,
    this.mediaUrl,
    this.fileName,
    this.localPath,
    this.senderMsgId,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'targetId': targetId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'localPath': localPath,
      'senderMsgId': senderMsgId,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe ? 1 : 0,
      'status': status.index,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['senderId'] ?? '',
      targetId: map['targetId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      localPath: map['localPath'],
      senderMsgId: map['senderMsgId'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isMe: map['isMe'] == 1,
      status: MessageStatus.values[map['status'] ?? 1],
    );
  }

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    return Message(
      senderId: json['senderId'] ?? '',
      targetId: json['targetId'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'text',
      mediaData: json['mediaData'],
      mediaUrl: json['mediaUrl'] is String ? json['mediaUrl'] : null,
      fileName: json['fileName'],
      senderMsgId: json['messageId'], // نستخدم messageId القادم من السيرفر كـ senderMsgId
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isMe: json['senderId'] == currentUserId,
      status: MessageStatus.values[json['status'] ?? 1],
    );
  }
}
