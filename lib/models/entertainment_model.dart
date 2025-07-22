import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class EntertainmentModel {
  String name;
  String locationId;
  String? rating;
  String? description;
  String? imageUrl;
  List<Map<String, dynamic>>? reviews; // Added reviews field

  EntertainmentModel({
    required this.name,
    required this.locationId,
    this.rating,
    this.description,
    this.imageUrl,
    this.reviews,
  });

  static Future<List<EntertainmentModel>> getEntertainmentLocations() async {
    const apiKey = '5E6B8DAB15DD45B6BD299E1C50DE14C1';
    const baseUrl = 'https://api.content.tripadvisor.com/api/v1';

    List<EntertainmentModel> entertainmentLocations = [
      EntertainmentModel(name: "Pearl Bay", locationId: '21111465'),
      EntertainmentModel(name: "Excel World Entertainment Park", locationId: '7694530'),
      EntertainmentModel(name: "Bellagio Colombo Casino", locationId: '10432705'),
    ];

    for (var entertainment in entertainmentLocations) {
      try {
        // Fetch location details
        final detailsUrl = '$baseUrl/location/${entertainment.locationId}/details?language=en&currency=USD&key=$apiKey';
        final detailsResponse = await http.get(
          Uri.parse(detailsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Details API Response Status for ${entertainment.name}: ${detailsResponse.statusCode}');
        print('Details API Response Body for ${entertainment.name}: ${detailsResponse.body}');

        if (detailsResponse.statusCode == 200) {
          final detailsData = jsonDecode(detailsResponse.body);
          entertainment.rating = detailsData['rating']?.toString() ?? 'N/A';
          entertainment.description = detailsData['description']?.isNotEmpty ?? false
              ? detailsData['description']
              : 'No description available';
        } else {
          entertainment.rating = 'N/A';
          entertainment.description = 'Failed to load description';
          print('Failed to load details for ${entertainment.name}: ${detailsResponse.statusCode}');
        }

        // Fetch location photos
        final photosUrl = '$baseUrl/location/${entertainment.locationId}/photos?language=en&key=$apiKey';
        final photosResponse = await http.get(
          Uri.parse(photosUrl),
          headers: {'accept': 'application/json'},
        );

        print('Photos API Response Status for ${entertainment.name}: ${photosResponse.statusCode}');
        print('Photos API Response Body for ${entertainment.name}: ${photosResponse.body}');

        if (photosResponse.statusCode == 200) {
          final photosData = jsonDecode(photosResponse.body);
          final photos = photosData['data'] ?? [];
          if (photos.isNotEmpty && photos[0]['images']?['large']?['url'] != null) {
            entertainment.imageUrl = photos[0]['images']['large']['url'];
          } else {
            entertainment.imageUrl = null;
          }
        } else {
          entertainment.imageUrl = null;
          print('Failed to load photos for ${entertainment.name}: ${photosResponse.statusCode}');
        }

        // Fetch location reviews
        final reviewsUrl = '$baseUrl/location/${entertainment.locationId}/reviews?language=en&key=$apiKey';
        final reviewsResponse = await http.get(
          Uri.parse(reviewsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Reviews API Response Status for ${entertainment.name}: ${reviewsResponse.statusCode}');
        print('Reviews API Response Body for ${entertainment.name}: ${reviewsResponse.body}');

        if (reviewsResponse.statusCode == 200) {
          final reviewsData = jsonDecode(reviewsResponse.body);
          entertainment.reviews = (reviewsData['data'] as List?)?.map((review) => {
            'text': review['text'] ?? 'No review text',
            'rating': review['rating']?.toString() ?? 'N/A',
          }).toList() ?? [];
        } else {
          entertainment.reviews = [{'text': 'Failed to load reviews', 'rating': 'N/A'}];
          print('Failed to load reviews for ${entertainment.name}: ${reviewsResponse.statusCode}');
        }
      } catch (e) {
        print('Error fetching data for ${entertainment.name}: $e');
        entertainment.rating = 'N/A';
        entertainment.description = 'Error loading data';
        entertainment.imageUrl = null;
        entertainment.reviews = [{'text': 'Error loading reviews', 'rating': 'N/A'}];
      }
    }

    return entertainmentLocations;
  }
}