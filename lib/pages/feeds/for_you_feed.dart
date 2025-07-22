import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app/models/post_model.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/post_card.dart';
import 'package:http/http.dart' as http;

class ForYouFeed extends StatefulWidget {
  final String currentUserId;
  final String userEmail;
  final String username;

  const ForYouFeed({
    super.key,
    required this.currentUserId,
    required this.userEmail,
    required this.username,
  });

  @override
  State<ForYouFeed> createState() => _ForYouFeedState();
}

class _ForYouFeedState extends State<ForYouFeed> {

  Future<List<Map<String, dynamic>>>? futureData;

  // Sample locations data - replace with your actual data source
  final List<Map<String, String>> locations = [
    {
      'name': 'New York',
      'image': 'assets/images/locations/new_york.jpg',
    },
    {
      'name': 'London',
      'image': 'assets/images/locations/london.jpg',
    },
    {
      'name': 'Tokyo',
      'image': 'assets/images/locations/tokyo.jpg',
    },
    {
      'name': 'Paris',
      'image': 'assets/images/locations/paris.jpg',
    },
    {
      'name': 'Sydney',
      'image': 'assets/images/locations/sydney.jpg',
    },
    {
      'name': 'Dubai',
      'image': 'assets/images/locations/dubai.jpg',
    },
  ];

  @override
  void initState() { 
    super.initState();
    _fetchUserPosts();
  }

Future<void> _fetchUserPosts() async {
  try {
    final response = await http.get(
      Uri.parse('http://localhost:5000/posts/?username="${widget.username}"'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      setState(() {
        // Assuming data is a list of posts
        futureData = Future.value(List<Map<String, dynamic>>.from(data));
      });
      print(data);
    } else {
      print('Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Rebuild FutureBuilder
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureData,// MongoDataBase.fetchPosts(), // You might want to create fetchForYouPosts() for different algorithm
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWithLocations();
          } else if (snapshot.hasError) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildLocationsSection(),
                  const SizedBox(height: 20),
                  Center(child: Text('Error: ${snapshot.error}')),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildLocationsSection(),
                  const SizedBox(height: 20),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Discover amazing posts from around the world!\nCheck out trending content in different locations above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data!;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildLocationsSection(),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              'Trending Locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return _buildLocationItem(location);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(Map<String, String> location) {
    return GestureDetector(
      onTap: () {
        // Handle location tap - navigate to location-specific feed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Showing posts from ${location['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color.fromARGB(255, 240, 144, 9),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  location['image']!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to a placeholder if image doesn't exist
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 240, 144, 9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 70,
              child: Text(
                location['name']!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWithLocations() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildLocationsSection(),
          const SizedBox(height: 10),
          _buildPostsLoadingSkeleton(),
        ],
      ),
    );
  }

  Widget _buildPostsLoadingSkeleton() {
    return Column(
      children: List.generate(3, (index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
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
      }),
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
}