enum MessageStatus { pending, sent, delivered, read, failed }

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
  final String? senderMsgId; // معرف الرسالة لدى المرسل لغرض عدم التكرار
  final DateTime timestamp;
  final bool isMe;
  MessageStatus status;
  final int? burnDuration; // Duration in seconds, null if not self-destructing
  DateTime? burnAt;

  // New fields for phone-first identification
  final String? senderName;
  final String? senderPhone;
  final String? targetName;
  final String? targetPhone;

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
    this.burnDuration,
    this.burnAt,
    this.senderName,
    this.senderPhone,
    this.targetName,
    this.targetPhone,
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
      'burnDuration': burnDuration,
      'burnAt': burnAt?.toIso8601String(),
      'senderName': senderName,
      'senderPhone': senderPhone,
      'targetName': targetName,
      'targetPhone': targetPhone,
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
      burnDuration: map['burnDuration'],
      burnAt: map['burnAt'] != null ? DateTime.parse(map['burnAt']) : null,
      senderName: map['senderName'],
      senderPhone: map['senderPhone'],
      targetName: map['targetName'],
      targetPhone: map['targetPhone'],
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
      burnDuration: json['burnDuration'],
      burnAt: json['burnAt'] != null ? DateTime.parse(json['burnAt']) : null,
      senderName: json['senderName'],
      senderPhone: json['senderPhone'],
      targetName: json['targetName'],
      targetPhone: json['targetPhone'],
    );
  }
}
