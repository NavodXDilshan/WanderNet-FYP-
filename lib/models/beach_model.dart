import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class BeachLocationModel {
  String name;
  String locationId;
  String? rating;
  String? description;
  String? imageUrl;
  List<Map<String, dynamic>>? reviews; // Added reviews field

  BeachLocationModel({
    required this.name,
    required this.locationId,
    this.rating,
    this.description,
    this.imageUrl,
    this.reviews,
  });

  static Future<List<BeachLocationModel>> getBeachLocations() async {
    const apiKey = '5E6B8DAB15DD45B6BD299E1C50DE14C1';
    const baseUrl = 'https://api.content.tripadvisor.com/api/v1';

    List<BeachLocationModel> beachLocations = [
      BeachLocationModel(name: "Bentota Beach", locationId: '7029063'),
      BeachLocationModel(name: "Arugam Bay", locationId: '577794'),
      BeachLocationModel(name: "Mirissa Beach", locationId: '6104104'),
    ];

    for (var beach in beachLocations) {
      try {
        // Fetch location details
        final detailsUrl = '$baseUrl/location/${beach.locationId}/details?language=en&currency=USD&key=$apiKey';
        final detailsResponse = await http.get(
          Uri.parse(detailsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Details API Response Status for ${beach.name}: ${detailsResponse.statusCode}');
        print('Details API Response Body for ${beach.name}: ${detailsResponse.body}');

        if (detailsResponse.statusCode == 200) {
          final detailsData = jsonDecode(detailsResponse.body);
          beach.rating = detailsData['rating']?.toString() ?? 'N/A';
          beach.description = detailsData['description']?.isNotEmpty ?? false
              ? detailsData['description']
              : 'No description available';
        } else {
          beach.rating = 'N/A';
          beach.description = 'Failed to load description';
          print('Failed to load details for ${beach.name}: ${detailsResponse.statusCode}');
        }

        // Fetch location photos
        final photosUrl = '$baseUrl/location/${beach.locationId}/photos?language=en&key=$apiKey';
        final photosResponse = await http.get(
          Uri.parse(photosUrl),
          headers: {'accept': 'application/json'},
        );

        print('Photos API Response Status for ${beach.name}: ${photosResponse.statusCode}');
        print('Photos API Response Body for ${beach.name}: ${photosResponse.body}');

        if (photosResponse.statusCode == 200) {
          final photosData = jsonDecode(photosResponse.body);
          final photos = photosData['data'] ?? [];
          if (photos.isNotEmpty && photos[0]['images']?['large']?['url'] != null) {
            beach.imageUrl = photos[0]['images']['large']['url'];
          } else {
            beach.imageUrl = null;
          }
        } else {
          beach.imageUrl = null;
          print('Failed to load photos for ${beach.name}: ${photosResponse.statusCode}');
        }

        // Fetch location reviews
        final reviewsUrl = '$baseUrl/location/${beach.locationId}/reviews?language=en&key=$apiKey';
        final reviewsResponse = await http.get(
          Uri.parse(reviewsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Reviews API Response Status for ${beach.name}: ${reviewsResponse.statusCode}');
        print('Reviews API Response Body for ${beach.name}: ${reviewsResponse.body}');

        if (reviewsResponse.statusCode == 200) {
          final reviewsData = jsonDecode(reviewsResponse.body);
          beach.reviews = (reviewsData['data'] as List?)?.map((review) => {
            'text': review['text'] ?? 'No review text',
            'rating': review['rating']?.toString() ?? 'N/A',
          }).toList() ?? [];
        } else {
          beach.reviews = [{'text': 'Failed to load reviews', 'rating': 'N/A'}];
          print('Failed to load reviews for ${beach.name}: ${reviewsResponse.statusCode}');
        }
      } catch (e) {
        print('Error fetching data for ${beach.name}: $e');
        beach.rating = 'N/A';
        beach.description = 'Error loading data';
        beach.imageUrl = null;
        beach.reviews = [{'text': 'Error loading reviews', 'rating': 'N/A'}];
      }
    }

    return beachLocations;
  }
}