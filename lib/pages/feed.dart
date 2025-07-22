import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/post_model.dart';
import 'package:app/pages/profile.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/post_card.dart';
import 'package:app/pages/create_post.dart';
import 'package:app/services/auth_service.dart';


class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final String currentUserId = 'navod_dilshan';
  final String userEmail = 'k.m.navoddilshan@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: appbar(),
      backgroundColor: Colors.white,
      endDrawer: drawerBar(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
          
          // Only refresh if post was successfully created
          if (result == true) {
            setState(() {}); // Refresh feed
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Rebuild FutureBuilder
        },
        //TODO: Implement a reconnect mechanism for MongoDB master connection
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: MongoDataBase.fetchPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton();
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Center(child: Text('No posts available')),
              );
            }

            final posts = snapshot.data!;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  children: posts.map((postData) {
                    final post = PostModel(
                      id: postData['_id']?.toHexString() ?? '',
                      userName: postData['userName'] ?? 'Unknown',
                      userAvatar: postData['userAvatar'] ?? 'assets/images/default.png',
                      timeAgo: postData['timeAgo'] ?? 'Unknown time',
                      content: postData['content'] ?? '',
                      imagePath: postData['imagePath'],
                      likes: _parseToInt(postData['likes']) ?? 0,
                      comments: _parseToInt(postData['comments']) ?? 0,
                      shares: _parseToInt(postData['shares']) ?? 0,
                      location: postData['location'],
                      latitude: _parseToDouble(postData['latitude']),
                      longitude: _parseToDouble(postData['longitude']),
                      placeId: postData['placeId'],
                      commentsList: postData['commentsList'] != null
                          ? List<Map<String, dynamic>>.from(postData['commentsList'])
                          : [],
                      createdAt: DateTime.parse(postData['createdAt'] ?? DateTime.now().toIso8601String()),
                    );
                    return PostCard(
                      post: post,
                      currentUserId: currentUserId,
                      userEmail: userEmail,
                      username: "Adhisha Indumina",
                      onInteraction: () {
                        setState(() {}); // Refresh the feed when needed
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper function to parse String or num to int
  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Helper function to parse String or num to double
  double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Drawer drawerBar(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 240, 144, 9),
            ),
            child: const Text(
              "Menu",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Image.asset("assets/images/user1.png"),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Profile()),
              );
            },
          ),
        ],
      ),
    );
  }

  AppBar appbar() {
    return AppBar(
      title: const Text(
        "Feed",
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
          // Placeholder for navigation
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
      actions: [
        GestureDetector(
          onTap: () {
            _scaffoldKey.currentState?.openEndDrawer();
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            width: 20,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              'assets/icons/dots.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
                // Add more skeleton widgets as needed
              ],
            ),
          ),
        );
      },
    );
  }
}