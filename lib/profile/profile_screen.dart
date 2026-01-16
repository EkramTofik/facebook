import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Simple state to hold profile data
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        if (mounted) Navigator.pop(context); // Should not happen if auth guarded
        return;
      }

      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      // Navigate to login screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return const Center(child: Text('Failed to load profile'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
             // Cover Photo & Profile Picture Area (Simplified for now)
             Stack(
               alignment: Alignment.bottomCenter,
               clipBehavior: Clip.none,
               children: [
                 Container(
                   height: 200,
                   color: Colors.grey[300], // Placeholder for cover photo
                 ),
                 Positioned(
                   bottom: -50,
                   child: CircleAvatar(
                     radius: 60,
                     backgroundColor: Colors.white,
                     child: CircleAvatar(
                       radius: 55,
                       backgroundColor: Colors.grey[200],
                       backgroundImage: _profile!['avatar_url'] != null 
                           ? NetworkImage(_profile!['avatar_url']) 
                           : null,
                       child: _profile!['avatar_url'] == null 
                           ? const Icon(Icons.person, size: 50, color: Colors.grey) 
                           : null,
                     ),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 60),
             
             // User Name
             Text(
               _profile!['username'] ?? 'User',
               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
             ),
             
             const SizedBox(height: 20),
             
             // Action Buttons
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20.0),
               child: Row(
                 children: [
                   Expanded(
                     child: ElevatedButton(
                       onPressed: () {
                         // TODO: Implement Edit Profile (Picture Upload)
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Profile Feature - Logic same as Post Image Upload')));
                       }, 
                       child: const Text('Edit Profile'),
                     ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     child: OutlinedButton(
                       onPressed: () {}, 
                       child: const Text('...'),
                     ),
                   ),
                 ],
               ),
             ),
             
             const Divider(),
             
             // User's Posts (Reuse Feed logic or create new widget)
             const Padding(
               padding: EdgeInsets.all(AppConstants.defaultPadding),
               child: Align(
                 alignment: Alignment.centerLeft,
                 child: Text("My Posts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
               ),
             ),
             
             // For this example, we just show a static placeholder. 
             // In a real app, query 'posts' where user_id == currentUserId
             const Center(
               child: Text('User posts will appear here.'),
             )
          ],
        ),
      ),
    );
  }
}
