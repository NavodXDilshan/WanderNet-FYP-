import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:app/models/post_model.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000';
  
  static Future<List<Map<String, dynamic>>> getCommentedPosts(String username) async {
    try {
      // URL encode the username to handle spaces and special characters
      final encodedUsername = Uri.encodeComponent(username);
      final url = Uri.parse('$baseUrl/posts/commented?username="$encodedUsername"');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching posts: $e');
    }
  }
}