import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../models/post_model.dart';
import '../feed/post_card.dart';
import 'edit_profile_screen.dart';

/// Facebook-style profile page with cover photo and tabs
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final profileData = await SupabaseService.getProfile(userId);
      final userPosts = await SupabaseService.getUserPosts(userId);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _posts = userPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Cover Photo & Profile Picture
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Cover photo
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue[300]!,
                            Colors.blue[600]!,
                          ],
                        ),
                      ),
                      child: (_profile?['cover_url'] != null && (_profile!['cover_url'] as String).isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: _profile!['cover_url'],
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    // Profile picture
                    Positioned(
                      bottom: -50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 70,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: (_profile?['avatar_url'] != null && (_profile!['avatar_url'] as String).isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      _profile!['avatar_url'])
                                  : null,
                              child: (_profile?['avatar_url'] == null || (_profile!['avatar_url'] as String).isEmpty)
                                  ? const Icon(Icons.person,
                                      size: 60, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                // Name and Bio
                Text(
                  _profile?['username'] ?? _profile?['full_name'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_profile?['bio'] != null &&
                    (_profile!['bio'] as String).isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      _profile!['bio'],
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                  ),
                const SizedBox(height: 16),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Add to story',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(profile: _profile!),
                              ),
                            );
                            if (result == true) _fetchData();
                          },
                          icon:
                              const Icon(Icons.edit, color: Colors.black, size: 18),
                          label: const Text('Edit profile',
                              style: TextStyle(color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () => _showMoreMenu(context),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_profile?['location'] != null &&
                          (_profile!['location'] as String).isNotEmpty)
                        _InfoRow(
                          icon: Icons.location_on,
                          text: 'Lives in ${_profile!['location']}',
                        ),
                      _InfoRow(
                        icon: Icons.access_time,
                        text:
                            'Joined ${_formatDate(_profile?['created_at'])}',
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _tabController.animateTo(1);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('See your About info'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppConstants.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppConstants.primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'About'),
                  Tab(text: 'Photos'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Posts Tab
            _posts.isEmpty
                ? const Center(child: Text('No posts yet'))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        post: _posts[index],
                        onDeleted: () {
                          setState(() => _posts.removeAt(index));
                        },
                        onUpdated: _fetchData,
                      );
                    },
                  ),
            // About Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Basic Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _AboutItem(icon: Icons.person_outline, label: 'Username', value: _profile?['username'] ?? 'Not set'),
                  _AboutItem(icon: Icons.badge_outlined, label: 'Full Name', value: _profile?['full_name'] ?? 'Not set'),
                  _AboutItem(icon: Icons.email_outlined, label: 'Email', value: _profile?['email'] ?? 'Not set'),
                  _AboutItem(icon: Icons.location_on_outlined, label: 'Location', value: _profile?['location'] ?? 'Not set'),
                  _AboutItem(icon: Icons.calendar_today_outlined, label: 'Joined', value: _formatDate(_profile?['created_at'])),
                  const SizedBox(height: 24),
                  const Text('Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_profile?['bio'] ?? 'No bio yet...', style: TextStyle(color: Colors.grey[800])),
                ],
              ),
            ),
            // Photos Tab
            const Center(child: Text('Photos section coming soon')),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search profile'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link to profile'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Profile status'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Activity log'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'recently';
    try {
      final date = DateTime.parse(dateStr);
      return '${_monthName(date.month)} ${date.year}';
    } catch (e) {
      return 'recently';
    }
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
