import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  // Hardcoded API keys (replace with your actual keys)
  static const String _ambeeApiKey = '065971b5c0cb30db9ae6a29e0c86b670797a3aa26f53239780d3d3dcc626ab02';
  static const String _googleApiKey = 'AIzaSyCSHjnVgYUxWctnEfeH3S3501J-j0iYZU0';
  static const String _ambeeBaseUrl = 'https://api.ambeedata.com/weather';
  static const String _googleBaseUrl = 'https://maps.googleapis.com/maps/api/geocode';

  // Cache for weather data to reduce API calls
  static final Map<String, WeatherData> _cache = {};

  Future<WeatherData> getWeatherByLatLng(double lat, double lng) async {
    final cacheKey = '$lat,$lng';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final url = Uri.parse('$_ambeeBaseUrl/latest/by-lat-lng?lat=$lat&lng=$lng&units=si');
    final response = await http.get(
      url,
      headers: {'x-api-key': _ambeeApiKey, 'Content-type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final weather = WeatherData.fromJson(json, city: 'Current Location');
      _cache[cacheKey] = weather;
      return weather;
    } else {
      final error = jsonDecode(response.body)['message'] ?? response.body;
      throw Exception('Failed to fetch weather: ${response.statusCode}, $error');
    }
  }

  Future<WeatherData> getWeatherByCity(String city) async {
    final cacheKey = city.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    //Get coordinates from Google API
    final coordinates = await _getCoordinatesFromCity(city);
    final lat = coordinates['lat'];
    final lng = coordinates['lng'];
    final placeName = coordinates['placeName'];

    //Fetch weather using Ambee by-lat-lng
    final url = Uri.parse('$_ambeeBaseUrl/latest/by-lat-lng?lat=$lat&lng=$lng&units=si');
    final response = await http.get(
      url,
      headers: {'x-api-key': _ambeeApiKey, 'Content-type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final weather = WeatherData.fromJson(json, city: placeName);
      _cache[cacheKey] = weather;
      return weather;
    } else {
      final error = jsonDecode(response.body)['message'] ?? response.body;
      if (response.statusCode == 401) {
        throw Exception('Invalid Ambee API key');
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}, $error');
      }
    }
  }

  Future<Map<String, dynamic>> _getCoordinatesFromCity(String city) async {
    final url = Uri.parse('$_googleBaseUrl/json?address=$city&key=$_googleApiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'OK' && json['results'].isNotEmpty) {
        final location = json['results'][0]['geometry']['location'];
        final placeName = json['results'][0]['formatted_address'] ?? city;
        return {
          'lat': location['lat'] as double,
          'lng': location['lng'] as double,
          'placeName': placeName,
        };
      } else {
        throw Exception('Place "$city" not found. Try a different name (e.g., Colombo, LK).');
      }
    } else {
      final error = jsonDecode(response.body)['error_message'] ?? response.body;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Invalid Google API key. Verify at console.cloud.google.com.');
      }
      throw Exception('Failed to fetch coordinates: ${response.statusCode}, $error');
    }
  }
}