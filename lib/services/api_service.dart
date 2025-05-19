import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app/models/post_model.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000'; // Update for production

  // Fetch all posts for general feed
  Future<List<PostModel>> fetchPosts() async {
    final response = await http.get(Uri.parse('$baseUrl/posts'));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => PostModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
  }

  // Fetch posts by a specific user
  Future<List<PostModel>> fetchUserPosts(String email) async {
    final response = await http.get(Uri.parse('$baseUrl/posts/$email'));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => PostModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load user posts: ${response.statusCode}');
    }
  }

  // Create a new post
  Future<void> createPost(String email, PostModel post) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': post.userName,
        'userAvatar': post.userAvatar,
        'timeAgo': post.timeAgo,
        'content': post.content,
        'imagePath': post.imagePath,
        'likes': post.likes,
        'comments': post.comments,
        'shares': post.shares,
        'createdAt': post.createdAt,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create post');
    }
  }

  // Like a post
  Future<void> likePost(String email, String postId) async {
    final response = await http.patch(Uri.parse('$baseUrl/posts/$email/$postId/like'));
    if (response.statusCode != 200) {
      throw Exception('Failed to like post');
    }
  }
}