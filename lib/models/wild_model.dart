import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class WildLocationModel {
  String name;
  String locationId;
  String? rating;
  String? description;
  String? imageUrl;
  List<Map<String, dynamic>>? reviews; // Added reviews field

  WildLocationModel({
    required this.name,
    required this.locationId,
    this.rating,
    this.description,
    this.imageUrl,
    this.reviews,
  });

  static Future<List<WildLocationModel>> getWildLocation() async {
    const apiKey = '5E6B8DAB15DD45B6BD299E1C50DE14C1';
    const baseUrl = 'https://api.content.tripadvisor.com/api/v1';

    List<WildLocationModel> wildLocations = [
      WildLocationModel(name: "Sinharaja Forest Reserve", locationId: '447525'),
      WildLocationModel(name: "Horton Plains National Park", locationId: '2486502'),
      WildLocationModel(name: "Knuckles Conservation Forest", locationId: '1889410'),
    ];

    for (var wild in wildLocations) {
      try {
        // Fetch location details
        final detailsUrl = '$baseUrl/location/${wild.locationId}/details?language=en&currency=USD&key=$apiKey';
        final detailsResponse = await http.get(
          Uri.parse(detailsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Details API Response Status for ${wild.name}: ${detailsResponse.statusCode}');
        print('Details API Response Body for ${wild.name}: ${detailsResponse.body}');

        if (detailsResponse.statusCode == 200) {
          final detailsData = jsonDecode(detailsResponse.body);
          wild.rating = detailsData['rating']?.toString() ?? 'N/A';
          wild.description = detailsData['description']?.isNotEmpty ?? false
              ? detailsData['description']
              : 'No description available';
        } else {
          wild.rating = 'N/A';
          wild.description = 'Failed to load description';
          print('Failed to load details for ${wild.name}: ${detailsResponse.statusCode}');
        }

        // Fetch location photos
        final photosUrl = '$baseUrl/location/${wild.locationId}/photos?language=en&key=$apiKey';
        final photosResponse = await http.get(
          Uri.parse(photosUrl),
          headers: {'accept': 'application/json'},
        );

        print('Photos API Response Status for ${wild.name}: ${photosResponse.statusCode}');
        print('Photos API Response Body for ${wild.name}: ${photosResponse.body}');

        if (photosResponse.statusCode == 200) {
          final photosData = jsonDecode(photosResponse.body);
          final photos = photosData['data'] ?? [];
          if (photos.isNotEmpty && photos[0]['images']?['large']?['url'] != null) {
            wild.imageUrl = photos[0]['images']['large']['url'];
          } else {
            wild.imageUrl = null;
          }
        } else {
          wild.imageUrl = null;
          print('Failed to load photos for ${wild.name}: ${photosResponse.statusCode}');
        }

        // Fetch location reviews
        final reviewsUrl = '$baseUrl/location/${wild.locationId}/reviews?language=en&key=$apiKey';
        final reviewsResponse = await http.get(
          Uri.parse(reviewsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Reviews API Response Status for ${wild.name}: ${reviewsResponse.statusCode}');
        print('Reviews API Response Body for ${wild.name}: ${reviewsResponse.body}');

        if (reviewsResponse.statusCode == 200) {
          final reviewsData = jsonDecode(reviewsResponse.body);
          wild.reviews = (reviewsData['data'] as List?)?.map((review) => {
            'text': review['text'] ?? 'No review text',
            'rating': review['rating']?.toString() ?? 'N/A',
          }).toList() ?? [];
        } else {
          wild.reviews = [{'text': 'Failed to load reviews', 'rating': 'N/A'}];
          print('Failed to load reviews for ${wild.name}: ${reviewsResponse.statusCode}');
        }
      } catch (e) {
        print('Error fetching data for ${wild.name}: $e');
        wild.rating = 'N/A';
        wild.description = 'Error loading data';
        wild.imageUrl = null;
        wild.reviews = [{'text': 'Error loading reviews', 'rating': 'N/A'}];
      }
    }

    return wildLocations;
  }
}