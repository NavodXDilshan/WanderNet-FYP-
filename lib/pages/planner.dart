import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../dbHelper/mongodb.dart';
import 'settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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
  final String userEmail = 'k.m.navoddilshan@gmail.com';
  String? selectedOption = 'Max Node';
  String? selectedStartPlaceId; // Use placeId for uniqueness
  String? selectedTargetPlaceId; // Use placeId for uniqueness
  List<Map<String, dynamic>> wishlistItems = [];
  final List<String> options = ['Max Node', 'Max Rating', 'Hybrid'];
  static const String googleApiKey = 'AIzaSyCSHjnVgYUxWctnEfeH3S3501J-j0iYZU0';
  bool _useRealRoutes = true; // Toggle for real routes vs straight lines

  // Map UI options to backend algorithm names
  final Map<String, String> algorithmMapping = {
    'Max Node': 'max_nodes',
    'Max Rating': 'max_score',
    'Hybrid': 'hybrid',
  };

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
    _loadWishlistData();
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
    try {
      final items = await MongoDataBase.fetchWishlistItems(userEmail);
      print('Loaded wishlist items: ${items.length}');
      // Deduplicate by placeId
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
        );
      }).whereType<Marker>().toSet();

      setState(() {
        wishlistItems = uniqueItems;
        _markers = newMarkers;
        if (wishlistItems.isNotEmpty) {
          selectedStartPlaceId = wishlistItems[0]['placeId'] as String? ?? wishlistItems[0]['placeName'] as String? ?? 'Unknown Place';
          selectedTargetPlaceId = wishlistItems.length > 1
              ? (wishlistItems[1]['placeId'] as String? ?? wishlistItems[1]['placeName'] as String? ?? 'Unknown Place')
              : selectedStartPlaceId;
        }
      });
      print('Markers updated: ${_markers.length}, Start: $selectedStartPlaceId, Target: $selectedTargetPlaceId');
      print('Wishlist items: ${wishlistItems.map((item) => {'placeId': item['placeId'], 'placeName': item['placeName']})}');
    } catch (e) {
      print('Failed to load wishlist data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wishlist data: $e')),
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
      print('Time constraint: $timeLimitHours hours ($timeLimitMinutes minutes)');

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

      final startIndex = wishlistItems.indexWhere((item) => item['placeId'] == selectedStartPlaceId);
      final targetIndex = wishlistItems.indexWhere((item) => item['placeId'] == selectedTargetPlaceId);

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
          .where((entry) {
            final item = entry.value;
            return item['latitude'] != null && item['longitude'] != null;
          })
          .map((entry) => {
                'lat': entry.value['latitude'] as double,
                'lng': entry.value['longitude'] as double,
              })
          .toList();

      final switchWeights = wishlistItems
          .asMap()
          .entries
          .where((entry) => entry.value['switchWeight'] != null)
          .map((entry) => entry.value['switchWeight'] as double)
          .toList();

      final ratings = wishlistItems
          .asMap()
          .entries
          .where((entry) => entry.value['rating'] != null)
          .map((entry) => entry.value['rating'] as double)
          .toList();

      final payload = {
        'locations': locations,
        'start': startIndex,
        'target': targetIndex,
        'time_limit': timeLimitMinutes,
        'switch_weights': switchWeights.isNotEmpty ? switchWeights : null,
        'scores': ratings.isNotEmpty ? ratings : null,
        'algorithm': algorithmMapping[selectedOption] ?? 'max_nodes',
      };

      print('Sending payload to backend: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('http://192.168.1.3:8000/optimize_route'),
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
          polylinePoints = waypoints; // Straight lines
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

  void _addMarker(Prediction prediction) async {
    try {
      if (prediction.lat != null && prediction.lng != null) {
        final lat = double.tryParse(prediction.lat!);
        final lng = double.tryParse(prediction.lng!);
        if (lat != null && lng != null) {
          final marker = Marker(
            markerId: MarkerId(prediction.placeId ?? prediction.description ?? 'search_marker'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: prediction.description ?? 'Unknown Place',
              onTap: () => _saveToWishlist(prediction),
            ),
          );
          setState(() {
            _markers = {..._markers, marker};
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 12.0),
          );
          print('Marker added: ${prediction.description} at ($lat, $lng)');
        } else {
          print('Invalid coordinates for marker: ${prediction.description}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid coordinates for selected place')),
          );
        }
      } else {
        print('No coordinates for marker: ${prediction.description}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coordinates available for selected place')),
        );
      }
    } catch (e) {
      print('Error adding marker: $e');
    }
  }

  Future<void> _saveToWishlist(Prediction prediction) async {
    try {
      if (prediction.lat != null && prediction.lng != null) {
        final lat = double.tryParse(prediction.lat!);
        final lng = double.tryParse(prediction.lng!);
        if (lat != null && lng != null) {
          await MongoDataBase.insertWishlistItem(userEmail, {
            'placeName': prediction.description ?? 'Unknown Place',
            'latitude': lat,
            'longitude': lng,
            'placeId': prediction.placeId,
            'createdAt': DateTime.now().toIso8601String(),
          });
          print('Saved to wishlist: ${prediction.description}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${prediction.description} to wishlist')),
          );
          _loadWishlistData();
        } else {
          print('Invalid coordinates for wishlist: ${prediction.description}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid coordinates for wishlist')),
          );
        }
      } else {
        print('No coordinates for wishlist: ${prediction.description}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coordinates available for wishlist')),
        );
      }
    } catch (e) {
      print('Error saving to wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to wishlist: $e')),
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
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: _searchController,
              googleAPIKey: googleApiKey,
              countries: ['LK'],
              getPlaceDetailWithLatLng: _addMarker,
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
        icon: const Icon(Icons.menu),
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
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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