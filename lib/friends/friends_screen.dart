import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/supabase_service.dart';
import '../utils/constants.dart';

/// Friends page with friend requests and suggestions
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final requests = await SupabaseService.getFriendRequests();
      final suggestions = await SupabaseService.getFriendSuggestions();
      if (mounted) {
        setState(() {
          _friendRequests = requests;
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching friends data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    try {
      await SupabaseService.updateFriendStatus(friendshipId, 'accepted');
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
        );
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    try {
      await SupabaseService.updateFriendStatus(friendshipId, 'rejected');
      _fetchData();
    } catch (e) {
      debugPrint('Error declining request: $e');
    }
  }

  Future<void> _addFriend(String friendId) async {
    try {
      await SupabaseService.sendFriendRequest(friendId);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  void _removeSuggestion(String id) {
    setState(() {
      _suggestions.removeWhere((s) => s['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Friend Requests Section
                    if (_friendRequests.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Friend Requests',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_friendRequests.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                      ),
                      ..._friendRequests.map((request) {
                        final sender = request['sender'] as Map<String, dynamic>;
                        return _FriendRequestCard(
                          name: sender['username'] ?? 'User',
                          avatarUrl: sender['avatar_url'] ?? '',
                          mutualFriends: 0, // In mock we had this, now 0
                          timeAgo: timeago.format(DateTime.parse(request['created_at'])),
                          onAccept: () => _acceptRequest(request['id']),
                          onDecline: () => _declineRequest(request['id']),
                        );
                      }),
                      const Divider(thickness: 8, color: Color(0xFFF0F2F5)),
                    ],

                    // Suggestions Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'People You May Know',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                    ),
                    if (_suggestions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('No suggestions at this time')),
                      ),
                    ..._suggestions.map((suggestion) => _SuggestionCard(
                          name: suggestion['username'] ?? 'User',
                          avatarUrl: suggestion['avatar_url'] ?? '',
                          mutualFriends: 0,
                          onAdd: () => _addFriend(suggestion['id']),
                          onRemove: () => setState(() => _suggestions.remove(suggestion)),
                        )),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int mutualFriends;
  final String timeAgo;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _FriendRequestCard({
    required this.name,
    required this.avatarUrl,
    required this.mutualFriends,
    required this.timeAgo,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$mutualFriends mutual friends',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onDecline,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int mutualFriends;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _SuggestionCard({
    required this.name,
    required this.avatarUrl,
    required this.mutualFriends,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$mutualFriends mutual friends',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Add Friend',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onRemove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
