import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';
import '../models/weather_data.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _cityController = TextEditingController();
  

  @override
  void initState() {
    super.initState();
    _fetchWeatherByLocation();
  }

  Future<void> _fetchWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enable location services';
      });
      return;
    }

    // Check permission
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
    if (_cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a city name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      WeatherData weather = await _weatherService.getWeatherByCity(_cityController.text);
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _weatherData == null && _errorMessage.isEmpty) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 250, 181, 96),
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.white, // White spinner for contrast
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Tracker'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'Enter city (e.g., Colombo)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _fetchWeatherByCity,
                ),
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
                style: const TextStyle(color: Colors.red),
              )
            else if (_weatherData != null)
              Container(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    // mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      cardTemplate(context, Text('Weather')),
                      cardTemplate(context, Text('${_weatherData!.weatherDescription}',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
              
              Card(
                
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      cardTemplate(context, Text('Temperature: ${_weatherData!.temperature} °C')),
                      cardTemplate(context, Text('Humidity: ${_weatherData!.humidity}%')),
                      cardTemplate(context, Text('Wind Speed: ${_weatherData!.windSpeed} m/s')),
                      cardTemplate(context, Text('Time: ${_weatherData!.time}')),
                      _getIconFromName(_weatherData!.iconName)
                    ],
                  ),
                ),
              ),
              
          ],
        ),
      ),
    );
  }

  Widget cardTemplate(BuildContext context, Widget child){
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child:Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child
          ],
        ))
    );
  }

  Icon _getIconFromName(String iconName) {
  switch (iconName) {
    case 'clear-day':
      return Icon(Icons.wb_sunny, color: Colors.orange);
    case 'rain':
      return Icon(Icons.beach_access, color: Colors.blue, size: 55.0,);
    case 'cloudy':
      return Icon(Icons.cloud, color: Colors.grey);
    default:
      return Icon(Icons.help_outline);
  }
}

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}