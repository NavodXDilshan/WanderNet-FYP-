import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class Planner extends StatefulWidget {
  const Planner({super.key});

  @override
  _PlannerState createState() => _PlannerState();
}

class _PlannerState extends State<Planner> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(37.7749, -122.4194); // Default: San Francisco
  bool _isLocationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      setState(() {
        _isLocationPermissionGranted = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 12.0,
        ),
        myLocationEnabled: _isLocationPermissionGranted,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}