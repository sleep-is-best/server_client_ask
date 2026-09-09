class Answer {
  final String? id;
  final String questionId;
  final String userId;
  final String content;
  final DateTime timestamp;
  final bool isBest;

  final List<String>? mediaUrls;
  final List<String>? localPaths;
  final String? mediaType;
  final List<String> votes;

  Answer({
    this.id,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.isBest = false,
    this.mediaUrls,
    this.localPaths,
    this.mediaType,
    this.votes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'userId': userId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isBest': isBest,
      'mediaUrls': mediaUrls,
      'localPaths': localPaths,
      'mediaType': mediaType,
      'votes': votes,
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
      mediaUrls: map['mediaUrls'] != null ? List<String>.from(map['mediaUrls']) : null,
      localPaths: map['localPaths'] != null ? List<String>.from(map['localPaths']) : null,
      mediaType: map['mediaType']?.toString(),
      votes: map['votes'] != null ? List<String>.from(map['votes']) : [],
    );
  }
}
