import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _createPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.createPost(
        content: text.isEmpty ? null : text,
        imagePath: _imageFile?.path,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post shared!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Post', style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          // User Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: SupabaseService.currentUserAvatar != null
                      ? NetworkImage(SupabaseService.currentUserAvatar!)
                      : null,
                  child: SupabaseService.currentUserAvatar == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SupabaseService.currentUserName ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.public, size: 14, color: Colors.black54),
                          SizedBox(width: 4),
                          Text('Public', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Icon(Icons.arrow_drop_down, size: 14, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Text Input
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                TextField(
                  controller: _textController,
                  maxLines: null,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind?',
                    border: InputBorder.none,
                  ),
                ),
                if (_imageFile != null)
                  Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 20,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PostAction(
                      icon: Icons.photo_library,
                      color: Colors.green,
                      label: 'Photo',
                      onTap: _pickImage,
                    ),
                    _PostAction(
                      icon: Icons.person_add,
                      color: Colors.blue,
                      label: 'Tag People',
                      onTap: () {},
                    ),
                    _PostAction(
                      icon: Icons.emoji_emotions,
                      color: Colors.orange,
                      label: 'Feeling',
                      onTap: () {},
                    ),
                    _PostAction(
                      icon: Icons.location_on,
                      color: Colors.red,
                      label: 'Location',
                      onTap: () {},
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

class _PostAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _PostAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}
