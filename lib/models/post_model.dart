import 'package:flutter/material.dart';

class PostModel {
  final String id;
  final String userName;
  final String userAvatar;
  final String timeAgo;
  final String content;
  final String? imagePath;
  final ValueNotifier<int> likesNotifier;
  final int comments;
  final int shares;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final List<Map<String, dynamic>> commentsList;

  PostModel({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.timeAgo,
    required this.content,
    this.imagePath,
    required int likes,
    required this.comments,
    required this.shares,
    this.location,
    this.latitude,
    this.longitude,
    this.placeId,
    this.commentsList = const [],
  }) : likesNotifier = ValueNotifier(likes);

  int get likes => likesNotifier.value;
  set likes(int value) => likesNotifier.value = value;
}