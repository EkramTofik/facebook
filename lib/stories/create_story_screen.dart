import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

/// Screen for creating a new story with image and optional text
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _textController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    } else {
      // User cancelled - go back
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _createStory() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.createStory(
        imagePath: _imageFile!.path,
        content: _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story posted!')),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Create Story'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _imageFile != null ? _createStory : null,
                  child: const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: _imageFile == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Story Image
                Image.file(
                  _imageFile!,
                  fit: BoxFit.contain,
                ),
                // Text overlay input at bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _imageFile != null
          ? FloatingActionButton(
              onPressed: _pickImage,
              backgroundColor: AppConstants.primaryColor,
              child: const Icon(Icons.photo_library, color: Colors.white),
            )
          : null,
    );
  }
}
