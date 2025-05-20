class PostModel {
  final String id;
  final String userName;
  final String userAvatar;
  final String timeAgo;
  final String content;
  final String? imagePath;
  final int likes;
  final int comments;
  final int shares;

  PostModel({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.timeAgo,
    required this.content,
    this.imagePath,
    required this.likes,
    required this.comments,
    required this.shares,
  });
}