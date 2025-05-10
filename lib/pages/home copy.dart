import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(MyApp());
}

// Main app widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Homepage(),
      debugShowCheckedModeBanner: false, // Removes debug banner
    );
  }
}

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar (Top Navigation)
      appBar: AppBar(
        title: const Text(
          'Social App',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue, // Facebook-like blue
        leading: Container(
          margin: const EdgeInsets.all(10),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/icons/Arrow - Left 2.svg',
            width: 20,
            height: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Add search functionality later
            },
          ),
          Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icons/dots.svg',
              width: 20,
              height: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),

      // Body (Main Content)
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Post Creation Section
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(
                          'https://via.placeholder.com/150', // Placeholder profile pic
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.videocam, 'Live'),
                      _buildActionButton(Icons.photo, 'Photo'),
                      _buildActionButton(Icons.people, 'Friends'),
                    ],
                  ),
                ],
              ),
            ),

            // News Feed Section
            ListView.builder(
              shrinkWrap: true, // Prevents infinite height error
              physics: const NeverScrollableScrollPhysics(), // Parent scroll handles it
              itemCount: 5, // Dummy posts
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User $index',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'April ${index + 1}, 2025',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('This is a sample post #$index. Enjoy Flutter!'),
                        const SizedBox(height: 10),
                        Image.network('https://via.placeholder.com/300x200'),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildInteractionButton(Icons.thumb_up, 'Like'),
                            _buildInteractionButton(Icons.comment, 'Comment'),
                            _buildInteractionButton(Icons.share, 'Share'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar (Optional)
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
        ],
      ),
    );
  }

  // Helper method for action buttons
  Widget _buildActionButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  // Helper method for interaction buttons
  Widget _buildInteractionButton(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18, color: Colors.grey),
      label: Text(label, style: const TextStyle(color: Colors.grey)),
    );
  }
}