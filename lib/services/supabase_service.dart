import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/story_model.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';

/// SupabaseService handles global access to the Supabase client.
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Session? get session => client.auth.currentSession;

  static User? get user => client.auth.currentUser;

  static String? get currentUserId => client.auth.currentUser?.id;

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    return await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
  }

  static Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*),
            shared_post:shared_post_id (
              *,
              profiles!author_id (*)
            )
          ''')
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response)
          .map((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user posts with joins: $e');
      // Fallback for missing shared_post_id
      final response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*)
          ''')
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response)
          .map((json) => PostModel.fromJson(json))
          .toList();
    }
  }

  static String? get currentUserEmail => client.auth.currentUser?.email;

  // ────────────────────────────────────────────────────────────────
  // CACHE FOR CURRENT USER PROFILE DATA
  // ────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? _currentProfileCache;

  static String? get currentUserAvatar {
    return _currentProfileCache?['avatar_url'] as String?;
  }

  static String? get currentUserName {
    return _currentProfileCache?['username'] as String? ??
        client.auth.currentUser?.userMetadata?['username'] ??
        client.auth.currentUser?.email?.split('@').first;
  }

  /// Asynchronously loads or refreshes the current user's profile into cache
  static Future<void> refreshCurrentProfile() async {
    if (currentUserId == null) return;
    try {
      final response = await client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', currentUserId!)
          .maybeSingle();

      if (response != null) {
        _currentProfileCache = response;
      }
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
    _currentProfileCache = null;
  }

  /// Sign In with Google (with proper redirect handling)
  static Future<bool> signInWithGoogle() async {
    try {
      String? redirectUrl;

      if (kIsWeb) {
        redirectUrl = Uri.base.origin;
      } else {
        redirectUrl = 'io.supabase.facebookclone://login-callback';
      }

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      return true;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // POSTS CRUD
  // ────────────────────────────────────────────────────────────────

  /// Fetch posts with profiles and user's reaction
  static Future<List<PostModel>> getPosts({int offset = 0, int limit = 10}) async {
    final userId = currentUserId;
    
    dynamic response;
    try {
      response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*),
            reactions!left (reaction_type),
            shared_post:shared_post_id (
              *,
              profiles!author_id (*)
            )
          ''')
          .or('visibility.eq.public,visibility.eq.friends')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error fetching posts with joins: $e');
      // Fallback if shared_post_id doesn't exist yet
      response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*),
            reactions!left (reaction_type)
          ''')
          .or('visibility.eq.public,visibility.eq.friends')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }

    final postList = <PostModel>[];
    for (final json in response) {
      final data = Map<String, dynamic>.from(json);
      
      int reactionCount = 0;
      int commentsCount = 0;
      
      try {
        // Get counts by fetching IDs (robust approach that avoids version-specific API issues)
        final reactionRes = await client
            .from('reactions')
            .select('id')
            .eq('post_id', json['id']);
        
        final commentRes = await client
            .from('comments')
            .select('id')
            .eq('post_id', json['id']);
            
        reactionCount = (reactionRes as List).length;
        commentsCount = (commentRes as List).length;
      } catch (e) {
        debugPrint('Error fetching counts for post ${json['id']}: $e');
      }

      // Get current user's reaction specifically
      String? myReaction;
      if (userId != null) {
        final myReactionResponse = await client
            .from('reactions')
            .select('reaction_type')
            .eq('post_id', json['id'])
            .eq('user_id', userId)
            .maybeSingle();
        myReaction = myReactionResponse?['reaction_type'] as String?;
      }

      data['reaction_count'] = reactionCount;
      data['comments_count'] = commentsCount;
      data['reactions'] = myReaction != null ? [{'reaction_type': myReaction}] : [];
      
      postList.add(PostModel.fromJson(data));
    }
    
    return postList;
  }

  /// Create a new post
  static Future<void> createPost({
    required String? content,
    String? imagePath,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _ensureProfileExists();

    String? imageUrl;
    if (imagePath != null) {
      final file = File(imagePath);
      final fileName = '${DateTime.now().toIso8601String()}_$userId.jpg';
      final path = 'posts/$fileName';

      await client.storage.from('post_images').upload(path, file);
      imageUrl = client.storage.from('post_images').getPublicUrl(path);
    }

    await client.from('posts').insert({
      'author_id': userId,
      'content': content,
      'image_url': imageUrl,
      'visibility': 'public',
    });
  }

  /// Share an existing post
  static Future<void> sharePost({
    required String postId,
    String? content,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _ensureProfileExists();

    await client.from('posts').insert({
      'author_id': userId,
      'content': content,
      'shared_post_id': postId,
      'visibility': 'public',
    });
  }

  /// Update an existing post (owner only - enforced by RLS)
  static Future<void> updatePost({
    required String postId,
    String? content,
    String? imageUrl,
  }) async {
    await client.from('posts').update({
      'content': content,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
  }

  /// Delete a post (owner only - enforced by RLS)
  static Future<void> deletePost(String postId) async {
    await client.from('posts').delete().eq('id', postId);
  }

  // ────────────────────────────────────────────────────────────────
  // REACTIONS
  // ────────────────────────────────────────────────────────────────

  /// Toggle or change reaction on a post
  /// Returns the new reaction state (null if removed)
  static Future<String?> toggleReaction({
    required String postId,
    required String reactionType,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _ensureProfileExists();

    // Check if user already has a reaction
    final existing = await client
        .from('reactions')
        .select('id, reaction_type')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      if (existing['reaction_type'] == reactionType) {
        // Same reaction - remove it
        await client.from('reactions').delete().eq('id', existing['id']);
        return null;
      } else {
        // Different reaction - update it
        await client.from('reactions').update({
          'reaction_type': reactionType,
        }).eq('id', existing['id']);
        return reactionType;
      }
    } else {
      // No existing reaction - add new
      await client.from('reactions').insert({
        'user_id': userId,
        'post_id': postId,
        'reaction_type': reactionType,
      });

      // Create notification for post author
      try {
        final post = await client.from('posts').select('author_id').eq('id', postId).single();
        final authorId = post['author_id'] as String;
        
        if (authorId != userId) {
          await client.from('notifications').insert({
            'recipient_id': authorId,
            'sender_id': userId,
            'type': 'like',
            'content': 'reacted to your post',
            'related_id': postId,
          });
        }
      } catch (e) {
        debugPrint('Error creating reaction notification: $e');
      }

      return reactionType;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // COMMENTS
  // ────────────────────────────────────────────────────────────────

  /// Get comments for a post with nested replies
  static Future<List<CommentModel>> getComments(String postId) async {
    final response = await client
        .from('comments')
        .select('''
          *,
          profiles!author_id (*)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final allComments = response.map((json) => CommentModel.fromJson(json)).toList();

    // Build tree structure - separate top-level comments and replies
    final topLevel = allComments.where((c) => c.parentId == null).toList();
    final replies = allComments.where((c) => c.parentId != null).toList();

    // Attach replies to their parent comments
    return topLevel.map((parent) {
      final childReplies = replies.where((r) => r.parentId == parent.id).toList();
      return parent.copyWithReplies(childReplies);
    }).toList();
  }

  /// Add a comment or reply
  static Future<CommentModel> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _ensureProfileExists();

    final response = await client
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': userId,
          'content': content,
          'parent_id': parentId,
        })
        .select('''
          *,
          profiles!author_id (*)
        ''')
        .single();
    final comment = CommentModel.fromJson(response);

    // Create notification for post author
    try {
      final post = await client.from('posts').select('author_id').eq('id', postId).single();
      final authorId = post['author_id'] as String;

      if (authorId != userId) {
        await client.from('notifications').insert({
          'recipient_id': authorId,
          'sender_id': userId,
          'type': 'comment',
          'content': 'commented on your post: "${content.length > 30 ? content.substring(0, 30) + '...' : content}"',
          'related_id': postId,
        });
      }
    } catch (e) {
      debugPrint('Error creating comment notification: $e');
    }

    return comment;
  }

  /// Delete a comment (owner only - enforced by RLS)
  static Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  // ────────────────────────────────────────────────────────────────
  // STORIES
  // ────────────────────────────────────────────────────────────────

  /// Get all active (non-expired) stories
  static Future<List<StoryModel>> getActiveStories() async {
    final response = await client
        .from('stories')
        .select('''
          *,
          profiles!author_id (*)
        ''')
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);

    return response.map((json) => StoryModel.fromJson(json)).toList();
  }

  /// Create a new story
  static Future<void> createStory({
    required String imagePath,
    String? content,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _ensureProfileExists();

    final file = File(imagePath);
    final fileName = '${DateTime.now().toIso8601String()}_$userId.jpg';
    final path = 'stories/$fileName';

    await client.storage.from('story_images').upload(path, file);
    final imageUrl = client.storage.from('story_images').getPublicUrl(path);

    await client.from('stories').insert({
      'author_id': userId,
      'content': content,
      'image_url': imageUrl,
    });
  }

  /// Delete a story (owner only - enforced by RLS)
  static Future<void> deleteStory(String storyId) async {
    await client.from('stories').delete().eq('id', storyId);
  }

  /// Get stories grouped by user
  static Future<Map<String, List<StoryModel>>> getStoriesGroupedByUser() async {
    final stories = await getActiveStories();
    final grouped = <String, List<StoryModel>>{};

    for (final story in stories) {
      grouped.putIfAbsent(story.authorId, () => []).add(story);
    }

    return grouped;
  }

  // ────────────────────────────────────────────────────────────────
  // FRIENDS SYSTEM
  // ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await client
        .from('friends')
        .select('''
          *,
          sender:profiles!user_id (id, username, avatar_url)
        ''')
        .eq('friend_id', userId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getFriendSuggestions() async {
    final userId = currentUserId;
    if (userId == null) return [];

    // Simple suggestion logic: profiles that are not the current user and not already friends/requested
    final friendsResponse = await client
        .from('friends')
        .select('friend_id, user_id')
        .or('user_id.eq.$userId,friend_id.eq.$userId');

    final friendIds = friendsResponse
        .map((f) => f['user_id'] == userId ? f['friend_id'] : f['user_id'])
        .toList();
    friendIds.add(userId);

    final response = await client
        .from('profiles')
        .select()
        .not('id', 'in', '(${friendIds.join(',')})')
        .limit(10);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateFriendStatus(String friendshipId, String status) async {
    await client
        .from('friends')
        .update({'status': status})
        .eq('id', friendshipId);
  }

  static Future<void> sendFriendRequest(String friendId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _ensureProfileExists();

    await client.from('friends').insert({
      'user_id': userId,
      'friend_id': friendId,
      'status': 'pending',
    });

    // Create notification
    try {
      await client.from('notifications').insert({
        'recipient_id': friendId,
        'sender_id': userId,
        'type': 'friend_request',
        'content': 'sent you a friend request',
        'related_id': userId, // In this case, relates to the sender
      });
    } catch (e) {
      debugPrint('Error creating friend request notification: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await client
        .from('notifications')
        .select('''
          *,
          sender:profiles!sender_id (id, username, avatar_url)
        ''')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  static Future<void> markAllNotificationsAsRead() async {
    final userId = currentUserId;
    if (userId == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId);
  }

  static Future<void> seedMockNotifications() async {
    final userId = currentUserId;
    if (userId == null) return;

    // Check if we already have notifications
    final existing = await client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .limit(1);

    if ((existing as List).isNotEmpty) return;

    // Get some mock profiles to be senders
    final profiles = await client
        .from('profiles')
        .select('id')
        .neq('id', userId)
        .limit(3);

    if ((profiles as List).isEmpty) return;

    final senderIds = (profiles as List).map((p) => p['id'] as String).toList();

    final mockNotifs = [
      {
        'recipient_id': userId,
        'sender_id': senderIds[0],
        'type': 'like',
        'content': 'liked your photo',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
      {
        'recipient_id': userId,
        'sender_id': senderIds[1 % senderIds.length],
        'type': 'comment',
        'content': 'commented on your post: "Amazing work! 🔥"',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'recipient_id': userId,
        'sender_id': senderIds[2 % senderIds.length],
        'type': 'friend_request',
        'content': 'sent you a friend request',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      },
      {
        'recipient_id': userId,
        'sender_id': senderIds[0],
        'type': 'post',
        'content': 'shared a new post you might like',
        'is_read': true,
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'recipient_id': userId,
        'sender_id': senderIds[1 % senderIds.length],
        'type': 'like',
        'content': 'and 5 others liked your status update',
        'is_read': true,
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];

    await client.from('notifications').insert(mockNotifs);
  }

  // ────────────────────────────────────────────────────────────────
  // SEARCH
  // ────────────────────────────────────────────────────────────────

  /// Search for profiles by username or full name
  static Future<List<UserModel>> searchProfiles(String query) async {
    final response = await client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,full_name.ilike.%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response)
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  /// Search for posts by content
  static Future<List<PostModel>> searchPosts(String query) async {
    try {
      final response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*),
            shared_post:shared_post_id (
              *,
              profiles!author_id (*)
            )
          ''')
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response)
          .map((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback if shared_post relationship is missing
      final response = await client
          .from('posts')
          .select('''
            *,
            profiles!author_id (*)
          ''')
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response)
          .map((json) => PostModel.fromJson(json))
          .toList();
    }
  }

  // ────────────────────────────────────────────────────────────────
  // UTILITIES
  // ────────────────────────────────────────────────────────────────

  /// Internal helper to ensure a profile exists before database writes.
  /// Fixes 'ForeignKeyViolation' errors for users without profiles.
  static Future<void> _ensureProfileExists() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final profile = await client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        final email = currentUserEmail;
        final name = currentUserName;
        await client.from('profiles').insert({
          'id': userId,
          'email': email,
          'username': name ?? email?.split('@').first ?? 'user_${userId.substring(0, 5)}',
        });
        await refreshCurrentProfile();
      }
    } catch (e) {
      debugPrint('Error ensuring profile existence: $e');
    }
  }

}
