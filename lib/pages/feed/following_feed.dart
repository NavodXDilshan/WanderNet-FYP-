import 'package:flutter/material.dart';
import 'package:app/models/post_model.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/post_card.dart';

class FollowingFeed extends StatefulWidget {
  final String currentUserId;
  final String userEmail;
  final String username;

  const FollowingFeed({
    super.key,
    required this.currentUserId,
    required this.userEmail,
    required this.username,
  });

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Rebuild FutureBuilder
      },
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
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No posts from people you follow yet.\nStart following more people to see their posts here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
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
                    currentUserId: widget.currentUserId,
                    userEmail: widget.userEmail,
                    username: widget.username,
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
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}