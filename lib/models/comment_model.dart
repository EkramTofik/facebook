import 'user_model.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final UserModel? user;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.user,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      user: json['profiles'] != null ? UserModel.fromJson(json['profiles']) : null,
    );
  }
}
