import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/post_model.dart';
import 'package:app/pages/profile.dart';
import 'package:app/dbHelper/mongodb.dart';

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
        onPressed: () async {
          final controller = TextEditingController();
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("New Post"),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "What's on your mind?"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text("Post"),
                ),
              ],
            ),
          );
          if (result != null && result.isNotEmpty) {
            await MongoDataBase.insertPost({
              'userName': 'Navod Dilshan',
              'userAvatar': 'assets/images/user1.png',
              'timeAgo': 'Just now',
              'content': result,
              'imagePath': null,
              'likes': 0,
              'comments': 0,
              'shares': 0,
              'likedBy': [],
              'createdAt': DateTime.now().toIso8601String(),
              'commentsList': [],
            });
            setState(() {}); // Refresh posts
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Post created successfully")),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Rebuild FutureBuilder
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: MongoDataBase.fetchPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
                    );
                    return _buildPostCard(context, post);
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

  Widget _buildPostCard(BuildContext context, PostModel post) {
    return FutureBuilder<bool>(
      future: Future.wait([
        MongoDataBase.hasUserLiked(post.id, currentUserId),
        // Check if post's location is in wishlist
        MongoDataBase.fetchWishlistItems(userEmail).then((items) {
          return items.any((item) => item['placeId'] == post.placeId && post.placeId != null);
        }),
      ]).then((results) => results[1] as bool), // Use wishlist result
      builder: (context, wishlistSnapshot) {
        if (wishlistSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        bool isShared = wishlistSnapshot.data ?? false;
        return FutureBuilder<bool>(
          future: MongoDataBase.hasUserLiked(post.id, currentUserId),
          builder: (context, likeSnapshot) {
            if (likeSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            bool isLiked = likeSnapshot.data ?? false;
            bool showCommentInput = false;
            bool showComments = false; // New state for collapsing comments
            Color likeColor = isLiked ? Colors.red : Colors.grey[600]!;
            Color commentColor = Colors.grey[600]!;
            Color shareColor = isShared ? Colors.green : Colors.grey[600]!;
            final commentController = TextEditingController();

            return StatefulBuilder(
              builder: (context, setCardState) {
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
                        if (post.location != null) ...[
                          Text(
                            '${post.location} (${post.latitude?.toStringAsFixed(4)}, ${post.longitude?.toStringAsFixed(4)})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],
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
                              icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              icolor: likeColor,
                              label: "Like",
                              onTap: isLiked
                                  ? () {} // Ignore tap if already liked
                                  : () {
                                      setCardState(() {
                                        isLiked = true;
                                        likeColor = Colors.red;
                                      });
                                      MongoDataBase.likePost(post.id, currentUserId).then((_) {
                                        setState(() {}); // Refresh to update likes count
                                      }).catchError((e) {
                                        setCardState(() {
                                          isLiked = false;
                                          likeColor = Colors.grey[600]!;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Error liking post: $e")),
                                        );
                                      });
                                    },
                            ),
                            _buildInteractionButton(
                              icon: Icons.comment_outlined,
                              icolor: commentColor,
                              label: "Comment",
                              onTap: () {
                                setCardState(() {
                                  showCommentInput = !showCommentInput;
                                  commentColor = showCommentInput ? Colors.blue : Colors.grey[600]!;
                                });
                              },
                            ),
                            _buildInteractionButton(
                              icon: Icons.add_location_alt,
                              icolor: shareColor,
                              label: "Add",
                              onTap: isShared
                                  ? () {} // Ignore tap if already added
                                  : () async {
                                      if (post.location == null || post.latitude == null || post.longitude == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("No location data available for this post")),
                                        );
                                        return;
                                      }
                                      try {
                                        await MongoDataBase.insertWishlistItem(userEmail, {
                                          'placeName': post.location,
                                          'latitude': post.latitude,
                                          'longitude': post.longitude,
                                          'placeId': post.placeId ?? '',
                                          'createdAt': DateTime.now().toIso8601String(),
                                        });
                                        setCardState(() {
                                          isShared = true;
                                          shareColor = Colors.green;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Added ${post.location} to wishlist")),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Failed to add to wishlist: $e")),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                        if (showCommentInput) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentController,
                                  decoration: const InputDecoration(
                                    hintText: "Write a comment...",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.blue),
                                onPressed: () async {
                                  final commentText = commentController.text.trim();
                                  if (commentText.isNotEmpty) {
                                    try {
                                      await MongoDataBase.insertComment(
                                        post.id,
                                        currentUserId,
                                        'Navod Dilshan',
                                        commentText,
                                      );
                                      commentController.clear();
                                      setCardState(() {
                                        showCommentInput = false;
                                        commentColor = Colors.grey[600]!;
                                      });
                                      setState(() {}); // Refresh to update comments
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Comment added")),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Error adding comment: $e")),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                        if (post.commentsList.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Comments",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setCardState(() {
                                    showComments = !showComments;
                                  });
                                },
                                child: Text(
                                  showComments ? "Hide Comments" : "Show Comments (${post.comments})",
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          if (showComments)
                            ...post.commentsList.map((comment) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment['userName'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatCommentTime(comment['createdAt']),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      comment['content'] ?? '',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Format comment timestamp
  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color icolor,
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