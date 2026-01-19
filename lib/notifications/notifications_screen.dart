import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../utils/constants.dart';
import '../services/supabase_service.dart';

/// Facebook-style notifications page connected to Supabase
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final notifications = await SupabaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await SupabaseService.markNotificationAsRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final unread = _notifications.where((n) => !(n['is_read'] as bool)).toList();
    final read = _notifications.where((n) => (n['is_read'] as bool)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Notifications',
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
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          children: [
            if (unread.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'New',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...unread.map((n) => _NotificationCard(
                    notification: n,
                    onTap: () => _markAsRead(n['id']),
                  )),
            ],
            if (read.isNotEmpty || unread.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Earlier',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...read.map((n) => _NotificationCard(
                    notification: n,
                    onTap: () {},
                  )),
            ] else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No notifications yet')),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.thumb_up;
      case 'comment': return Icons.chat_bubble;
      case 'friend_request': return Icons.person_add;
      case 'post': return Icons.public;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'like': return AppConstants.primaryColor;
      case 'comment': return Colors.green;
      case 'friend_request': return AppConstants.primaryColor;
      case 'post': return Colors.grey;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] as bool;
    final sender = notification['sender'] as Map<String, dynamic>?;
    final username = sender?['username'] ?? 'Someone';
    final avatarUrl = sender?['avatar_url'] as String?;
    final content = notification['content'] as String;
    final createdAt = DateTime.parse(notification['created_at']);
    final icon = _getIcon(notification['type']);
    final iconColor = _getIconColor(notification['type']);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isRead ? Colors.white : const Color(0xFFE7F3FF),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Icon(icon, color: iconColor, size: 28)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(icon, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.3),
                      children: [
                        TextSpan(
                          text: username,
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        TextSpan(text: ' $content'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(createdAt),
                    style: TextStyle(
                      color: isRead ? Colors.grey[600] : AppConstants.primaryColor,
                      fontSize: 12,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
