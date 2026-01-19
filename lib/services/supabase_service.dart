import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/story_model.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

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

  static String? get currentUserEmail => client.auth.currentUser?.email;

  // ────────────────────────────────────────────────────────────────
  // CACHE FOR CURRENT USER PROFILE DATA
  // ────────────────────────────────────────────────────────────────
  static Map<String, dynamic>? _currentProfileCache;

  static Future<String?> get currentUserAvatar async {
    if (currentUserId == null) return null;

    if (_currentProfileCache != null &&
        _currentProfileCache!.containsKey('avatar_url')) {
      return _currentProfileCache!['avatar_url'] as String?;
    }

    try {
      final response = await client
          .from('profiles')
          .select('avatar_url, username')
          .eq('id', currentUserId!)
          .maybeSingle();

      if (response != null) {
        _currentProfileCache = response;
        return response['avatar_url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching current user avatar: $e');
      return null;
    }
  }

  static String? get currentUserName {
    return _currentProfileCache?['username'] as String? ??
        client.auth.currentUser?.userMetadata?['username'] ??
        client.auth.currentUser?.email?.split('@').first;
  }

  static Future<void> refreshCurrentProfile() async {
    _currentProfileCache = null;
    await currentUserAvatar;
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
    
    final response = await client
        .from('posts')
        .select('''
          *,
          profiles!author_id (*),
          reactions!left (reaction_type)
        ''')
        .or('visibility.eq.public,visibility.eq.friends')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // For each post, also get counts
    final posts = <PostModel>[];
    for (final json in response) {
      // Get reaction count for this post
      final reactionCountResponse = await client
          .from('reactions')
          .select()
          .eq('post_id', json['id'])
          .count(CountOption.exact);
      
      final commentsCountResponse = await client
          .from('comments')
          .select()
          .eq('post_id', json['id'])
          .count(CountOption.exact);

      // Filter reactions to only current user's
      final allReactions = json['reactions'] as List<dynamic>?;
      String? myReaction;
      if (allReactions != null && userId != null) {
        // The reactions from left join may include all, we need to query separately
      }

      // Get current user's reaction specifically
      if (userId != null) {
        final myReactionResponse = await client
            .from('reactions')
            .select('reaction_type')
            .eq('post_id', json['id'])
            .eq('user_id', userId)
            .maybeSingle();
        myReaction = myReactionResponse?['reaction_type'] as String?;
      }

      final enrichedJson = Map<String, dynamic>.from(json);
      enrichedJson['reaction_count'] = reactionCountResponse.count;
      enrichedJson['comments_count'] = commentsCountResponse.count;
      enrichedJson['reactions'] = myReaction != null ? [{'reaction_type': myReaction}] : [];

      posts.add(PostModel.fromJson(enrichedJson));
    }

    return posts;
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

    return CommentModel.fromJson(response);
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
