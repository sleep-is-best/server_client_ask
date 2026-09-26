
class Reel {
  final String? id;
  final String userId;
  final String? creatorName;
  final String? creatorProfileImage;
  final String? creatorRole;
  final String videoUrl;
  final String? thumbnail;
  final String? title;
  final String caption;
  final String? reference;
  final List<String> likes;
  final List<dynamic> comments;
  final int views;
  final int shares;
  final bool isLiked;
  final bool isFollowing;
  final DateTime timestamp;

  Reel({
    this.id,
    required this.userId,
    this.creatorName,
    this.creatorProfileImage,
    this.creatorRole,
    required this.videoUrl,
    this.thumbnail,
    this.title,
    required this.caption,
    this.reference,
    required this.likes,
    required this.comments,
    this.views = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isFollowing = false,
    required this.timestamp,
  });

  factory Reel.fromMap(Map<String, dynamic> map) {
    return Reel(
      id: map['id']?.toString(),
      userId: map['userId'] ?? '',
      creatorName: map['creatorName'],
      creatorProfileImage: map['creatorProfileImage'],
      creatorRole: map['creatorRole'],
      videoUrl: (map['videoUrl'] ?? map['video_url'] ?? map['url'] ?? '').toString(),
      thumbnail: map['thumbnail'] ?? '',
      title: map['title'] ?? '',
      caption: map['caption'] ?? '',
      reference: map['reference'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      comments: List<dynamic>.from(map['comments'] ?? []),
      views: map['views'] ?? 0,
      shares: map['shares'] ?? 0,
      isLiked: map['isLiked'] ?? false,
      isFollowing: map['isFollowing'] ?? false,
      timestamp: DateTime.tryParse(
            (map['timestamp'] ?? map['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'creatorName': creatorName,
      'creatorProfileImage': creatorProfileImage,
      'creatorRole': creatorRole,
      'videoUrl': videoUrl,
      'thumbnail': thumbnail,
      'title': title,
      'caption': caption,
      'reference': reference,
      'likes': likes,
      'comments': comments,
      'views': views,
      'shares': shares,
      'isLiked': isLiked,
      'isFollowing': isFollowing,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get creatorId => userId;
  int get likesCount => likes.length;
  int get commentsCount => comments.length;
  int get viewsCount => views;
}
