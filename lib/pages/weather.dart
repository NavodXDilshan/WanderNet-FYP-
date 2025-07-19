import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';
import '../models/weather_data.dart';
import '../dbHelper/mongodb.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  List<WeatherData> _wishlistWeatherData = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _cityController = TextEditingController();
  final String userEmail = 'k.m.navoddilshan@gmail.com';

  @override
  void initState() {
    super.initState();
    _fetchWeatherByLocation();
    _loadWishlistWeather();
  }

  Future<void> _fetchWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enable location services';
      });
      return;
    }

    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        WeatherData weather = await _weatherService.getWeatherByLatLng(
          position.latitude,
          position.longitude,
        );
        setState(() {
          _weatherData = weather;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch weather: $e';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = status.isPermanentlyDenied
            ? 'Location permission permanently denied. Enable in settings.'
            : 'Location permission denied';
      });
      if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable location in settings'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchWeatherByCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a place name')),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z\s,-]+$').hasMatch(city)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid place name (letters, spaces, commas, or hyphens only)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      WeatherData weather = await _weatherService.getWeatherByCity(city);
      setState(() {
        _weatherData = weather;
        _isLoading = false;
        _cityController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weather fetched for ${weather.cityName}')),
      );
    } catch (e) {
      String errorMsg;
      if (e.toString().contains('Invalid Ambee API key')) {
        errorMsg = 'Invalid Ambee API key. Verify at api.ambeedata.com.';
      } else if (e.toString().contains('Invalid Google API key')) {
        errorMsg = 'Invalid Google API key. Verify at console.cloud.google.com.';
      } else if (e.toString().contains('not found')) {
        errorMsg = 'Place "$city" not found. Try a different name (e.g., Colombo, LK).';
      } else if (e.toString().contains('network')) {
        errorMsg = 'Network error. Please check your internet connection.';
      } else {
        errorMsg = 'Failed to fetch weather: $e';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Future<void> _loadWishlistWeather() async {
    try {
      await MongoDataBase.connect();
      final wishlistItems = await MongoDataBase.fetchWishlistItems(userEmail);
      final weatherList = <WeatherData>[];
      for (var item in wishlistItems) {
        final lat = item['latitude'] as double?;
        final lng = item['longitude'] as double?;
        if (lat != null && lng != null) {
          try {
            final weather = await _weatherService.getWeatherByLatLng(lat, lng);
            weatherList.add(weather);
          } catch (e) {
            print('Failed to fetch weather for ${item['placeName']}: $e');
          }
        }
      }
      setState(() {
        _wishlistWeatherData = weatherList;
      });
    } catch (e) {
      print('Error loading wishlist weather: $e');
      setState(() {
        _wishlistWeatherData = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Tracker'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'Enter place',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _fetchWeatherByCity,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _fetchWeatherByCity(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchWeatherByLocation,
                child: const Text('Use Current Location'),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                )
              else if (_weatherData != null)
                Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _weatherData!.cityName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _weatherData!.weatherDescription,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWeatherRow('Temperature', '${_weatherData!.temperature} °C'),
                            _buildWeatherRow('Humidity', '${_weatherData!.humidity}%'),
                            _buildWeatherRow('Wind Speed', '${_weatherData!.windSpeed} m/s'),
                            _buildWeatherRow('Time', _weatherData!.time),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _weatherData!.iconName.isNotEmpty
                                    ? _getIconFromName(_weatherData!.iconName)
                                    : const Icon(Icons.help_outline, size: 55.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Text(
                'Wishlist Locations Weather',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ..._wishlistWeatherData.map((weather) => ExpansionTile(
                    title: Row(
                      children: [
                        weather.iconName.isNotEmpty
                            ? _getIconFromName(weather.iconName)
                            : const Icon(Icons.help_outline, size: 40.0),
                        const SizedBox(width: 10),
                        Text(
                          '${weather.temperature} °C',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWeatherRow('City', weather.cityName),
                            _buildWeatherRow('Description', weather.weatherDescription),
                            _buildWeatherRow('Temperature', '${weather.temperature} °C'),
                            _buildWeatherRow('Humidity', '${weather.humidity}%'),
                            _buildWeatherRow('Wind Speed', '${weather.windSpeed} m/s'),
                            _buildWeatherRow('Time', weather.time),
                          ],
                        ),
                      ),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Icon _getIconFromName(String iconName) {
    switch (iconName) {
      case 'clear-day':
        return const Icon(Icons.wb_sunny, color: Colors.orange, size: 55.0);
      case 'clear-night':
        return const Icon(Icons.nightlight_round, color: Colors.blueGrey, size: 55.0);
      case 'rain':
        return const Icon(Icons.beach_access, color: Colors.blue, size: 55.0);
      case 'snow':
        return const Icon(Icons.ac_unit, color: Colors.lightBlueAccent, size: 55.0);
      case 'cloudy':
      case 'partly-cloudy-day':
      case 'partly-cloudy-night':
        return const Icon(Icons.cloud, color: Colors.grey, size: 55.0);
      case 'wind':
        return const Icon(Icons.air, color: Colors.teal, size: 55.0);
      default:
        return const Icon(Icons.help_outline, size: 55.0);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}