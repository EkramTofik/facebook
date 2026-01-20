import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  bool _isLoading = false;
  String? _avatarUrl;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['full_name']);
    _usernameController = TextEditingController(text: widget.profile['username']);
    _bioController = TextEditingController(text: widget.profile['bio']);
    _locationController = TextEditingController(text: widget.profile['location']);
    _avatarUrl = widget.profile['avatar_url'];
    _coverUrl = widget.profile['cover_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final bucket = isAvatar ? 'post_images' : 'post_images'; // Using existing bucket for simplicity
        final url = await SupabaseService.uploadImage(image.path, bucket);
        if (url != null) {
          setState(() {
            if (isAvatar) {
              _avatarUrl = url;
            } else {
              _coverUrl = url;
            }
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        avatarUrl: _avatarUrl,
        coverUrl: _coverUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  title: 'Profile Picture',
                  onAction: () => _pickImage(true),
                ),
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                ),
                const SizedBox(height: 24),
                
                _SectionTitle(
                  title: 'Cover Photo',
                  onAction: () => _pickImage(false),
                ),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: _coverUrl != null ? DecorationImage(
                      image: CachedNetworkImageProvider(_coverUrl!),
                      fit: BoxFit.cover,
                    ) : null,
                  ),
                  child: _coverUrl == null ? const Center(child: Icon(Icons.camera_alt, size: 30)) : null,
                ),
                const SizedBox(height: 24),

                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter your name')),
                const SizedBox(height: 16),

                const Text('Username', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _usernameController, decoration: const InputDecoration(hintText: 'Enter username')),
                const SizedBox(height: 16),

                const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Describe yourself...'),
                ),
                const SizedBox(height: 16),

                const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _locationController, decoration: const InputDecoration(hintText: 'Hometown...')),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onAction;

  const _SectionTitle({required this.title, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onAction, child: const Text('Edit')),
      ],
    );
  }
}
