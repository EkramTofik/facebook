import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import 'post_card.dart';
import 'create_post_screen.dart';
import '../utils/constants.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Stream to get real-time updates from 'posts' table
  // Note: For a real app, you would join tables appropriately or use a view.
  // Here we will fetch posts and map them. Since Supabase stream returns Maps,
  // we will process them.
  // CRITICAL: .stream() on joined tables is tricky. 
  // For simplicity and robustness in this exam, we will use a FutureBuilder that refreshes,
  // or a simple stream on 'posts' without joins, then fetch user data separately.
  // BETTER APPROACH for Beginners: Use StreamBuilder for real-time.
  
  // We will stream the 'posts' table ordered by created_at.
  final _postsStream = SupabaseService.client
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackgroundColor,
      // Create Post Widget embedded in the list or as a header
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('facebook', 
              style: TextStyle(
                color: AppConstants.primaryColor, 
                fontWeight: FontWeight.bold, 
                fontSize: 28
              )
            ),
            backgroundColor: Colors.white,
            floating: true,
            actions: [
               IconButton(
                 icon: const Icon(Icons.add_circle, color: Colors.black),
                 onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
               ),
               IconButton(
                 icon: const Icon(Icons.search, color: Colors.black),
                 onPressed: () {},
               ),
            ],
          ),
          SliverToBoxAdapter(child: _buildCreatePostArea()),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _postsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(child: Center(child: Text('Error: ${snapshot.error}')));
              }
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }

              final data = snapshot.data!;
              if (data.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No posts yet! Be the first to post.'),
                )));
              }

              // Since stream returns only post data, we need to fetch user data.
              // For simplicity in this widget, we can't do async calls easily for every item in build.
              // TIP for Exams: Explain that normally you'd use a ViewModel or Join.
              // Here, we will map to PostModel. The 'user' field will be null initially if we don't join.
              // To Fix: We should update our query to include profiles, but Supabase SDK .stream() 
              // currently has limitations on deep joins.
              // WORKAROUND: We will return a FutureBuilder inside the ListView item OR
              // fetch the posts as a ONE-TIME Future with select('*, profiles(*)') for the initial load
              // and use a refresh indicator. 
              // Let's switch to FutureBuilder with Pull-to-Refresh for a robust "Production-like" feel
              // that supports Joins easily.
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final postMap = data[index];
                    // We need to fetch the user profile for this post lazily or render what we have.
                    // For now, let's create a wrapper that fetches the user profile.
                    
                    return _AsyncPostCard(postMap: postMap);
                  },
                  childCount: data.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostArea() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.grey, 
            child: Icon(Icons.person, color: Colors.white)
          ), // Current user avatar placeholder
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
              },
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                alignment: Alignment.centerLeft,
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text('What\'s on your mind?', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget to fetch user details for a post
class _AsyncPostCard extends StatelessWidget {
  final Map<String, dynamic> postMap;
  const _AsyncPostCard({required this.postMap});

  @override
  Widget build(BuildContext context) {
    // We already have the post data. 
    // If the stream doesn't include profile data, we fetch it here.
    final String userId = postMap['user_id'];
    
    return FutureBuilder(
      future: SupabaseService.client.from('profiles').select().eq('id', userId).single(),
      builder: (context, snapshot) {
        // Prepare PostModel with available data
        // If snapshot has data (user profile), we merge it.
        Map<String, dynamic> fullData = Map.from(postMap);
        if (snapshot.hasData) {
          fullData['profiles'] = snapshot.data;
        }
        
        // Pass to PostModel
        final post = PostModel.fromJson(fullData);
        
        return PostCard(post: post);
      },
    );
  }
}
