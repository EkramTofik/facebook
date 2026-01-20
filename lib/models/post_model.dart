/// Model representing a post in the feed
class PostModel {
  final String id;
  final String authorId;
  final String? content;
  final String? imageUrl;
  final String visibility;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? profiles;
  final int reactionCount;
  final int commentsCount;
  final String? myReaction; // 'like', 'love', 'haha', 'wow', 'sad', 'angry', or null

  String get authorName => (profiles?['username'] as String?) ?? 'Unknown';
  String? get authorAvatarUrl => profiles?['avatar_url'] as String?;

  PostModel({
    required this.id,
    required this.authorId,
    this.content,
    this.imageUrl,
    required this.visibility,
    required this.createdAt,
    this.updatedAt,
    this.profiles,
    this.reactionCount = 0,
    this.commentsCount = 0,
    this.myReaction,
    this.sharedPostId,
    this.sharedPost,
  });

  final String? sharedPostId;
  final PostModel? sharedPost;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Extract my reaction from reactions array if present
    String? myReaction;
    final reactions = json['reactions'] as List<dynamic>?;
    if (reactions != null && reactions.isNotEmpty) {
      myReaction = reactions.first['reaction_type'] as String?;
    }

    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      profiles: json['profiles'] as Map<String, dynamic>?,
      reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      myReaction: myReaction,
      sharedPostId: json['shared_post_id'] as String?,
      sharedPost: json['shared_post'] != null 
          ? PostModel.fromJson(json['shared_post'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create a copy with updated fields
  PostModel copyWith({
    String? content,
    String? imageUrl,
    int? reactionCount,
    int? commentsCount,
    String? myReaction,
    bool clearReaction = false,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      visibility: visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
      profiles: profiles,
      reactionCount: reactionCount ?? this.reactionCount,
      commentsCount: commentsCount ?? this.commentsCount,
      myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
    );
  }
}
