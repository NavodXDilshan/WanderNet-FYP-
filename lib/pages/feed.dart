import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/post_model.dart';
import 'package:app/pages/profile.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/post_card.dart';
import 'package:app/pages/create_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/pages/feed/for_you_feed.dart';
import 'package:app/pages/feed/following_feed.dart';

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
        'username': user.userMetadata?['username'] as String? ?? user.email ?? 'Guest',
        'userId': user.id,
      };
    } catch (e) {
      print('Error refreshing session or fetching user info: $e');
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? user.email ?? 'Guest',
        'userId': user.id,
      };
    }
  }
}

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? currentUserId;
  String? userEmail;
  String? username;
  late TabController _tabController;

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
      userEmail = userInfo['userEmail'];
      username = userInfo['username'];
      currentUserId = userInfo['userId'];
    });
  }

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
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color.fromARGB(255, 240, 144, 9),
              labelColor: const Color.fromARGB(255, 240, 144, 9),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'For You'),
                Tab(text: 'Latest'),
              ],
            ),
          ),
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ForYouFeed(
                  currentUserId: currentUserId ?? '',
                  userEmail: userEmail ?? '',
                  username: username ?? '',
                ),
                FollowingFeed(
                  currentUserId: currentUserId ?? '',
                  userEmail: userEmail ?? '',
                  username: username ?? '',
                ),
              ],
            ),
          ),
        ],
      ),
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
}