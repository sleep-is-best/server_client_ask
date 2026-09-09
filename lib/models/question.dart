class Question {
  String? id;
  final String userId;
  final String content;
  final List<String>? mediaUrls;
  final List<String>? localPaths;
  final String? mediaType; // 'image', 'file', 'video'
  final DateTime timestamp;
  int points;
  int answerCount;
  final List<String> votes;
  final String? bestAnswerId;

  Question({
    this.id,
    required this.userId,
    required this.content,
    this.mediaUrls,
    this.localPaths,
    this.mediaType,
    required this.timestamp,
    this.points = 0,
    this.answerCount = 0,
    this.votes = const [],
    this.bestAnswerId,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'content': content,
      'mediaUrls': mediaUrls,
      'localPaths': localPaths,
      'mediaType': mediaType,
      'timestamp': timestamp.toIso8601String(),
      'points': points,
      'answerCount': answerCount,
      'votes': votes,
      'bestAnswerId': bestAnswerId,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id']?.toString(),
      userId: map['userId']?.toString() ?? 'unknown',
      content: map['content']?.toString() ?? '',
      mediaUrls: map['mediaUrls'] != null ? List<String>.from(map['mediaUrls']) : (map['mediaUrl'] != null ? [map['mediaUrl'].toString()] : null),
      localPaths: map['localPaths'] != null ? List<String>.from(map['localPaths']) : null,
      mediaType: map['mediaType']?.toString(),
      timestamp: map['timestamp'] != null 
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      points: map['points'] is num ? (map['points'] as num).toInt() : (int.tryParse(map['points']?.toString() ?? '0') ?? 0),
      answerCount: map['answerCount'] is num ? (map['answerCount'] as num).toInt() : (int.tryParse(map['answerCount']?.toString() ?? '0') ?? 0),
      votes: map['votes'] != null ? List<String>.from(map['votes']) : [],
      bestAnswerId: map['bestAnswerId']?.toString(),
    );
  }
}
