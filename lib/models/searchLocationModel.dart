import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchLocationModel {
  String name;
  String? locationId;
  String? rating;
  String? description;
  String? imageUrl;
  List<Map<String, dynamic>>? reviews;

  SearchLocationModel({
    required this.name,
    this.locationId,
    this.rating,
    this.description,
    this.imageUrl,
    this.reviews,
  });

  factory SearchLocationModel.fromJson(Map<String, dynamic> json) {
    return SearchLocationModel(
      name: json['name'] ?? 'Unknown',
      locationId: json['locationId'],
      rating: json['rating'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'locationId': locationId,
      'rating': rating,
      'description': description,
      'imageUrl': imageUrl,
      'reviews': reviews,
    };
  }

  static Future<SearchLocationModel> fetchDetails(String locationId) async {
    const apiKey = '5E6B8DAB15DD45B6BD299E1C50DE14C1';
    const baseUrl = 'https://api.content.tripadvisor.com/api/v1';
    final model = SearchLocationModel(name: '', locationId: locationId);

    try {
      // Fetch location details
      final detailsUrl = '$baseUrl/location/$locationId/details?language=en&currency=USD&key=$apiKey';
      final detailsResponse = await http.get(
        Uri.parse(detailsUrl),
        headers: {'accept': 'application/json'},
      );

      print('Details API Response Status for $locationId: ${detailsResponse.statusCode}');
      print('Details API Response Body for $locationId: ${detailsResponse.body}');

      if (detailsResponse.statusCode == 200) {
        final detailsData = jsonDecode(detailsResponse.body);
        model.rating = detailsData['rating']?.toString() ?? 'N/A';
        model.description = detailsData['description']?.isNotEmpty ?? false
            ? detailsData['description']
            : 'No description available';
      } else {
        model.rating = 'N/A';
        model.description = 'Failed to load description';
        print('Failed to load details for $locationId: ${detailsResponse.statusCode}');
      }

      // Fetch location photos
      final photosUrl = '$baseUrl/location/$locationId/photos?language=en&key=$apiKey';
      final photosResponse = await http.get(
        Uri.parse(photosUrl),
        headers: {'accept': 'application/json'},
      );

      print('Photos API Response Status for $locationId: ${photosResponse.statusCode}');
      print('Photos API Response Body for $locationId: ${photosResponse.body}');

      if (photosResponse.statusCode == 200) {
        final photosData = jsonDecode(photosResponse.body);
        final photos = photosData['data'] ?? [];
        if (photos.isNotEmpty && photos[0]['images']?['large']?['url'] != null) {
          model.imageUrl = photos[0]['images']['large']['url'];
        } else {
          model.imageUrl = null;
        }
      } else {
        model.imageUrl = null;
        print('Failed to load photos for $locationId: ${photosResponse.statusCode}');
      }

      // Fetch location reviews
      final reviewsUrl = '$baseUrl/location/$locationId/reviews?language=en&key=$apiKey';
      final reviewsResponse = await http.get(
        Uri.parse(reviewsUrl),
        headers: {'accept': 'application/json'},
      );

      print('Reviews API Response Status for $locationId: ${reviewsResponse.statusCode}');
      print('Reviews API Response Body for $locationId: ${reviewsResponse.body}');

      if (reviewsResponse.statusCode == 200) {
        final reviewsData = jsonDecode(reviewsResponse.body);
        model.reviews = (reviewsData['data'] as List?)?.map((review) => {
          'text': review['text'] ?? 'No review text',
          'rating': review['rating']?.toString() ?? 'N/A',
        }).toList() ?? [];
      } else {
        model.reviews = [{'text': 'Failed to load reviews', 'rating': 'N/A'}];
        print('Failed to load reviews for $locationId: ${reviewsResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching data for $locationId: $e');
      model.rating = 'N/A';
      model.description = 'Error loading data';
      model.imageUrl = null;
      model.reviews = [{'text': 'Error loading reviews', 'rating': 'N/A'}];
    }

    return model;
  }
}