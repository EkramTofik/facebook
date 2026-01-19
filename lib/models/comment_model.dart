import 'user_model.dart';

/// Model representing a comment on a post with optional nested replies
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String? parentId;
  final String content;
  final DateTime createdAt;
  final UserModel? author;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.author,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      parentId: json['parent_id'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      replies: const [],
    );
  }

  /// Create a copy with replies attached
  CommentModel copyWithReplies(List<CommentModel> replies) {
    return CommentModel(
      id: id,
      postId: postId,
      authorId: authorId,
      parentId: parentId,
      content: content,
      createdAt: createdAt,
      author: author,
      replies: replies,
    );
  }
}
