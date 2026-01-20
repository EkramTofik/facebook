import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../profile/profile_screen.dart';

/// Facebook-style menu page with shortcuts and settings
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            _ProfileCard(),
            const SizedBox(height: 16),

            // Shortcuts Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: const [
                _MenuShortcut(
                  icon: Icons.people,
                  label: 'Friends',
                  color: Color(0xFF1877F2),
                ),
                _MenuShortcut(
                  icon: Icons.groups,
                  label: 'Groups',
                  color: Color(0xFF1877F2),
                ),
                _MenuShortcut(
                  icon: Icons.storefront,
                  label: 'Marketplace',
                  color: Color(0xFF1877F2),
                ),

                _MenuShortcut(
                  icon: Icons.history,
                  label: 'Memories',
                  color: Color(0xFF5856D6),
                ),
                _MenuShortcut(
                  icon: Icons.bookmark,
                  label: 'Saved',
                  color: Color(0xFF8B5CF6),
                ),
                _MenuShortcut(
                  icon: Icons.flag,
                  label: 'Pages',
                  color: Color(0xFFFF6B35),
                ),
                _MenuShortcut(
                  icon: Icons.event,
                  label: 'Events',
                  color: Color(0xFFE91E63),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // See More button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'See more',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Settings List
            const _MenuListItem(
              icon: Icons.settings,
              title: 'Settings & privacy',
              hasArrow: true,
            ),
            const _MenuListItem(
              icon: Icons.help_outline,
              title: 'Help & support',
              hasArrow: true,
            ),
            const _MenuListItem(
              icon: Icons.nightlight_round,
              title: 'Dark mode',
              hasArrow: true,
            ),
            const _MenuListItem(
              icon: Icons.feedback_outlined,
              title: 'Give feedback',
              hasArrow: false,
            ),
            const SizedBox(height: 8),

            // Logout Button
            InkWell(
              onTap: () => _showLogoutDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Log Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage: (SupabaseService.currentUserAvatar != null && SupabaseService.currentUserAvatar!.isNotEmpty)
                  ? CachedNetworkImageProvider(SupabaseService.currentUserAvatar!)
                  : null,
              child: (SupabaseService.currentUserAvatar == null || SupabaseService.currentUserAvatar!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SupabaseService.currentUserName ??
                        SupabaseService.currentUserEmail?.split('@').first ??
                        'User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'See your profile',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _MenuShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuShortcut({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool hasArrow;

  const _MenuListItem({
    required this.icon,
    required this.title,
    required this.hasArrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: hasArrow
            ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
            : null,
        onTap: () {},
      ),
    );
  }
}
