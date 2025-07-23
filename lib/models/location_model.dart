import 'dart:ffi';

class LocationModel {
  final String location;
  final double latitude;
  final double longitude;

  LocationModel({
    required this.location,
    required this.latitude,
    required this.longitude,
  });
}