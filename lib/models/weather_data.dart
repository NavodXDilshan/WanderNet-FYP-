import 'package:intl/intl.dart';

class WeatherData {
  final String cityName;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String weatherDescription;
  final String time;
  final String iconName;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherDescription,
    required this.time,
    required this.iconName,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, {String? city}) {
    final data = json['data'] as Map<String, dynamic>? ?? {};

    String timeString = 'Unknown';
    if (data['time'] is int) {
      final timestamp = data['time'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      timeString = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } else if (data['time'] is String) {
      timeString = data['time'] as String;
    }

    return WeatherData(
      cityName: city ?? data['place'] as String? ?? 'Unknown Location',
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (data['windSpeed'] as num?)?.toDouble() ?? 0.0,
      weatherDescription: data['summary'] as String? ?? _mapIconToDescription(data['icon'] as String? ?? 'unknown'),
      time: timeString,
      iconName: data['icon'] as String? ?? 'default',
    );
  }

  static String _mapIconToDescription(String iconName) {
    switch (iconName) {
      case 'clear-day':
        return 'Clear Sky';
      case 'clear-night':
        return 'Clear Night';
      case 'rain':
        return 'Rain';
      case 'snow':
        return 'Snow';
      case 'cloudy':
      case 'partly-cloudy-day':
      case 'partly-cloudy-night':
        return 'Cloudy';
      case 'wind':
        return 'Windy';
      default:
        return 'Unknown';
    }
  }
}