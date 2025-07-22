import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../dbHelper/mongodb.dart';
import 'settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _timeConstraintController = TextEditingController();
  String? userEmail;
  String? username;
  String? userId;
  String? selectedOption = 'Max Node';
  String? selectedStartPlaceId;
  String? selectedTargetPlaceId;
  List<Map<String, dynamic>> wishlistItems = [];
  List<Map<String, dynamic>> nearbyAttractions = [];
  final List<String> options = ['Max Node', 'Max Rating', 'Hybrid'];
  static const String googleApiKey = 'AIzaSyCSHjnVgYUxWctnEfeH3S3501J-j0iYZU0';
  bool _useRealRoutes = true;

  final Map<String, String> algorithmMapping = {
    'Max Node': 'max_nodes',
    'Max Rating': 'max_score',
    'Hybrid': 'hybrid',
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkAndRequestLocationPermission();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getUserInfo();
    setState(() {
      userEmail = userInfo['userEmail'];
      username = userInfo['username'];
      userId = userInfo['userId'];
    });
    if (userEmail != null) {
      await _loadWishlistData();
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        print('Location services disabled');
        return;
      }

      PermissionStatus status = await Permission.location.status;
      if (status.isGranted) {
        setState(() {
          _isLocationPermissionGranted = true;
        });
        print('Location permission granted');
      } else if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.location.request();
        if (status.isGranted) {
          setState(() {
            _isLocationPermissionGranted = true;
          });
          print('Location permission granted after request');
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
          print('Location permission permanently denied');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          print('Location permission denied');
        }
      }
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }

  Future<void> _loadWishlistData() async {
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    try {
      final items = await MongoDataBase.fetchWishlistItems(userEmail!);
      print('Loaded wishlist items for $userEmail: ${items.length}');
      final seenPlaceIds = <String>{};
      final uniqueItems = items.where((item) {
        final placeId = item['placeId'] as String? ?? (item['placeName'] as String? ?? 'Unknown Place');
        if (seenPlaceIds.contains(placeId)) {
          print('Duplicate placeId detected: $placeId');
          return false;
        }
        seenPlaceIds.add(placeId);
        return true;
      }).toList();

      final newMarkers = uniqueItems.map((item) {
        final lat = item['latitude'] as double?;
        final lng = item['longitude'] as double?;
        final placeName = item['placeName'] as String? ?? 'Unknown Place';
        final placeId = item['placeId'] as String? ?? placeName;
        if (lat == null || lng == null) {
          print('Invalid coordinates for $placeName: lat=$lat, lng=$lng');
          return null;
        }
        return Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: placeName,
          ),
          onTap: () => _showRemoveDialog(placeId, placeName),
        );
      }).whereType<Marker>().toSet();

      setState(() {
        wishlistItems = uniqueItems;
        _markers = newMarkers;
        // Reset selectedStartPlaceId and selectedTargetPlaceId if they are invalid
        if (wishlistItems.isNotEmpty) {
          final validStart = wishlistItems.any((item) => item['placeId'] == selectedStartPlaceId || item['placeName'] == selectedStartPlaceId);
          final validTarget = wishlistItems.any((item) => item['placeId'] == selectedTargetPlaceId || item['placeName'] == selectedTargetPlaceId);
          
          selectedStartPlaceId = validStart ? selectedStartPlaceId : (wishlistItems[0]['placeId'] as String? ?? wishlistItems[0]['placeName'] as String? ?? 'Unknown Place');
          selectedTargetPlaceId = validTarget && wishlistItems.length > 1
              ? selectedTargetPlaceId
              : (wishlistItems.length > 1
                  ? (wishlistItems[1]['placeId'] as String? ?? wishlistItems[1]['placeName'] as String? ?? 'Unknown Place')
                  : selectedStartPlaceId);
        } else {
          selectedStartPlaceId = null;
          selectedTargetPlaceId = null;
        }
      });
      print('Wishlist updated: ${wishlistItems.length} items, Start: $selectedStartPlaceId, Target: $selectedTargetPlaceId');
    } catch (e) {
      print('Failed to load wishlist data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wishlist data: $e')),
      );
    }
  }

  Future<void> _fetchNearbyAttractions(List<LatLng> waypoints) async {
    try {
      setState(() {
        nearbyAttractions = [];
      });
      final seenPlaceIds = <String>{};
      final attractions = <Map<String, dynamic>>[];

      for (final waypoint in waypoints) {
        final response = await http.get(
          Uri.parse(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${waypoint.latitude},${waypoint.longitude}'
            '&radius=5000&type=tourist_attraction&key=$googleApiKey',
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK') {
            for (var result in data['results']) {
              final placeId = result['place_id'] as String?;
              if (placeId == null || seenPlaceIds.contains(placeId)) continue;
              seenPlaceIds.add(placeId);
              attractions.add({
                'placeId': placeId,
                'name': result['name'] as String? ?? 'Unknown Attraction',
                'latitude': result['geometry']['location']['lat'] as double?,
                'longitude': result['geometry']['location']['lng'] as double?,
                'rating': result['rating']?.toDouble() ?? 0.0,
              });
            }
          } else {
            print('Nearby search API error: ${data['status']}');
          }
        } else {
          print('Nearby search HTTP error: ${response.statusCode}');
        }
      }

      setState(() {
        nearbyAttractions = attractions;
      });
      print('Fetched ${nearbyAttractions.length} nearby attractions');
    } catch (e) {
      print('Error fetching nearby attractions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch nearby attractions: $e')),
      );
    }
  }

  Future<List<LatLng>> _getDirections(List<LatLng> waypoints) async {
    final polylinePoints = PolylinePoints();
    List<LatLng> allPoints = [];

    for (int i = 0; i < waypoints.length - 1; i++) {
      final origin = waypoints[i];
      final destination = waypoints[i + 1];

      final result = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$googleApiKey',
        ),
      );

      if (result.statusCode == 200) {
        final data = jsonDecode(result.body);
        if (data['status'] == 'OK') {
          final encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          final points = polylinePoints.decodePolyline(encodedPolyline);
          allPoints.addAll(points.map((point) => LatLng(point.latitude, point.longitude)));
          print('Fetched directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}: ${points.length} points');
        } else {
          print('Directions API error: ${data['status']}');
          throw Exception('Directions API error: ${data['status']}');
        }
      } else {
        print('Directions API HTTP error: ${result.statusCode}');
        throw Exception('Directions API HTTP error: ${result.statusCode}');
      }
    }

    return allPoints;
  }

  Future<void> _calculateRoute() async {
    try {
      print('Starting route calculation...');
      if (wishlistItems.length < 2) {
        print('Error: Less than 2 locations in wishlist');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least two locations are required for route optimization')),
        );
        return;
      }

      final timeLimitText = _timeConstraintController.text;
      final timeLimitHours = double.tryParse(timeLimitText);
      if (timeLimitHours == null || timeLimitHours <= 0) {
        print('Error: Invalid time constraint: $timeLimitText');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid time constraint (in hours)')),
        );
        return;
      }
      final timeLimitMinutes = timeLimitHours * 60;

      if (selectedStartPlaceId == null || selectedTargetPlaceId == null) {
        print('Error: Start or target not selected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and target locations')),
        );
        return;
      }

      if (selectedStartPlaceId == selectedTargetPlaceId) {
        print('Error: Start and target are the same: $selectedStartPlaceId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start and target locations must be different')),
        );
        return;
      }

      final startIndex = wishlistItems.indexWhere((item) => item['placeId'] == selectedStartPlaceId || item['placeName'] == selectedStartPlaceId);
      final targetIndex = wishlistItems.indexWhere((item) => item['placeId'] == selectedTargetPlaceId || item['placeName'] == selectedTargetPlaceId);

      if (startIndex == -1 || targetIndex == -1) {
        print('Error: Invalid start or target index. Start: $startIndex, Target: $targetIndex');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid start or target location')),
        );
        return;
      }

      final locations = wishlistItems
          .asMap()
          .entries
          .where((entry) => entry.value['latitude'] != null && entry.value['longitude'] != null)
          .map((entry) => {
                'lat': entry.value['latitude'] as double,
                'lng': entry.value['longitude'] as double,
              })
          .toList();

      // Ensure switch_weights and scores match locations length
      final switchWeights = wishlistItems
          .asMap()
          .entries
          .where((entry) => entry.value['latitude'] != null && entry.value['longitude'] != null)
          .map((entry) => entry.value['switchWeight'] as double? ?? 1.0)
          .toList();

      final ratings = wishlistItems
          .asMap()
          .entries
          .where((entry) => entry.value['latitude'] != null && entry.value['longitude'] != null)
          .map((entry) => entry.value['rating'] as double? ?? 0.0)
          .toList();

      final payload = {
        'locations': locations,
        'start': startIndex,
        'target': targetIndex,
        'time_limit': timeLimitMinutes,
        'switch_weights': switchWeights.isNotEmpty ? switchWeights : List.filled(locations.length, 1.0),
        'scores': ratings.isNotEmpty ? ratings : List.filled(locations.length, 0.0),
        'algorithm': algorithmMapping[selectedOption] ?? 'max_nodes',
      };

      print('Sending payload to backend: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('http://localhost:8000/optimize_route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = List<int>.from(data['route']);
        if (route.isEmpty) {
          print('Error: No valid route returned from backend');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid route found')),
          );
          return;
        }

        print('Route received: $route');

        final waypoints = route.map((index) {
          final item = wishlistItems[index];
          return LatLng(item['latitude'] as double, item['longitude'] as double);
        }).toList();

        await _fetchNearbyAttractions(waypoints);

        List<LatLng> polylinePoints;
        if (_useRealRoutes) {
          setState(() {
            _polylines = {};
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fetching real route...')),
          );
          polylinePoints = await _getDirections(waypoints);
        } else {
          polylinePoints = waypoints;
        }

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylinePoints,
              color: Colors.blue,
              width: 5,
            ),
          };
        });

        if (polylinePoints.isNotEmpty) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  polylinePoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
                  polylinePoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
                ),
                northeast: LatLng(
                  polylinePoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
                  polylinePoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
                ),
              ),
              100.0,
            ),
          );
        }

        print('Polyline updated with ${polylinePoints.length} points');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route calculated and displayed')),
        );
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Unknown error';
        print('Backend error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to calculate route: $error')),
        );
      }
    } catch (e) {
      print('Error in calculateRoute: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating route: $e')),
      );
    }
  }

  Future<void> _addAttractionToWishlist(Map<String, dynamic> attraction) async {
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    try {
      final lat = attraction['latitude'] as double?;
      final lng = attraction['longitude'] as double?;
      if (lat == null || lng == null) {
        print('Invalid coordinates for attraction: ${attraction['name']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates for attraction')),
        );
        return;
      }

      await MongoDataBase.insertWishlistItem(userEmail!, {
        'placeName': attraction['name'] as String? ?? 'Unknown Attraction',
        'latitude': lat,
        'longitude': lng,
        'placeId': attraction['placeId'] as String?,
        'rating': attraction['rating'] as double?,
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('Added attraction to wishlist: ${attraction['name']} for $userEmail');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${attraction['name']} to wishlist')),
      );
      await _loadWishlistData();
    } catch (e) {
      print('Error adding attraction to wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to wishlist: $e')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    print('Map created');
  }

  void _updateSelectedOption(String? value) {
    setState(() {
      selectedOption = value;
    });
    print('Selected option updated: $value');
  }

  void _updateSelectedStart(String? placeId) {
    setState(() {
      selectedStartPlaceId = placeId;
    });
    print('Selected start updated: $placeId');
  }

  void _updateSelectedTarget(String? placeId) {
    setState(() {
      selectedTargetPlaceId = placeId;
    });
    print('Selected target updated: $placeId');
  }

  void _toggleRouteType(bool value) {
    setState(() {
      _useRealRoutes = value;
    });
    print('Route type updated: ${_useRealRoutes ? "Real routes" : "Straight lines"}');
  }

  Future<void> _addMarkerFromSearch() async {
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    final city = _searchController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a place name')),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$city&key=$googleApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'OK' && json['results'].isNotEmpty) {
          final location = json['results'][0]['geometry']['location'];
          final placeName = json['results'][0]['formatted_address'] ?? city;
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;

          final marker = Marker(
            markerId: MarkerId(placeName),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: placeName,
              onTap: () => _showRemoveDialog(placeName, placeName),
            ),
            onTap: () => _showRemoveDialog(placeName, placeName),
          );

          await _addToWishlistAndMap(placeName, lat, lng, placeName);
          if (!_markers.any((m) => m.markerId.value == placeName)) {
            setState(() {
              _markers.add(marker);
            });
          }
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 12.0),
          );
          _searchController.clear();
          print('Marker added and saved to wishlist: $placeName at ($lat, $lng) for $userEmail');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Place not found. Try a different name (e.g., Colombo, LK).')),
          );
        }
      } else {
        final error = jsonDecode(response.body)['error_message'] ?? 'Unknown error';
        if (response.statusCode == 401 || response.statusCode == 403) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid Google API key. Verify at console.cloud.google.com.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch coordinates: ${response.statusCode}, $error')),
          );
        }
      }
    } catch (e) {
      print('Error adding marker from search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding marker: $e')),
      );
    }
  }

  Future<void> _addToWishlistAndMap(String name, double lat, double lng, String placeId) async {
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    try {
      await MongoDataBase.insertWishlistItem(userEmail!, {
        'placeName': name,
        'latitude': lat,
        'longitude': lng,
        'placeId': placeId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('Saved to wishlist: $name for $userEmail');
      await _loadWishlistData();
    } catch (e) {
      print('Error saving to wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to wishlist: $e')),
      );
    }
  }

  void _showRemoveDialog(String placeId, String placeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(placeName),
        content: const Text('Do you want to remove this location from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeWishlistItem(placeId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeWishlistItem(String placeId) async {
    if (userEmail == null || userId == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    try {
      await MongoDataBase.removeWishlistItem(userEmail!, placeId);
      print('Removed placeId $placeId from wishlist for $userEmail');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $placeId from wishlist')),
      );
      await _loadWishlistData();
    } catch (e) {
      print('Error removing wishlist item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item: $e')),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_isLocationPermissionGranted && _mapController != null) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0,
          ),
        );
      } catch (e) {
        print('Error getting current location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission not granted')),
      );
    }
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
        timeConstraintController: _timeConstraintController,
        onCalculate: _calculateRoute,
        wishlistItems: wishlistItems,
        selectedStartPlaceId: selectedStartPlaceId,
        selectedTargetPlaceId: selectedTargetPlaceId,
        onStartChanged: _updateSelectedStart,
        onTargetChanged: _updateSelectedTarget,
        useRealRoutes: _useRealRoutes,
        onRouteTypeChanged: _toggleRouteType,
      ),
      endDrawer: NearbyAttractionsDrawer(
        nearbyAttractions: nearbyAttractions,
        onAddToWishlist: _addAttractionToWishlist,
        onRecalculate: () {
          Navigator.pop(context);
          _calculateRoute();
        },
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
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            minMaxZoomPreference: const MinMaxZoomPreference(7.0, 15.0),
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Add to wishlist',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _addMarkerFromSearch,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _addMarkerFromSearch(),
            ),
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
          if (_isLocationPermissionGranted)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                onPressed: _goToCurrentLocation,
                backgroundColor: const Color.fromARGB(255, 241, 178, 42),
                child: const Icon(Icons.my_location),
              ),
            ),
          if (userEmail == null)
            Positioned(
              bottom: 80,
              left: 16,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage())),
                child: const Text('Sign in to manage wishlist'),
              ),
            ),
        ],
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      title: Text(
        'Plan Your Tour',
        style: const TextStyle(color: Color.fromARGB(255, 250, 250, 250), fontSize: 18, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      actions: [
        GestureDetector(
          onTap: () {
            _scaffoldKey.currentState?.openEndDrawer();
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            width: 20,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              'assets/icons/dots.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
      ],
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _timeConstraintController.dispose();
    super.dispose();
  }
}

class DrawerBar extends StatelessWidget {
  final String? selectedOption;
  final List<String> options;
  final ValueChanged<String?> onOptionChanged;
  final TextEditingController timeConstraintController;
  final VoidCallback onCalculate;
  final List<Map<String, dynamic>> wishlistItems;
  final String? selectedStartPlaceId;
  final String? selectedTargetPlaceId;
  final ValueChanged<String?> onStartChanged;
  final ValueChanged<String?> onTargetChanged;
  final bool useRealRoutes;
  final ValueChanged<bool> onRouteTypeChanged;

  const DrawerBar({
    super.key,
    required this.selectedOption,
    required this.options,
    required this.onOptionChanged,
    required this.timeConstraintController,
    required this.onCalculate,
    required this.wishlistItems,
    required this.selectedStartPlaceId,
    required this.selectedTargetPlaceId,
    required this.onStartChanged,
    required this.onTargetChanged,
    required this.useRealRoutes,
    required this.onRouteTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 240, 144, 9),
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
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Settings()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignInPage()));
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Use Real Routes:'),
                Switch(
                  value: useRealRoutes,
                  onChanged: onRouteTypeChanged,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: selectedStartPlaceId,
              decoration: const InputDecoration(
                labelText: 'Start Location',
                border: OutlineInputBorder(),
              ),
              items: wishlistItems
                  .map((item) {
                    final placeId = item['placeId'] as String? ?? (item['placeName'] as String? ?? 'Unknown Place');
                    final placeName = item['placeName'] as String? ?? 'Unknown Place';
                    return DropdownMenuItem<String>(
                      value: placeId,
                      child: Text(placeName),
                    );
                  })
                  .toList(),
              onChanged: onStartChanged,
              isExpanded: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: selectedTargetPlaceId,
              decoration: const InputDecoration(
                labelText: 'Target Location',
                border: OutlineInputBorder(),
              ),
              items: wishlistItems
                  .map((item) {
                    final placeId = item['placeId'] as String? ?? (item['placeName'] as String? ?? 'Unknown Place');
                    final placeName = item['placeName'] as String? ?? 'Unknown Place';
                    return DropdownMenuItem<String>(
                      value: placeId,
                      child: Text(placeName),
                    );
                  })
                  .toList(),
              onChanged: onTargetChanged,
              isExpanded: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: timeConstraintController,
              decoration: const InputDecoration(
                labelText: 'Time Constraint (hours)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onCalculate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Calculate'),
            ),
          ),
        ],
      ),
    );
  }
}

class NearbyAttractionsDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> nearbyAttractions;
  final Function(Map<String, dynamic>) onAddToWishlist;
  final VoidCallback onRecalculate;

  const NearbyAttractionsDrawer({
    super.key,
    required this.nearbyAttractions,
    required this.onAddToWishlist,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 240, 144, 9),
            ),
            child: const Text(
              'Nearby Attractions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          if (nearbyAttractions.isEmpty)
            const ListTile(
              title: Text('No nearby attractions found'),
              subtitle: Text('Calculate a route to find attractions'),
            ),
          ...nearbyAttractions.map((attraction) {
            return ListTile(
              title: Text(
                attraction['name'] ?? 'Unknown Attraction',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Rating: ${attraction['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => onAddToWishlist(attraction),
              ),
            );
          }).toList(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: onRecalculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Recalculate Route'),
            ),
          ),
        ],
      ),
    );
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