/// Model representing a temporary story (expires after 24 hours)
class StoryModel {
  final String id;
  final String authorId;
  final String? content;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic>? profiles;

  String get authorName => (profiles?['username'] as String?) ?? 'Unknown';
  String? get authorAvatarUrl => profiles?['avatar_url'] as String?;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  StoryModel({
    required this.id,
    required this.authorId,
    this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
    this.profiles,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      profiles: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'author_id': authorId,
    'content': content,
    'image_url': imageUrl,
  };
}
