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
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? placeId; // New field

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
  });
}