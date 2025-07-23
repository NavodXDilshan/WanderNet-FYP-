import 'package:flutter/material.dart';
import 'package:app/models/post_model.dart';
import 'package:app/components/post_card.dart';
import 'package:app/aiHelper/flask.dart';
import 'package:app/models/location_model.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _ForYouFeedState extends State<ForYouFeed>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Sample locations data - replace with your actual data source
  List<LocationModel>? locations;

  @override
  void initState() {
    super.initState();
    _fetchTrendingLocations();
  }

  Future<void> _fetchTrendingLocations() async {
    try {
      final List<Map<String, dynamic>> locationData =
          await ApiService.getCommentedLocations(widget.username);
      setState(() {
        locations = locationData.map((data) {
          return LocationModel(
            location: data['location'] ?? 'Unknown',
            latitude: data['latitude'],
            longitude: data['longitude'],
          );
        }).toList();
      });
    } catch (e) {
      print('Error fetching locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _fetchTrendingLocations();}); // Rebuild FutureBuilder
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiService.getCommentedPosts(widget.username), // You might want to create fetchForYouPosts() for different algorithm
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
                        id: (postData['_id'] as Map<String, dynamic>?)?['\$oid'] ?? '',
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
              itemCount: locations?.length,
              itemBuilder: (context, index) {
                final location = locations?[index];
                return _buildLocationItem(location != null
                    ? {
                        'location': location.location,
                        'latitude': location.latitude.toString(),
                        'longitude': location.longitude.toString(),
                      }
                    : {'location': 'Unknown', 'latitude': '0.0', 'longitude': '0.0'});
              },
            ),
          ),
        ],
        
      ),
    );
  }

   // Add this helper method to the PostCard class
  void _openInMaps(String location, double latitude, double longitude) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildLocationItem(Map<String, String> location) {
    return GestureDetector(
      onTap: () {
        // Launch longitude and latitude in Google Maps or any other action
        _openInMaps(
          location['location'] ?? 'Unknown',
          double.tryParse(location['latitude'] ?? '0.0') ?? 0.0,
          double.tryParse(location['longitude'] ?? '0.0') ?? 0.0,
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
                child: Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 70,
              child: Text(
                location['location'] ?? 'Unknown',
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