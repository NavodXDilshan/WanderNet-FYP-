import 'package:app/dbHelper/mongodb.dart';
import 'package:app/models/post_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_postController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some content")),
      );
      return;
    }

    try {
      final postData = {
        'userName': 'Navod Dilshan',
        'userAvatar': 'assets/images/user1.png',
        'timeAgo': 'Just now',
        'content': _postController.text,
        'imagePath': null,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await MongoDataBase.insertPost(postData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post created successfully")),
      );
      _postController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create post: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = PostModel(
      id:"",
      userName: "Navod Dilshan",
      userAvatar: "assets/images/user1.png",
      timeAgo: "2h ago",
      content: "Enjoying a sunny day at the park! 🌞",
      imagePath: "assets/images/post1.webp",
      likes: 120,
      comments: 15,
      shares: 5,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        elevation: 0.0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context); // Back to Feed
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              'assets/icons/Arrow - Left 2.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomLeft,
              children: [
                // Cover Photo
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/cover_photo.jpg"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Profile Avatar
                Positioned(
                  bottom: -40,
                  left: 20,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 46,
                      backgroundImage: AssetImage("assets/images/user1.png"),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            // User Name and Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Navod Dilshan",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Placeholder for edit profile
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Edit Profile clicked")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Edit Profile"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Post Input Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Placeholder for image upload
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Image upload clicked")),
                          );
                        },
                        icon: const Icon(Icons.photo),
                        label: const Text("Add Photo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Placeholder for location selection
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Add Location clicked")),
                          );
                        },
                        icon: const Icon(Icons.location_on),
                        label: const Text("Add Location"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _submitPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("Post"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Posts Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Posts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildPostCard(context, post),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, PostModel post) {
    return Card(
      color: const Color.fromARGB(255, 251, 217, 169),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: AssetImage(post.userAvatar),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.content,
              style: const TextStyle(fontSize: 14),
            ),
            if (post.imagePath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Image.asset(
                    post.imagePath!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${post.likes} Likes"),
                Text("${post.comments} Comments"),
                Text("${post.shares} Shares"),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInteractionButton(
                  icon: Icons.thumb_up_outlined,
                  icolor: Colors.grey[600],
                  label: "Like",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Like clicked")),
                    );
                  },
                ),
                _buildInteractionButton(
                  icon: Icons.comment_outlined,
                  icolor: Colors.grey[600],
                  label: "Comment",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Comment clicked")),
                    );
                  },
                ),
                _buildInteractionButton(
                  icon: Icons.add_location_alt,
                  icolor: Colors.grey[600],
                  label: "Add",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Add clicked")),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required dynamic icolor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: icolor, size: 20),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}