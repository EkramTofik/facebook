import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../services/supabase_service.dart';
import '../stories/create_story_screen.dart';
import '../stories/story_viewer_screen.dart';

/// Horizontal scrollable stories bar at the top of the feed
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  Map<String, List<StoryModel>> _groupedStories = {};
  bool _isLoading = true;
  String? _currentUserAvatar;

  @override
  void initState() {
    super.initState();
    _loadStories();
    _loadCurrentUserAvatar();
  }

  Future<void> _loadCurrentUserAvatar() async {
    final avatar = await SupabaseService.currentUserAvatar;
    if (mounted) {
      setState(() => _currentUserAvatar = avatar);
    }
  }

  Future<void> _loadStories() async {
    try {
      final grouped = await SupabaseService.getStoriesGroupedByUser();
      if (mounted) {
        setState(() {
          _groupedStories = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreateStory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    ).then((_) => _loadStories());
  }

  void _openStoryViewer(List<StoryModel> stories, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;
    final myStories = _groupedStories[currentUserId] ?? [];
    final otherStories = _groupedStories.entries
        .where((e) => e.key != currentUserId)
        .toList();

    return Container(
      height: 110,
      color: Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                // Add Story / My Story
                _StoryCircle(
                  isAddStory: myStories.isEmpty,
                  avatarUrl: _currentUserAvatar,
                  name: myStories.isEmpty ? 'Add Story' : 'Your Story',
                  hasUnseenStory: myStories.isNotEmpty,
                  onTap: myStories.isEmpty
                      ? _openCreateStory
                      : () => _openStoryViewer(myStories, 0),
                ),
                // Other users' stories
                ...otherStories.map((entry) {
                  final userStories = entry.value;
                  final firstStory = userStories.first;
                  return _StoryCircle(
                    avatarUrl: firstStory.authorAvatarUrl,
                    name: firstStory.authorName,
                    hasUnseenStory: true,
                    onTap: () => _openStoryViewer(userStories, 0),
                  );
                }),
              ],
            ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final bool isAddStory;
  final String? avatarUrl;
  final String name;
  final bool hasUnseenStory;
  final VoidCallback onTap;

  const _StoryCircle({
    this.isAddStory = false,
    this.avatarUrl,
    required this.name,
    this.hasUnseenStory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseenStory
                        ? const LinearGradient(
                            colors: [Color(0xFF1877F2), Color(0xFF00C6FF)],
                          )
                        : null,
                    border: hasUnseenStory
                        ? null
                        : Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.grey, size: 28)
                        : null,
                  ),
                ),
                if (isAddStory)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1877F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
