import 'package:flutter/material.dart';
import 'package:app/models/post_model.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/components/photo_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final String currentUserId;
  final String userEmail;
  final String username;
  final VoidCallback onInteraction;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.userEmail,
    required this.username,
    required this.onInteraction,
  });

  // Format comment timestamp
  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return 'Unknown time';
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  // Add this helper method to the PostCard class
  void _openInMaps(String location, double latitude, double longitude) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Report post function (dummy implementation)
  void _reportPost(String reason) {
    // TODO: Implement actual report functionality
    print('Post reported for: $reason');
  }

  // Show report dialog
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.report_outlined, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Report Post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you reporting this post?',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _buildReportOption(
                context,
                Icons.warning_amber_outlined,
                'Inappropriate content',
                Colors.orange.shade400,
              ),
              _buildReportOption(
                context,
                Icons.security_outlined,
                'Spam or scam',
                Colors.red.shade400,
              ),
              _buildReportOption(
                context,
                Icons.info_outline,
                'Misleading information',
                Colors.blue.shade400,
              ),
              _buildReportOption(
                context,
                Icons.more_horiz,
                'Other',
                Colors.grey.shade400,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportOption(BuildContext context, IconData icon, String reason, Color color) {
    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await MongoDataBase.connectToReports();
        await MongoDataBase.insertPostReport({
          'postId': post.id,
          'reportedBy': username,
          'reason': reason,
          'reportedAt': DateTime.now().toIso8601String(),
          'imagePath':post.imagePath
        });

        _reportPost(reason);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Post reported for: $reason'),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              reason,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInteractionButton({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    required Color activeColor,
    String? count,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isActive ? activeColor : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? activeColor : Colors.grey.shade600,
                  size: 18,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isActive ? activeColor : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Text(count),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<bool>>(
      future: Future.wait([

        MongoDataBase.hasUserLiked(post.id, currentUserId),
        MongoDataBase.fetchWishlistItems(userEmail).then((items) {
          // print(items.any((item) => item['placeId'] == post.location));
          return items.any((item) => item['placeId'] == post.location);
        }),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          );
        }

        final results = snapshot.data ?? [false, false];
        bool isLiked = results[0];
        bool isInWishlist = results[1];
        bool showCommentInput = false;
        bool showComments = false;
        final commentController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setCardState) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.purple.shade400],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: AssetImage(post.userAvatar),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getTimeAgo(post.createdAt),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                                _showReportDialog(context);
                            },
                            icon: Icon(
                              Icons.more_horiz,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location Section
                    if (post.location != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (post.latitude != null && post.longitude != null) {
                                _openInMaps(post.location!, post.latitude!, post.longitude!);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade50, Colors.indigo.shade50],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.location!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        if (post.latitude != null && post.longitude != null)
                                          Text(
                                            '${post.latitude!.toStringAsFixed(4)}, ${post.longitude!.toStringAsFixed(4)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Content Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        post.content,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Image Section
                    if (post.imagePath != null) ...[
                      const SizedBox(height: 16),
                      PhotoGallery(
                        imagePath: post.imagePath,
                        isNetworkImage: true,
                        borderRadius: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        fit: BoxFit.cover,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Stats Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildStatChip(Icons.favorite, '${post.likes}', Colors.red.shade400),
                          const SizedBox(width: 8),
                          _buildStatChip(Icons.chat_bubble, '${post.comments}', Colors.blue.shade400),
                          const SizedBox(width: 8),
                          _buildStatChip(Icons.bookmark, '${post.shares}', Colors.green.shade400),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 16),

                    // Interaction Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildModernInteractionButton(
                            icon: Icons.favorite_outline,
                            activeIcon: Icons.favorite,
                            label: "Like",
                            count: post.likes.toString(),
                            isActive: isLiked,
                            activeColor: Colors.red.shade400,
                            onTap: () async {
                              try {
                                setCardState(() {
                                  isLiked = !isLiked;
                                });
                                if (isLiked) {
                                  await MongoDataBase.likePost(post.id, currentUserId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.favorite, color: Colors.white, size: 16),
                                            SizedBox(width: 8),
                                            Text("Post liked!"),
                                          ],
                                        ),
                                        backgroundColor: Colors.red.shade400,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } else {
                                  await MongoDataBase.unlikePost(post.id, currentUserId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.heart_broken, color: Colors.white, size: 16),
                                            SizedBox(width: 8),
                                            Text("Post unliked"),
                                          ],
                                        ),
                                        backgroundColor: Colors.grey.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setCardState(() {
                                  isLiked = !isLiked;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          _buildModernInteractionButton(
                            icon: Icons.chat_bubble_outline,
                            activeIcon: Icons.chat_bubble,
                            label: "Comment",
                            isActive: showCommentInput,
                            activeColor: Colors.blue.shade400,
                            onTap: () {
                              setCardState(() {
                                showCommentInput = !showCommentInput;
                              });
                            },
                          ),
                          _buildModernInteractionButton(
                            icon: Icons.bookmark_outline,
                            activeIcon: Icons.bookmark,
                            label: isInWishlist ? "Saved" : "Save",
                            isActive: isInWishlist,
                            activeColor: Colors.green.shade400,
                            onTap: () async {
                              if (post.location == null || post.latitude == null || post.longitude == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.white, size: 16),
                                        SizedBox(width: 8),
                                        Text("No location data available"),
                                      ],
                                    ),
                                    backgroundColor: Colors.orange.shade600,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                return;
                              }
                              try {
                                setCardState(() {
                                  isInWishlist = !isInWishlist;
                                });
                                if (isInWishlist) {
                                  await MongoDataBase.insertWishlistItem(userEmail, {
                                    'placeName': post.location,
                                    'latitude': post.latitude,
                                    'longitude': post.longitude,
                                    'placeId': post.location ?? '',
                                    'createdAt': DateTime.now().toIso8601String(),
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.bookmark, color: Colors.white, size: 16),
                                            const SizedBox(width: 8),
                                            Text("Added ${post.location} to wishlist"),
                                          ],
                                        ),
                                        backgroundColor: Colors.green.shade400,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } else {
                                  await MongoDataBase.removeWishlistItem(userEmail, post.placeId ?? '');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.bookmark_remove, color: Colors.white, size: 16),
                                            const SizedBox(width: 8),
                                            Text("Removed ${post.location} from wishlist"),
                                          ],
                                        ),
                                        backgroundColor: Colors.grey.shade600,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setCardState(() {
                                  isInWishlist = !isInWishlist;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Comment Input Section
                    if (showCommentInput) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentController,
                                  decoration: InputDecoration(
                                    hintText: "Write a thoughtful comment...",
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                  onPressed: () async {
                                    final commentText = commentController.text.trim();
                                    if (commentText.isNotEmpty) {
                                      try {
                                        await MongoDataBase.insertComment(
                                          post.id,
                                          currentUserId,
                                          username,
                                          commentText,
                                        );
                                        // Update the local post data
                                        post.commentsList.add({
                                            'userId': currentUserId,
                                            'userName': username,
                                            'content': commentText,
                                            'createdAt': DateTime.now().toIso8601String(),
                                        });
                                        post.comments++;
                                        commentController.clear();
                                        setCardState(() {
                                          showCommentInput = false;
                                          showComments = true;
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                                                  SizedBox(width: 8),
                                                  Text("Comment added successfully!"),
                                                ],
                                              ),
                                              backgroundColor: Colors.green.shade400,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Error adding comment: $e"),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Comments Section
                    if (post.commentsList.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Comments (${post.comments})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setCardState(() {
                                  showComments = !showComments;
                                });
                              },
                              icon: AnimatedRotation(
                                turns: showComments ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.keyboard_arrow_down, size: 20),
                              ),
                              label: Text(
                                showComments ? "Hide" : "Show",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showComments) ...[
                        const SizedBox(height: 12),
                        ...post.commentsList.map((comment) {
                          return Container(
                            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      comment['userName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatCommentTime(comment['createdAt']),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['content'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}