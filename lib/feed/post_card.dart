import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../utils/constants.dart';
import '../services/supabase_service.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool isLiked;
  late int likeCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLikedByMe;
    likeCount = widget.post.likeCount;
  }

  // Handle Like Button Press
  Future<void> _toggleLike() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      if (isLiked) {
        // Add like to DB
        await SupabaseService.client.from('likes').insert({
          'user_id': userId,
          'post_id': widget.post.id,
        });
      } else {
        // Remove like from DB
        await SupabaseService.client.from('likes').delete().match({
          'user_id': userId,
          'post_id': widget.post.id,
        });
      }
    } catch (e) {
      // Revert if error
      setState(() {
        isLiked = !isLiked;
        likeCount += isLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 0, // Flat design like FB
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.post.user?.avatarUrl != null 
                        ? NetworkImage(widget.post.user!.avatarUrl!) 
                        : null,
                    child: widget.post.user?.avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.user?.username ?? 'Unknown User',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(timeago.format(widget.post.createdAt),
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Post Text
            if (widget.post.content != null && widget.post.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(widget.post.content!),
              ),

            // Post Image
            if (widget.post.imageUrl != null)
              CachedNetworkImage(
                imageUrl: widget.post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200, 
                  color: Colors.grey[200], 
                  child: const Center(child: CircularProgressIndicator())
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),

            // Footer: Likes and Action Buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.thumb_up, size: 16, color: AppConstants.primaryColor),
                  const SizedBox(width: 4),
                  Text('$likeCount'),
                  const Spacer(),
                  Text('${widget.post.commentCount} Comments'),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PostButton(
                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  text: 'Like',
                  color: isLiked ? AppConstants.primaryColor : Colors.grey,
                  onTap: _toggleLike,
                ),
                _PostButton(
                  icon: Icons.comment_outlined,
                  text: 'Comment',
                  onTap: () {
                    // Navigate to comments (simplified for now: just show snackbar)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detailed view/comments TODO')));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color color;

  const _PostButton({
    required this.icon,
    required this.text,
    required this.onTap,
     this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
