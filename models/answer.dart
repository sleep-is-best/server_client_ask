class Answer {
  final String? id;
  final String questionId;
  final String userId;
  final String content;
  final DateTime timestamp;
  final bool isBest;

  Answer({
    this.id,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.isBest = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'userId': userId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isBest': isBest ? 1 : 0,
    };
  }

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['id']?.toString(),
      questionId: map['questionId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? 'unknown',
      content: map['content']?.toString() ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isBest: map['isBest'] == 1 || map['isBest'] == true || map['isBest'] == '1',
    );
  }
}
