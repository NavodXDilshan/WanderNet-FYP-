class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String weatherDescription;
  final String time;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherDescription,
    required this.time,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return WeatherData(
      temperature: (data['temperature'] as num).toDouble(),
      humidity: (data['humidity'] as num).toDouble(),
      windSpeed: (data['windSpeed'] as num).toDouble(),
      weatherDescription: data['weather']['description'] as String,
      time: data['time'] as String,
    );
  }
}