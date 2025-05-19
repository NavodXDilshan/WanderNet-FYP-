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
  final String? userEmail;
  final String createdAt;

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
    this.userEmail,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['_id'] as String,
      userName: json['userName'] as String,
      userAvatar: json['userAvatar'] as String,
      timeAgo: json['timeAgo'] as String,
      content: json['content'] as String,
      imagePath: json['imagePath'] as String?,
      likes: json['likes'] as int,
      comments: json['comments'] as int,
      shares: json['shares'] as int,
      userEmail: json['userEmail'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}