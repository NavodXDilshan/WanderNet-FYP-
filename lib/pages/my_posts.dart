// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:app/models/post_model.dart';
// import 'package:app/services/api_service.dart';

// class MyPosts extends StatefulWidget {
//   final String email;

//   const MyPosts({super.key, required this.email});

//   @override
//   State<MyPosts> createState() => _MyPostsState();
// }

// class _MyPostsState extends State<MyPosts> {
//   final ApiService _apiService = ApiService();
//   final Map<String, bool> _likeStates = {};
//   final Map<String, IconData> _likeIcons = {};
//   final Map<String, Color> _likeColors = {};

//   void _toggleLike(String postId, String userEmail) async {
//     setState(() {
//       _likeStates[postId] = !(_likeStates[postId] ?? false);
//       _likeIcons[postId] = _likeStates[postId]! ? Icons.thumb_up : Icons.thumb_up_outlined;
//       _likeColors[postId] = _likeStates[postId]! ? Colors.red : Colors.grey[600]!;
//     });
//     try {
//       await _apiService.likePost(userEmail, postId);
//       setState(() {}); // Refresh to show updated likes
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to like post: $e')),
//       );
//       setState(() {
//         _likeStates[postId] = !(_likeStates[postId] ?? false);
//         _likeIcons[postId] = _likeStates[postId]! ? Icons.thumb_up : Icons.thumb_up_outlined;
//         _likeColors[postId] = _likeStates[postId]! ? Colors.red : Colors.grey[600]!;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "My Posts",
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: const Color.fromARGB(255, 240, 144, 9),
//         elevation: 0.0,
//         leading: GestureDetector(
//           onTap: () {
//             Navigator.pop(context);
//           },
//           child: Container(
//             margin: const EdgeInsets.all(10),
//             alignment: Alignment.center,
//             decoration: BoxDecoration(
//               color: const Color.fromARGB(255, 240, 144, 9),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: SvgPicture.asset(
//               'assets/icons/Arrow - Left 2.svg',
//               width: 20,
//               height: 20,
//             ),
//           ),
//         ),
//       ),
//       backgroundColor: Colors.white,
//       body: FutureBuilder<List<PostModel>>(
//         future: _apiService.fetchUserPosts(widget.email),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('No posts available'));
//           }

//           final posts = snapshot.data!;
//           return ListView.builder(
//             padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
//             itemCount: posts.length,
//             itemBuilder: (context, index) {
//               final post = posts[index];
//               return null;
//               // return _buildPostCard(context, post, post.id, widget.email);
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildPostCard(BuildContext context, PostModel post, String postId, String userEmail) {
//     return Card(
//       color: const Color.fromARGB(255, 251, 217, 169),
//       margin: const EdgeInsets.only(bottom: 10),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       child: Padding(
//         padding: const EdgeInsets.all(10),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 20,
//                   backgroundImage: NetworkImage(post.userAvatar),
//                 ),
//                 const SizedBox(width: 10),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       post.userName,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     Text(
//                       post.timeAgo,
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Text(
//               post.content,
//               style: const TextStyle(fontSize: 14),
//             ),
//             if (post.imagePath != null) ...[
//               const SizedBox(height: 10),
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(8),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey[300]!, width: 1),
//                   ),
//                   child: Image.network(
//                     post.imagePath!,
//                     width: double.infinity,
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//             ],
//             const SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text("${post.likes} Likes"),
//                 Text("${post.comments} Comments"),
//                 Text("${post.shares} Shares"),
//               ],
//             ),
//             const Divider(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildInteractionButton(
//                   icon: _likeIcons[postId] ?? Icons.thumb_up_outlined,
//                   icolor: _likeColors[postId] ?? Colors.grey[600],
//                   label: "Like",
//                   onTap: () => _toggleLike(postId, userEmail),
//                 ),
//                 _buildInteractionButton(
//                   icon: Icons.comment_outlined,
//                   icolor: Colors.grey[600],
//                   label: "Comment",
//                   onTap: () {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text("Comment clicked")),
//                     );
//                   },
//                 ),
//                 _buildInteractionButton(
//                   icon: Icons.add_location_alt,
//                   icolor: Colors.grey[600],
//                   label: "Add",
//                   onTap: () {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text("Add clicked")),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInteractionButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     required dynamic icolor,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Row(
//         children: [
//           Icon(icon, color: icolor, size: 20),
//           const SizedBox(width: 5),
//           Text(
//             label,
//             style: TextStyle(color: Colors.grey[600], fontSize: 14),
//           ),
//         ],
//       ),
//     );
//   }
// }