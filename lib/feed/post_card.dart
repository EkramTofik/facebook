import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post_model.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import 'comments_sheet.dart';
import 'edit_post_screen.dart';

/// A single post card with reactions, comments, and owner-only edit/delete
class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late String? _myReaction;
  late int _reactionCount;
  late int _commentsCount;

  @override
  void initState() {
    super.initState();
    _myReaction = widget.post.myReaction;
    _reactionCount = widget.post.reactionCount;
    _commentsCount = widget.post.commentsCount;
  }

  bool get _isOwner => widget.post.authorId == SupabaseService.currentUserId;

  Future<void> _handleReaction(String reactionType) async {
    final oldReaction = _myReaction;
    final oldCount = _reactionCount;

    // Optimistic update
    setState(() {
      if (_myReaction == reactionType) {
        _myReaction = null;
        _reactionCount--;
      } else {
        if (_myReaction == null) _reactionCount++;
        _myReaction = reactionType;
      }
    });

    try {
      final newReaction = await SupabaseService.toggleReaction(
        postId: widget.post.id,
        reactionType: reactionType,
      );
      
      if (mounted) {
        setState(() => _myReaction = newReaction);
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _myReaction = oldReaction;
          _reactionCount = oldCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ReactionButton(
              emoji: '👍',
              label: 'Like',
              isSelected: _myReaction == 'like',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('like');
              },
            ),
            _ReactionButton(
              emoji: '❤️',
              label: 'Love',
              isSelected: _myReaction == 'love',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('love');
              },
            ),
            _ReactionButton(
              emoji: '😂',
              label: 'Haha',
              isSelected: _myReaction == 'haha',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('haha');
              },
            ),
            _ReactionButton(
              emoji: '😮',
              label: 'Wow',
              isSelected: _myReaction == 'wow',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('wow');
              },
            ),
            _ReactionButton(
              emoji: '😢',
              label: 'Sad',
              isSelected: _myReaction == 'sad',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('sad');
              },
            ),
            _ReactionButton(
              emoji: '😡',
              label: 'Angry',
              isSelected: _myReaction == 'angry',
              onTap: () {
                Navigator.pop(ctx);
                _handleReaction('angry');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.post.id,
        onCommentsCountChanged: (count) {
          if (mounted) setState(() => _commentsCount = count);
        },
      ),
    );
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Post'),
              onTap: () {
                Navigator.pop(ctx);
                _editPost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deletePost();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editPost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(post: widget.post),
      ),
    );

    if (result == true) {
      widget.onUpdated?.call();
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deletePost(widget.post.id);
        widget.onDeleted?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _getReactionEmoji(String? reaction) {
    switch (reaction) {
      case 'like': return '👍';
      case 'love': return '❤️';
      case 'haha': return '😂';
      case 'wow': return '😮';
      case 'sad': return '😢';
      case 'angry': return '😡';
      default: return '👍';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.post.authorName;
    final avatarUrl = widget.post.authorAvatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            timeago.format(widget.post.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.public,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isOwner)
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.black54),
                    onPressed: _showPostOptions,
                  ),
              ],
            ),
          ),

          // Content
          if (widget.post.content != null && widget.post.content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                widget.post.content!,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          // Image
          if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.post.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 800, // Optimize memory by resizing image in cache
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 60),
              ),
            ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                if (_reactionCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_getReactionEmoji(_myReaction ?? 'like'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$_reactionCount', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '$_commentsCount comments',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE4E6EB)),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: _myReaction != null ? null : Icons.thumb_up_outlined,
                emoji: _myReaction != null ? _getReactionEmoji(_myReaction) : null,
                label: _myReaction != null
                    ? _myReaction![0].toUpperCase() + _myReaction!.substring(1)
                    : 'Like',
                color: _myReaction != null ? AppConstants.primaryColor : null,
                onTap: () => _handleReaction('like'),
                onLongPress: _showReactionPicker,
              ),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: 'Comment',
                onTap: _openComments,
              ),
              _ActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppConstants.primaryColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionButton({
    this.icon,
    this.emoji,
    required this.label,
    this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.grey[700];

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 18))
            else if (icon != null)
              Icon(icon, color: displayColor, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: displayColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
