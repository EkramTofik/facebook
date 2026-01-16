import 'user_model.dart';

class PostModel {
  final String id;
  final String userId;
  final String? content;
  final String? imageUrl;
  final DateTime createdAt;
  
  // We often join the 'profiles' table to get the user name and avatar
  final UserModel? user; 
  
  // We can also fetch counts if we use Supabase count functionality
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe; // Helper to show if current user liked it

  PostModel({
    required this.id,
    required this.userId,
    this.content,
    this.imageUrl,
    required this.createdAt,
    this.user,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['user_id'],
      content: json['content'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      // If we joined 'profiles' in the query, it will be in the json map
      user: json['profiles'] != null ? UserModel.fromJson(json['profiles']) : null,
      // These counts would come from a tailored query or separate count fetching
      // For simplicity in this tutorial, we might handle counts separately, 
      // but here is how you would map them if your query returns them.
      likeCount: json['likes'] != null ? (json['likes'] as List).length : 0,
      // For 'isLikedByMe', we usually process the list of likes in the frontend logic
      // or using a specific RPC. We will handle this logic in the UI layer for simplicity.
    );
  }
}
