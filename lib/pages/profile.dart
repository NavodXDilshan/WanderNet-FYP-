import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/post_model.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/post_card.dart';
import 'package:app/pages/create_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/pages/market.dart';
import 'package:app/pages/signin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/pages/edit.dart';

class AuthService {
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<Map<String, String?>> getUserInfo() async {
    final user = supabase.auth.currentUser;
    print('Current user: ${user?.id}, email: ${user?.email}, metadata: ${user?.userMetadata}');
    if (user == null) {
      print('No authenticated user found');
      return {'userEmail': null, 'username': null, 'userId': null};
    }
    try {
      if (supabase.auth.currentSession?.isExpired ?? true) {
        await supabase.auth.refreshSession();
      }
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? 'Guest',
        'userId': user.id,
      };
    } catch (e) {
      print('Error refreshing session or fetching user info: $e');
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? 'Guest',
        'userId': user.id,
      };
    }
  }
}

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? username;
  String? userEmail;
  String? currentUserId;
  late TabController _tabController;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getUserInfo();
    setState(() {
      username = userInfo['username'];
      userEmail = userInfo['userEmail'];
      currentUserId = userInfo['userId'];
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUserPosts() async {
    if (username == null || username == 'Guest') {
      return [];
    }
    try {
      final posts = await MongoDataBase.fetchPosts(username: username);
      // Filter to ensure only posts where userName matches the current username
      final userPosts = posts.where((post) => post['userName'] == username).toList();
      print('Fetched ${userPosts.length} posts for user $username');
      return userPosts;
    } catch (e) {
      print('Error fetching user posts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load posts: $e')),
      );
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserMarkets() async {
    if (userEmail == null || username == 'Guest') {
      return [];
    }
    try {
      final allMarkets = await MongoDataBase.fetchMarketItems();
      final userMarkets = allMarkets.where((market) => market['userEmail'] == userEmail).toList();
      print('Fetched ${userMarkets.length} markets for user email $userEmail');
      return userMarkets;
    } catch (e) {
      print('Error fetching user markets: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load markets: $e')),
      );
      return [];
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await MongoDataBase.deletePost(postId);
      setState(() {}); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  Future<void> _deleteMarket(String userEmail) async {
    try {
      await MongoDataBase.deleteMarketItem(userEmail);
      setState(() {}); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete market: $e')),
      );
    }
  }

  void _showDeleteDialog(String id, {required bool isPost}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isPost) {
                _deletePost(id);
              } else {
                _deleteMarket(id);
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await _secureStorage.delete(key: 'supabase_session');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  void _updateProfileState(String newUsername, String? newEmail, String? newUserId) {
    setState(() {
      username = newUsername;
      userEmail = newEmail;
      currentUserId = newUserId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: appBar(),
      backgroundColor: Colors.white,
      endDrawer: drawerBar(context),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 240, 144, 9),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Your Posts'),
                Tab(text: 'Your Markets'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    if (_tabController.index == 0) setState(() {});
                  },
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchUserPosts(),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              return Stack(
                                children: [
                                  PostCard(
                                    post: post,
                                    currentUserId: currentUserId ?? '',
                                    userEmail: "",
                                    username: username ?? '',
                                    onInteraction: () {
                                      if (_tabController.index == 0) setState(() {});
                                    },
                                  ),
                                  Positioned(
                                    top: 15,
                                    right: 35,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _showDeleteDialog(post.id, isPost: true),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    if (_tabController.index == 1) setState(() {});
                  },
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchUserMarkets(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingSkeleton();
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Center(child: Text('No markets available')),
                        );
                      }
                      final markets = snapshot.data!;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: markets.map((marketData) {
                              final market = MarketItemModel.fromMap(marketData);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 200,
                                          width: double.infinity,
                                          child: market.imageUrl != null && market.imageUrl!.isNotEmpty
                                              ? Image.network(
                                                  market.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    print('Image load error for ${market.imageUrl}: $error');
                                                    return Container(
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.image_not_supported,
                                                        size: 50,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                market.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "LKR ${market.price}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                market.category,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Created: ${marketData['createdAt'] ?? 'Unknown'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteDialog(marketData['userEmail'], isPost: false),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      title: const Text(
        "Profile",
        style: TextStyle(
          color: Color.fromARGB(255, 255, 255, 255),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      elevation: 0.0,
      leading: GestureDetector(
        onTap: () {
          Navigator.pop(context);
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
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfile(
                    onAvatarUpdated: _updateProfileState,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await _logout();
            },
          ),
        ],
      ),
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
              ],
            ),
          ),
        );
      },
    );
  }

  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: const Center(child: Text('Sign In Page')),);
  }
}