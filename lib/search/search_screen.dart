import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../feed/post_card.dart';
import '../utils/constants.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;
  
  List<UserModel> _people = [];
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 1) {
        _performSearch(query);
      } else {
        setState(() {
          _people = [];
          _posts = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await Future.wait([
        SupabaseService.searchProfiles(query),
        SupabaseService.searchPosts(query),
      ]);

      if (mounted) {
        setState(() {
          _people = results[0] as List<UserModel>;
          _posts = results[1] as List<PostModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppConstants.primaryColor,
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'PEOPLE'),
            Tab(text: 'POSTS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? _buildRecentSearches()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllResults(),
                    _buildPeopleResults(),
                    _buildPostsResults(),
                  ],
                ),
    );
  }

  Widget _buildRecentSearches() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Keep up with what\'s happening',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults() {
    final combined = [..._people, ..._posts];
    if (combined.isEmpty) return _buildNoResults();

    return ListView(
      children: [
        if (_people.isNotEmpty) ...[
          _buildSectionHeader('People'),
          ..._people.take(3).map((user) => _buildUserTile(user)),
          if (_people.length > 3)
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('See All People'),
            ),
        ],
        if (_posts.isNotEmpty) ...[
          _buildSectionHeader('Posts'),
          ..._posts.map((post) => PostCard(post: post)),
        ],
      ],
    );
  }

  Widget _buildPeopleResults() {
    if (_people.isEmpty) return _buildNoResults();
    return ListView.builder(
      itemCount: _people.length,
      itemBuilder: (context, index) => _buildUserTile(_people[index]),
    );
  }

  Widget _buildPostsResults() {
    if (_posts.isEmpty) return _buildNoResults();
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) => PostCard(post: _posts[index]),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Text(
        'No results found for "${_searchController.text}"',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(user.username),
      subtitle: user.fullName != null ? Text(user.fullName!) : null,
      onTap: () {
        // Navigate to profile
      },
    );
  }
}
