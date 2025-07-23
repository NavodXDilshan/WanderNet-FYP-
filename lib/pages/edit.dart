import 'package:flutter/material.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/models/post_model.dart';
import 'package:app/pages/profile.dart';

class EditProfile extends StatefulWidget {
  final void Function(String, String?, String?) onAvatarUpdated;

  const EditProfile({super.key, required this.onAvatarUpdated});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  String? selectedAvatar = 'assets/images/user1.png'; // Default user icon
  final List<String> userIcons = [
    'assets/images/user1.png',
    'assets/images/user2.png',
    'assets/images/user3.png',
    'assets/images/user4.png',
    'assets/images/user5.png',
    'assets/images/user6.png',
    'assets/images/user7.png',
    'assets/images/user8.png',
    'assets/images/user9.png',
    'assets/images/user10.png',
  ];

  Future<void> _updateAvatar(String newAvatar) async {
    try {
      final userInfo = await AuthService.getUserInfo();
      final username = userInfo['username'];
      if (username == null || username == 'Guest') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot update avatar for guest user')),
        );
        return;
      }

      // Update posts in MongoDB
      final posts = await MongoDataBase.fetchPosts(username: username);
      for (var post in posts) {
        await MongoDataBase.deletePost(post['_id'].toHexString());
        post['userAvatar'] = newAvatar;
        await MongoDataBase.insertPost(post);
      }

      // Update profile state using the callback
      if (mounted) {
        widget.onAvatarUpdated(username, userInfo['userEmail'], userInfo['userId']);
        Navigator.pop(context); // Return to profile
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile',style: TextStyle(color: Colors.white),),
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Select Your Avatar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: userIcons.map((icon) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedAvatar = icon;
                    });
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage(icon),
                    child: selectedAvatar == icon
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (selectedAvatar != null) {
                  _updateAvatar(selectedAvatar!);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}