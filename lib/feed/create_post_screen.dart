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

  // Pick Image
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Create Post
  Future<void> _createPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      String? imageUrl; // Will hold the uploaded URL if any
      
      // Upload Image if selected
      if (_imageFile != null) {
        final fileName = '${DateTime.now().toIso8601String()}_$userId.jpg';
        final path = 'posts/$fileName';
        
        // Upload to 'post_images' bucket (must be created in Supabase Dashboard)
        await SupabaseService.client.storage
            .from('post_images')
            .upload(path, _imageFile!);

        // Get Public Link
        imageUrl = SupabaseService.client.storage
            .from('post_images')
            .getPublicUrl(path);
      }

      // Insert Post Data
      await SupabaseService.client.from('posts').insert({
        'user_id': userId,
        'content': text,
        'image_url': imageUrl,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('POST', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Text Input
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: InputBorder.none,
              ),
            ),
            
            if (_imageFile != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
            const Spacer(),
            const Divider(),
            
            // Image Picker Button
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library, color: Colors.green),
              label: const Text('Photo/Video', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
