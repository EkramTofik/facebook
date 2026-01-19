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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'facebook',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.8,
          ),
        ),
        actions: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.add, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.search, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.messenger_outline, color: Colors.black87),
          ),
          const SizedBox(width: 12),
        ],
      ),
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    FutureBuilder<String?>(
                      future: SupabaseService.currentUserAvatar,
                      builder: (context, snapshot) {
                        final avatarUrl = snapshot.data;
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToCreatePost,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            "What's on your mind?",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
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
