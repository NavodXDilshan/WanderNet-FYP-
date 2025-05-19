import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/post_model.dart';

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  dynamic iconName = Icons.thumb_up_outlined;
  dynamic iconColor = Colors.grey[600];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final post = PostModel(
      userName: "John Doe",
      userAvatar: "assets/images/user1.png",
      timeAgo: "2h ago",
      content: "Enjoying a sunny day at the park! 🌞",
      imagePath: "assets/images/post1.webp",
      likes: 120,
      comments: 15,
      shares: 5,
    );
    final post1 = PostModel(
      userName: "John Doe",
      userAvatar: "assets/images/user1.png",
      timeAgo: "2h ago",
      content: "Enjoying a sunny day at the park! 🌞",
      imagePath: "assets/images/post1.webp",
      likes: 120,
      comments: 15,
      shares: 5,
    );

    return Scaffold(
      key : _scaffoldKey,
      appBar: appbar(),
      backgroundColor: Colors.white,
      endDrawer: drawerBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: _buildPostCard(context, post),
        ),
        
      ),
    );
  }

  Drawer drawerBar() {
    return Drawer(
      child: ListView(
        padding:EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
            ),
            child:Text("Menu",
            style: TextStyle(
              color:Colors.white,
              fontSize: 24,
            ),),
            ),
            ListTile(
              leading: Image.asset("assets/images/user1.png")
            )
        ],)
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
    return Card(
      color: const Color.fromARGB(255, 251, 217, 169),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fit to content
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
                  icon: iconName,
                  icolor: iconColor,
                  label: "Like",
                  onTap: () {
                    setState(() {
                      if (iconName == Icons.thumb_up)
                        {iconName = Icons.thumb_up_outlined;
                        iconColor = Colors.grey[600];}
                      else
                        {iconName = Icons.thumb_up;
                        iconColor = Colors.red;}
                    });
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