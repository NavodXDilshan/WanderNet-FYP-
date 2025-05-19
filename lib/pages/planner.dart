import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';
import '../models/weather_data.dart';

class Planner extends StatefulWidget {
  const Planner({super.key});

  @override
  PlannerState createState() => PlannerState();
}

class PlannerState extends State<Planner> {
  GoogleMapController? _mapController;
  static const LatLng _sriLankaCenter = LatLng(7.8731, 80.7718);
  static LatLngBounds _sriLankaBounds = LatLngBounds(
    southwest: LatLng(5.9167, 79.6522),
    northeast: LatLng(9.8350, 81.8815),
  );
  bool _isLocationPermissionGranted = false;
  WeatherData? _weatherData;
  final WeatherService _weatherService = WeatherService();
  String? selectedOption = 'Max Node';
  final List<String> options = ['Max Node', 'Max Rating', 'Hybrid'];

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) {
      setState(() {
        _isLocationPermissionGranted = true;
      });
    } else if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.location.request();
      if (status.isGranted) {
        setState(() {
          _isLocationPermissionGranted = true;
        });
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is permanently denied. Please enable it in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setLatLngBounds(_sriLankaBounds);
  }

  Future<void> _fetchWeatherForLocation(LatLng location) async {
    try {
      WeatherData weather = await _weatherService.getWeatherByLatLng(
        location.latitude,
        location.longitude,
      );
      setState(() {
        _weatherData = weather;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weather: ${weather.weatherDescription}, ${weather.temperature}°C',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch weather: $e')),
      );
    }
  }

  void _updateSelectedOption(String? value) {
    setState(() {
      selectedOption = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: appBar(),
      drawer: DrawerBar(
        selectedOption: selectedOption,
        options: options,
        onOptionChanged: _updateSelectedOption,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _sriLankaCenter,
              zoom: 7.5,
            ),
            cameraTargetBounds: CameraTargetBounds(_sriLankaBounds),
            myLocationEnabled: _isLocationPermissionGranted,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            minMaxZoomPreference: const MinMaxZoomPreference(7.0, 15.0),
            markers: {
              const Marker(
                markerId: MarkerId('colombo'),
                position: LatLng(6.9271, 79.8612),
                infoWindow: InfoWindow(title: 'Colombo'),
              ),
            },
            onTap: _fetchWeatherForLocation,
          ),
          if (!_isLocationPermissionGranted)
            Positioned(
              bottom: 16,
              left: 16,
              child: ElevatedButton(
                onPressed: _checkAndRequestLocationPermission,
                child: const Text('Enable Location'),
              ),
            ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      title: const Text('Plan Your Tour'),
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.menu),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class DrawerBar extends StatelessWidget {
  final String? selectedOption;
  final List<String> options;
  final ValueChanged<String?> onOptionChanged;

  const DrawerBar({
    super.key,
    required this.selectedOption,
    required this.options,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate or do something
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: const Text('Setting'),
            onTap: () {
              Navigator.pop(context);
              // Navigate or do something
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // Navigate or do something
            },
          ),
          ListTile(
            title: const Text('Select Option'),
            subtitle: Column(
              children: options
                  .map(
                    (option) => RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: selectedOption,
                      onChanged: onOptionChanged,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

extension on GoogleMapController? {
  void setLatLngBounds(LatLngBounds sriLankaBounds) {}
}