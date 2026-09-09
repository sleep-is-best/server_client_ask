class Specialization {
  final int id;
  final String name;
  final String? icon;

  Specialization({required this.id, required this.name, this.icon});

  factory Specialization.fromMap(Map<String, dynamic> map) {
    return Specialization(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
    );
  }
}

class Level {
  final int id;
  final int specializationId;
  final String name;

  Level({required this.id, required this.specializationId, required this.name});

  factory Level.fromMap(Map<String, dynamic> map) {
    return Level(
      id: map['id'],
      specializationId: map['specialization_id'],
      name: map['name'],
    );
  }
}

class Subject {
  final int id;
  final int levelId;
  final int semesterId;
  final String name;

  Subject({required this.id, required this.levelId, required this.semesterId, required this.name});

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      levelId: map['level_id'],
      semesterId: map['semester_id'],
      name: map['name'],
    );
  }
}

class EducationalMaterial {
  final String? id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final String? creatorRole;
  final String? creatorProfileImage;
  final int specializationId;
  final int levelId;
  final int semesterId;
  final int subjectId;
  final String subjectName;
  final String materialType; // 'summary', 'malzam', 'exam_model'
  final String fileUrl;
  final String? thumbnailUrl;
  final int fileSize;
  final String fileType;
  final String status; // 'pending', 'approved', 'rejected', 'hidden', 'deleted'
  final String? rejectionReason;
  int viewsCount;
  int downloadsCount;
  final DateTime createdAt;

  EducationalMaterial({
    this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorName,
    this.creatorRole,
    this.creatorProfileImage,
    required this.specializationId,
    required this.levelId,
    required this.semesterId,
    required this.subjectId,
    required this.subjectName,
    required this.materialType,
    required this.fileUrl,
    this.thumbnailUrl,
    this.fileSize = 0,
    required this.fileType,
    this.status = 'pending',
    this.rejectionReason,
    this.viewsCount = 0,
    this.downloadsCount = 0,
    required this.createdAt,
  });

  factory EducationalMaterial.fromMap(Map<String, dynamic> map) {
    return EducationalMaterial(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      creatorId: map['creator_id'] ?? '',
      creatorName: map['creator_name'] ?? '',
      creatorRole: map['creator_role'],
      creatorProfileImage: map['creator_profile_image'],
      specializationId: map['specialization_id'] ?? 0,
      levelId: map['level_id'] ?? 0,
      semesterId: map['semester_id'] ?? 0,
      subjectId: map['subject_id'] ?? 0,
      subjectName: map['subject_name'] ?? '',
      materialType: map['material_type'] ?? 'summary',
      fileUrl: map['file_url'] ?? '',
      thumbnailUrl: map['thumbnail_url'],
      fileSize: map['file_size'] ?? 0,
      fileType: map['file_type'] ?? 'pdf',
      status: map['status'] ?? 'pending',
      rejectionReason: map['rejection_reason'],
      viewsCount: map['views_count'] ?? 0,
      downloadsCount: map['downloads_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'creator_id': creatorId,
      'specialization_id': specializationId,
      'level_id': levelId,
      'semester_id': semesterId,
      'subject_id': subjectId,
      'material_type': materialType,
      'file_url': fileUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
      'file_type': fileType,
      'status': status,
    };
  }
}
