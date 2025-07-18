import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class HotelLocationModel {
  String name;
  String locationId;
  String? rating;
  String? description;
  String? imageUrl;

  HotelLocationModel({
    required this.name,
    required this.locationId,
    this.rating,
    this.description,
    this.imageUrl,
  });

  static Future<List<HotelLocationModel>> getHotelLocations() async {
    const apiKey = '5E6B8DAB15DD45B6BD299E1C50DE14C1'; 
    const baseUrl = 'https://api.content.tripadvisor.com/api/v1';

    List<HotelLocationModel> hotelLocations = [
      HotelLocationModel(name: "Marino Beach Colombo", locationId: '14106301'),
      HotelLocationModel(name: "Heritance Kandalama", locationId: '315685'),
      HotelLocationModel(name: "Araliya Beach Resort & Spa", locationId: '23262280'),
    ];

    for (var hotel in hotelLocations) {
      try {
        // Fetch location details
        final detailsUrl = '$baseUrl/location/${hotel.locationId}/details?language=en&currency=USD&key=$apiKey';
        final detailsResponse = await http.get(
          Uri.parse(detailsUrl),
          headers: {'accept': 'application/json'},
        );

        print('Details API Response Status for ${hotel.name}: ${detailsResponse.statusCode}');
        print('Details API Response Body for ${hotel.name}: ${detailsResponse.body}');

        if (detailsResponse.statusCode == 200) {
          final detailsData = jsonDecode(detailsResponse.body);
          hotel.rating = detailsData['rating']?.toString() ?? 'N/A';
          hotel.description = detailsData['description']?.isNotEmpty ?? false
              ? detailsData['description']
              : 'No description available';
        } else {
          hotel.rating = 'N/A';
          hotel.description = 'Failed to load description';
          print('Failed to load details for ${hotel.name}: ${detailsResponse.statusCode}');
        }

        // Fetch location photos
        final photosUrl = '$baseUrl/location/${hotel.locationId}/photos?language=en&key=$apiKey';
        final photosResponse = await http.get(
          Uri.parse(photosUrl),
          headers: {'accept': 'application/json'},
        );

        print('Photos API Response Status for ${hotel.name}: ${photosResponse.statusCode}');
        print('Photos API Response Body for ${hotel.name}: ${photosResponse.body}');

        if (photosResponse.statusCode == 200) {
          final photosData = jsonDecode(photosResponse.body);
          final photos = photosData['data'] ?? [];
          if (photos.isNotEmpty && photos[0]['images']?['large']?['url'] != null) {
            hotel.imageUrl = photos[0]['images']['large']['url'];
          } else {
            hotel.imageUrl = null; // No image available
          }
        } else {
          hotel.imageUrl = null;
          print('Failed to load photos for ${hotel.name}: ${photosResponse.statusCode}');
        }
      } catch (e) {
        print('Error fetching data for ${hotel.name}: $e');
        hotel.rating = 'N/A';
        hotel.description = 'Error loading data';
        hotel.imageUrl = null;
      }
    }

    return hotelLocations;
  }
}