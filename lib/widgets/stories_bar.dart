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
      height: 200,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Create Story Card
                _StoryCard(
                  isAddStory: true,
                  avatarUrl: _currentUserAvatar,
                  name: 'Create story',
                  onTap: _openCreateStory,
                ),
                // Other users' stories
                ...otherStories.map((entry) {
                  final userStories = entry.value;
                  final firstStory = userStories.first;
                  return _StoryCard(
                    avatarUrl: firstStory.authorAvatarUrl,
                    storyImageUrl: firstStory.imageUrl,
                    name: firstStory.authorName,
                    onTap: () => _openStoryViewer(userStories, 0),
                  );
                }),
                // Mock Friend Suggestions (to match the design image)
                _StoryCard(
                  isSuggestion: true,
                  avatarUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTLOfv1543QS1cF3kFJTNRfBhKVWw8yoOdaKA&s',
                  name: 'Muna Seid',
                  onTap: () {},
                ),
              ],
            ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final bool isAddStory;
  final bool isSuggestion;
  final String? avatarUrl;
  final String? storyImageUrl;
  final String name;
  final VoidCallback onTap;

  const _StoryCard({
    this.isAddStory = false,
    this.isSuggestion = false,
    this.avatarUrl,
    this.storyImageUrl,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSuggestion ? Border.all(color: Colors.grey[200]!) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (isSuggestion)
              Container(color: Colors.white)
            else if (isAddStory)
              (avatarUrl != null
                  ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey[200]))
            else if (storyImageUrl != null)
              CachedNetworkImage(imageUrl: storyImageUrl!, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[300]),

            // Overlay for readability (except suggestions)
            if (!isSuggestion)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),

            // Content
            if (isSuggestion)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ),
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_add, size: 16, color: Color(0xFF1877F2)),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              )
            else if (isAddStory)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   const Spacer(flex: 2),
                   Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF1877F2),
                      child: Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF1877F2),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
