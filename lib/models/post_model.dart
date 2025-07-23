class PostModel {
  final String id;
  final String userName;
  final String userAvatar;
  final String timeAgo;
  final String content;
  final String? imagePath;
  final int likes;
  int comments;
  final int shares;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final DateTime createdAt;
  final List<Map<String, dynamic>> commentsList;
  final String? valid;

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
    this.location,
    this.latitude,
    this.longitude,
    this.placeId,
    required this.createdAt,
    this.commentsList = const [],
    this.valid,
  });
}