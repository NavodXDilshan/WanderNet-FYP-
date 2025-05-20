import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../dbHelper/mongodb.dart';


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
  final TextEditingController _searchController = TextEditingController();
  final String userEmail = 'k.m.navoddilshan@gmail.com';
  String? selectedOption = 'Max Node';
  final List<String> options = ['Max Node', 'Max Rating', 'Hybrid'];
  static const String googleApiKey = 'AIzaSyCSHjnVgYUxWctnEfeH3S3501J-j0iYZU0';

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
  }

  void _updateSelectedOption(String? value) {
    setState(() {
      selectedOption = value;
    });
  }

  void _addMarker(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      final lat = double.tryParse(prediction.lat!);
      final lng = double.tryParse(prediction.lng!);
      if (lat != null && lng != null) {
        final marker = Marker(
          markerId: MarkerId(prediction.placeId ?? prediction.description ?? ''),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: prediction.description ?? 'Unknown Place',
            onTap: () => _saveToWishlist(prediction),
          ),
        );
        setState(() {
          _markers = {marker};
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 12.0),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates for selected place')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates available for selected place')),
      );
    }
  }

  Future<void> _saveToWishlist(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      final lat = double.tryParse(prediction.lat!);
      final lng = double.tryParse(prediction.lng!);
      if (lat != null && lng != null) {
        try {
          await MongoDataBase.insertWishlistItem(userEmail, {
            'placeName': prediction.description ?? 'Unknown Place',
            'latitude': lat,
            'longitude': lng,
            'placeId': prediction.placeId,
            'createdAt': DateTime.now().toIso8601String(),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${prediction.description} to wishlist')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add to wishlist: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates for wishlist')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates available for wishlist')),
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
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: _searchController,
              googleAPIKey: googleApiKey,
              // hintText: 'Search for a place',
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
            title: const Text('Setting'),
            onTap: () {
              Navigator.pop(context);
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
        ],
      ),
    );
  }
}