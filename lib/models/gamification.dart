class Badge {
  final String id;
  final String name;
  final String icon;
  final int minPoints;
  final DateTime awardedAt;

  Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.minPoints,
    required this.awardedAt,
  });

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      minPoints: map['minPoints'] ?? 0,
      awardedAt: DateTime.parse(map['awardedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class ReputationTransaction {
  final String id;
  final String studentId;
  final int points;
  final String reason;
  final String type;
  final DateTime timestamp;

  ReputationTransaction({
    required this.id,
    required this.studentId,
    required this.points,
    required this.reason,
    required this.type,
    required this.timestamp,
  });

  factory ReputationTransaction.fromMap(Map<String, dynamic> map) {
    return ReputationTransaction(
      id: map['id'],
      studentId: map['studentId'],
      points: map['points'],
      reason: map['reason'],
      type: map['type'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Bookmark {
  final String id;
  final String targetType; // 'question', 'reel', 'material'
  final String targetId;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      targetType: map['targetType'],
      targetId: map['targetId'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
