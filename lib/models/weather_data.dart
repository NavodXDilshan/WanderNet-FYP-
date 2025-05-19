import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String weatherDescription;
  final String time;
  final String iconName;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherDescription,
    required this.time,
    required this.iconName,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};

    // Handle time as Unix timestamp (int)
    String timeString = 'Unknown';
    if (data['time'] is int) {
      final timestamp = data['time'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      timeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } else if (data['time'] is String) {
      timeString = data['time'] as String;
    }
  

    return WeatherData(
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (data['windSpeed'] as num?)?.toDouble() ?? 0.0,
      weatherDescription: data['summary'] as String? ?? data['icon'] as String? ?? 'Unknown',
      time: timeString,
      iconName: data['icon'] as String? ?? 'default',
    );
  }

  get text => null;

  static Icon _mapIcon(String iconName) {
  switch (iconName) {
    case 'clear-day':
      return Icon(Icons.wb_sunny, color: Colors.orange);
    case 'clear-night':
      return Icon(Icons.nightlight_round, color: Colors.blueGrey);
    case 'rain':
      return Icon(Icons.beach_access, color: Colors.blue);
    case 'snow':
      return Icon(Icons.ac_unit, color: Colors.lightBlueAccent);
    case 'cloudy':
    case 'partly-cloudy-day':
    case 'partly-cloudy-night':
      return Icon(Icons.cloud, color: Colors.grey);
    case 'wind':
      return Icon(Icons.air, color: Colors.teal);
    default:
      return Icon(Icons.help_outline, color: Colors.grey);
  }
}

}