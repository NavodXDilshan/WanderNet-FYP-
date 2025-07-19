import 'package:flutter/material.dart';
import 'package:app/dbHelper/mongodb.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        actions: [
          TextButton(
            onPressed: () async {
              final content = _contentController.text.trim();
              if (content.isNotEmpty) {
                try {
                  await MongoDataBase.insertPost({
                    'userName': 'Navod Dilshan',
                    'userAvatar': 'assets/images/user1.png',
                    'timeAgo': 'Just now',
                    'content': content,
                    'imagePath': null,
                    'likes': 0,
                    'comments': 0,
                    'shares': 0,
                    'likedBy': [],
                    'createdAt': DateTime.now().toIso8601String(),
                    'commentsList': [],
                  });
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Post created successfully")),
                    );
                    
                    // Return true to indicate successful post creation
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error creating post: $e")),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter some content")),
                );
              }
            },
            child: const Text(
              'Post',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),
            // You can add more features here like:
            // - Image picker
            // - Location picker
            // - Other post attributes
          ],
        ),
      ),
    );
  }
}