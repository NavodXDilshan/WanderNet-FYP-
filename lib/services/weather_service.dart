import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  static const String _apiKey = 'e8b076d174ea56742e0a0057e60f338006a36bbf52c845f1a95db124e2f8102b'; // Replace with your Ambee API key
  static const String _baseUrl = 'https://api.ambeedata.com/weather/latest';

  Future<WeatherData> getWeatherByLatLng(double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/by-lat-lng?lat=$lat&lng=$lng&units=si');
    final response = await http.get(
      url,
      headers: {'x-api-key': _apiKey, 'Content-type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return WeatherData.fromJson(json);
    } else {
      throw Exception('Failed to fetch weather data: ${response.statusCode}');
    }
  }

  Future<WeatherData> getWeatherByCity(String city) async {
    final url = Uri.parse('$_baseUrl/by-place?place=$city&units=si');
    final response = await http.get(
      url,
      headers: {'x-api-key': _apiKey, 'Content-type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return WeatherData.fromJson(json);
    } else {
      throw Exception('Failed to fetch weather data: ${response.statusCode}');
    }
  }
}