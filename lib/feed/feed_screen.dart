import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import '../widgets/stories_bar.dart';
import 'post_card.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoadingMore || (!_hasMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _offset = 0;
        _posts.clear();
        _hasMore = true;
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final newPosts = await SupabaseService.getPosts(
        offset: _offset,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _offset += newPosts.length;
          _hasMore = newPosts.length == _limit;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Feed load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        _hasMore &&
        !_isLoadingMore) {
      _loadPosts();
    }
  }

  Future<void> _refresh() async {
    await _loadPosts(refresh: true);
  }

  void _navigateToCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF1877F2),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Stories Bar
            const SliverToBoxAdapter(
              child: StoriesBar(),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 8, thickness: 8, color: Color(0xFFE4E6EB)),
            ),

            // Create Post Input Bar
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (SupabaseService.currentUserAvatar != null && SupabaseService.currentUserAvatar!.isNotEmpty)
                          ? CachedNetworkImageProvider(SupabaseService.currentUserAvatar!)
                          : null,
                      child: (SupabaseService.currentUserAvatar == null || SupabaseService.currentUserAvatar!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToCreatePost,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Text(
                            "What's on your mind?",
                            style: TextStyle(color: Colors.black87, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.photo_library, color: Colors.green, size: 28),
                      onPressed: _navigateToCreatePost,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 12, thickness: 12, color: Color(0xFFE4E6EB)),
            ),

            // Posts List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1877F2)),
                ),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    "No posts yet.\nBe the first to share!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _posts.length) {
                      return _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }

                    return PostCard(
                      post: _posts[index],
                      onDeleted: () {
                        setState(() => _posts.removeAt(index));
                      },
                      onUpdated: _refresh,
                    );
                  },
                  childCount: _posts.length + (_isLoadingMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1877F2),
        onPressed: _navigateToCreatePost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
