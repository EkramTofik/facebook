import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

/// Screen for editing an existing post
class EditPostScreen extends StatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _textController;
  String? _currentImageUrl;
  File? _newImageFile;
  bool _isLoading = false;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.post.content ?? '');
    _currentImageUrl = widget.post.imageUrl;
  }

  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
        _removeImage = false;
      });
    }
  }

  void _removeCurrentImage() {
    setState(() {
      _currentImageUrl = null;
      _newImageFile = null;
      _removeImage = true;
    });
  }

  Future<void> _saveChanges() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _currentImageUrl == null && _newImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;

      // Upload new image if selected
      if (_newImageFile != null) {
        final userId = SupabaseService.currentUserId;
        final fileName = '${DateTime.now().toIso8601String()}_$userId.jpg';
        final path = 'posts/$fileName';

        await SupabaseService.client.storage
            .from('post_images')
            .upload(path, _newImageFile!);

        imageUrl = SupabaseService.client.storage
            .from('post_images')
            .getPublicUrl(path);
      } else if (_removeImage) {
        imageUrl = null;
      }

      await SupabaseService.updatePost(
        postId: widget.post.id,
        content: content,
        imageUrl: imageUrl,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes made
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated!')),
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
      appBar: AppBar(
        title: const Text('Edit Post', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          ),
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

            // Current Image Preview
            if (_currentImageUrl != null && _newImageFile == null)
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_currentImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeCurrentImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // New Image Preview
            if (_newImageFile != null)
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(_newImageFile!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _newImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const Spacer(),
            const Divider(),

            // Image Picker Button
            TextButton.icon(
              onPressed: _pickNewImage,
              icon: const Icon(Icons.photo_library, color: Colors.green),
              label: const Text(
                'Change Photo',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
