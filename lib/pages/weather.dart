import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/weather_service.dart';
import '../models/weather_data.dart';
import '../dbHelper/mongodb.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthService {
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<Map<String, String?>> getUserInfo() async {
    final user = supabase.auth.currentUser;
    print('Current user: ${user?.id}, email: ${user?.email}, metadata: ${user?.userMetadata}');
    if (user == null) {
      print('No authenticated user found');
      return {'userEmail': null, 'username': null, 'userId': null};
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('user_id', user.id)
          .single();
      return {
        'userEmail': user.email,
        'username': response['username'] as String? ?? 'Guest',
        'userId': user.id
      };
    } catch (e) {
      print('Error fetching username from profiles: $e');
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? 'Guest',
        'userId': user.id
      };
    }
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  List<Map<String, dynamic>> _wishlistWeatherData = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _cityController = TextEditingController();
  String? userEmail;
  String? username;
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchWeatherByLocation();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getUserInfo();
    setState(() {
      userEmail = userInfo['userEmail'];
      username = userInfo['username'];
      userId = userInfo['userId'];
    });
    if (userEmail != null) {
      await _loadWishlistWeather();
    }
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
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    try {
      await MongoDataBase.connect();
      final wishlistItems = await MongoDataBase.fetchWishlistItems(userEmail!);
      print('Wishlist items for $userEmail: $wishlistItems');
      final weatherList = <Map<String, dynamic>>[];
      for (var item in wishlistItems) {
        final lat = item['latitude'] as double?;
        final lng = item['longitude'] as double?;
        final placeName = item['placeName'] as String? ?? 'Unknown';
        if (lat != null && lng != null) {
          try {
            final weather = await _weatherService.getWeatherByLatLng(lat, lng);
            weatherList.add({
              'placeName': placeName,
              'weather': weather,
            });
          } catch (e) {
            print('Failed to fetch weather for $placeName: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wishlist: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weather Tracker',
          style: const TextStyle(color: Color.fromARGB(255, 237, 230, 230), fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/weather.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.black.withOpacity(0.4), // Semi-transparent overlay for readability
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 0, left: 0, right: 0),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.11),
                          blurRadius: 40,
                          spreadRadius: 0.0,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Enter place',
                        filled: true,
                        fillColor: const Color.fromARGB(255, 255, 255, 255),
                        contentPadding: const EdgeInsets.all(15),
                        hintText: 'search',
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SvgPicture.asset('assets/icons/Search.svg'),
                        ),
                        suffixIcon: SizedBox(
                          width: 100,
                          child: IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const VerticalDivider(
                                  color: Colors.black,
                                  indent: 10,
                                  endIndent: 10,
                                  thickness: 0.1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SvgPicture.asset('assets/icons/Filter.svg'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _fetchWeatherByCity(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: _fetchWeatherByLocation,
                      child: const Text('Use Current Location'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage.isNotEmpty)
                    Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
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
                                    color: const Color.fromARGB(255, 240, 144, 9),
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
                                        : const Icon(Icons.help_outline, size: 40.0),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  if (_wishlistWeatherData.isEmpty && userEmail != null)
                    const Center(child: Text('No wishlist items found.'))
                  else if (_wishlistWeatherData.isEmpty && userEmail == null)
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage())),
                        child: const Text('Sign in to view wishlist'),
                      ),
                    )
                  else
                    ..._wishlistWeatherData.map((entry) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ExpansionTile(
                            title: Center(
                              child: Text(
                                entry['placeName'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            leading: entry['weather'].iconName.isNotEmpty
                                ? _getIconFromName(entry['weather'].iconName)
                                : const Icon(Icons.help_outline, size: 40.0),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: entry['weather'].iconName.isNotEmpty
                                          ? _getIconFromName(entry['weather'].iconName)
                                          : const Icon(Icons.help_outline, size: 40.0),
                                    ),
                                    const Divider(height: 20),
                                    _buildWeatherRow('', entry['weather'].weatherDescription),
                                    _buildWeatherRow('Temperature', '${entry['weather'].temperature} °C'),
                                    _buildWeatherRow('Humidity', '${entry['weather'].humidity}%'),
                                    _buildWeatherRow('Wind Speed', '${entry['weather'].windSpeed} m/s'),
                                    _buildWeatherRow('Time', entry['weather'].time),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          label.isEmpty
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 64.0,
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                )
              : Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.right,
                    softWrap: true,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _getIconFromName(String iconName) {
    switch (iconName) {
      case 'clear-day':
        return Image.asset('assets/icons/sunny.png', width: 40, height: 40);
      case 'clear-night':
        return Image.asset('assets/icons/moon-and-stars.png', width: 40, height: 40);
      case 'rain':
        return Image.asset('assets/icons/heavy-rain.png', width: 40, height: 40);
      case 'snow':
        return Image.asset('assets/icons/snow.png', width: 40, height: 40);
      case 'cloudy':
        return Image.asset('assets/icons/clouds.png', width: 40, height: 40);
      case 'partly-cloudy-day':
        return Image.asset('assets/icons/cloudy-day.png', width: 40, height: 40);
      case 'partly-cloudy-night':
        return Image.asset('assets/icons/partly-cloudy-night.png', width: 40, height: 40);
      case 'wind':
        return Image.asset('assets/icons/wind.png', width: 40, height: 40);
      default:
        return const Icon(Icons.help_outline, size: 40.0);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: const Center(child: Text('Sign In Page')),
    );
  }
}