import 'package:flutter/material.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:app/services/auth_service.dart';
import 'dart:async';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final _locationSearchController = TextEditingController();
  LatLng? _selectedLocation;
  String? _locationName;
  GoogleMapController? _mapController;
  bool _isLoadingLocation = false;
  bool _isSearchingLocation = false;
  bool _showLocationSearch = false;
  String? userEmail;
  String? username;
  String? userId;
  
  // Image upload related variables
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;
  final ImagePicker _picker = ImagePicker();
  
  // Location search related variables
  List<Location> _searchResults = [];
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getUserInfo();
    setState(() {
      userEmail = userInfo['userEmail'];
      username = userInfo['username'];
      userId = userInfo['userId'];
    });
  }

  // Location search functionality
  void _onSearchChanged(String query) {
    if (_searchTimer != null) {
      _searchTimer!.cancel();
    }
    
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchLocation(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() {
      _isSearchingLocation = true;
    });
    
    try {
      List<Location> locations = await locationFromAddress(query);
      setState(() {
        _searchResults = locations.take(5).toList(); // Limit to 5 results
        _isSearchingLocation = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearchingLocation = false;
      });
      print('Error searching location: $e');
    }
  }

  Future<void> _selectSearchedLocation(Location location) async {
    LatLng selectedLocation = LatLng(location.latitude, location.longitude);
    
    setState(() {
      _selectedLocation = selectedLocation;
      _showLocationSearch = false;
      _searchResults = [];
      _locationSearchController.clear();
    });
    
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(selectedLocation, 15),
      );
    }
    
    await _getLocationName(selectedLocation);
  }

  void _toggleLocationSearch() {
    setState(() {
      _showLocationSearch = !_showLocationSearch;
      if (!_showLocationSearch) {
        _locationSearchController.clear();
        _searchResults = [];
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening image picker: $e')),
        );
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File image) async {
  try {
    setState(() {
      _isUploadingImage = true;
    });

    developer.log("something");

    // Replace with your backend URL
    const String backendUrl = 'http://localhost:3000'; // Update this
    
    // First, prepare the upload
    final prepareResponse = await http.post(
      Uri.parse('$backendUrl/api/prepare-upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'files': [
          {
            'name': image.path.split('/').last,
            'size': await image.length(),
            'customId': null,
          }
        ],
        'routeConfig': ['image'], // Adjust based on your backend config
        'metadata': null,
        'callbackUrl': 'http://example.com/callback', // Optional, adjust as needed
        'callbackSlug': 'upload-callback', // Optional, adjust as needed
      }),
    );

    if (prepareResponse.statusCode != 200) {
      throw Exception('Failed to prepare upload: ${prepareResponse.body}');
    }


    final prepareData = jsonDecode(prepareResponse.body);
    
    
    // Add null checks and better error handling
    if (prepareData[0] == null || prepareData[0].isEmpty) {
      throw Exception('Invalid response from upload service');
    }

    developer.log("something2");


    
    final uploadData = prepareData[0];
    
    // Validate required fields
    if (uploadData['url'] == null) {
      throw Exception('Upload URL not provided');
    }

    
    
    // Upload the file to UploadThing
    final uploadRequest = http.MultipartRequest('POST', Uri.parse(uploadData['url']));

    
    // Handle form fields properly - check if it's a Map or List
    if (uploadData['fields'] != null) {
      final fields = uploadData['fields'];

      developer.log('Upload fields: $fields');

      
      if (fields is Map<String, dynamic>) {
        // If it's a Map, iterate over entries
        fields.forEach((key, value) {
          uploadRequest.fields[key] = value.toString();
        });
      } else if (fields is List) {
        // If it's a List, handle accordingly
        for (var field in fields) {
          if (field is Map<String, dynamic>) {
            field.forEach((key, value) {
              uploadRequest.fields[key] = value.toString();
            });
          }
        }
      }
    }
    
    // Add the file
    uploadRequest.files.add(
      await http.MultipartFile.fromPath('file', image.path),
    );

    final uploadResponse = await uploadRequest.send();
    final responseBody = await uploadResponse.stream.bytesToString();
    
    print('Upload response status: ${uploadResponse.statusCode}');
    print('Upload response body: $responseBody');
    
    if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201 || uploadResponse.statusCode == 204) {
      // Parse the response to get the actual file URL
      try {

        return uploadData['fileUrl']; // Return the URL directly from uploadData
        
        // This depends on your UploadThing configuration
        // // Common patterns:
        // if (responseData is List && responseData.isNotEmpty) {
        //   return responseData[0]['url']; // If response is an array
        // } else if (responseData is Map && responseData['url'] != null) {
        //   return responseData['url']; // If response is an object with url
        // } else {
        //   // Fallback - construct URL from key
        //   final key = uploadData['key'] ?? uploadData['fields']?['key'];
        //   if (key != null) {
        //     return uploadData['url'].replaceAll('/upload', '/$key');
        //   }
        // }
      } catch (parseError) {
        print('Error parsing upload response: $parseError');
        // Fallback URL construction
        final key = uploadData['key'] ?? uploadData['fields']?['key'];
        if (key != null) {
          return uploadData['url'].replaceAll('/upload', '/$key');
        }
      }
      
      throw Exception('Could not determine file URL from response');
    } else {
      throw Exception('Upload failed with status ${uploadResponse.statusCode}: $responseBody');
    }
  } catch (e) {
    print('Upload error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    }
    return null;
  } finally {
    setState(() {
      _isUploadingImage = false;
    });
  }
}

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition();
      LatLng newLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = newLocation;
        _isLoadingLocation = false;
      });
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, 15),
        );
      }
      
      _getLocationName(newLocation);
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _getLocationName(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _locationName = '${place.locality ?? place.subAdministrativeArea ?? 'Unknown'}, ${place.country ?? 'Unknown'}';
        });
      }
    } catch (e) {
      print('Error getting location name: $e');
      setState(() {
        _locationName = 'Location selected';
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _getLocationName(location);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _removeLocation() {
    setState(() {
      _selectedLocation = null;
      _locationName = null;
      _showLocationSearch = false;
      _locationSearchController.clear();
      _searchResults = [];
    });
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    _locationSearchController.dispose();
    _mapController?.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        actions: [
          TextButton(
            onPressed: _isUploadingImage ? null : () async {
              final content = _contentController.text.trim();
              if (content.isNotEmpty) {
                try {
                  String? imageUrl;
                  
                  // Upload image if selected
                  if (_selectedImage != null) {
                    imageUrl = await _uploadImage(_selectedImage!);
                    if (imageUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Image upload failed. Please try again.")),
                      );
                      return;
                    }
                  }
                  
                  await MongoDataBase.insertPost({
                    'userName': username ?? 'Anonymous',
                    'userAvatar': 'assets/images/user1.png',
                    'timeAgo': 'Just now',
                    'content': content,
                    'imagePath': imageUrl,
                    'likes': 0,
                    'comments': 0,
                    'shares': 0,
                    'likedBy': [],
                    'createdAt': DateTime.now().toIso8601String(),
                    'location': _locationName,
                    'latitude': _selectedLocation?.latitude,
                    'longitude': _selectedLocation?.longitude,
                    'commentsList': [],
                    'valid':'true',
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Post created successfully")),
                    );
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error creating post: $e")),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter some content")),
                );
              }
            },
            child: _isUploadingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            
            // Image section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo),
                    title: Text(_selectedImage != null ? 'Image selected' : 'Add photo'),
                    subtitle: _selectedImage != null ? const Text('Tap to change image') : null,
                    trailing: _selectedImage != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _removeImage,
                          )
                        : null,
                    onTap: _pickImage,
                  ),
                  
                  if (_selectedImage != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Location section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: _isLoadingLocation 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_on),
                    title: Text(_locationName ?? 'Add location'),
                    subtitle: _selectedLocation != null 
                        ? const Text('Tap on map to change location')
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedLocation == null)
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _toggleLocationSearch,
                            tooltip: 'Search location',
                          ),
                        if (_selectedLocation != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _removeLocation,
                          ),
                      ],
                    ),
                    onTap: _selectedLocation == null && !_showLocationSearch ? _getCurrentLocation : null,
                  ),
                  
                  // Location search field
                  if (_showLocationSearch)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _locationSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search for a location...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _isSearchingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: _toggleLocationSearch,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                          
                          // Search results
                          if (_searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _searchResults.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final location = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.place, size: 20),
                                    title: FutureBuilder<List<Placemark>>(
                                      future: placemarkFromCoordinates(
                                        location.latitude, 
                                        location.longitude
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                          final place = snapshot.data![0];
                                          return Text(
                                            '${place.name ?? place.locality ?? 'Unknown'}, ${place.country ?? 'Unknown'}',
                                            style: const TextStyle(fontSize: 14),
                                          );
                                        }
                                        return Text(
                                          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 14),
                                        );
                                      },
                                    ),
                                    subtitle: Text(
                                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    onTap: () => _selectSearchedLocation(location),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  
                  if (_selectedLocation != null) 
                    Container(
                      height: 200,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation!,
                            zoom: 15,
                          ),
                          onTap: _onMapTap,
                          markers: {
                            Marker(
                              markerId: const MarkerId('selected_location'),
                              position: _selectedLocation!,
                              infoWindow: InfoWindow(
                                title: 'Selected Location',
                                snippet: _locationName ?? 'Tap to change',
                              ),
                            ),
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                  
                  if (_selectedLocation == null && !_showLocationSearch)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _getCurrentLocation,
                                  icon: const Icon(Icons.my_location),
                                  label: const Text('Current Location'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                              onPressed: () {
                                LatLng defaultLocation = const LatLng(37.7749, -122.4194);
                                setState(() {
                                  _selectedLocation = defaultLocation;
                                });
                                _getLocationName(defaultLocation);
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Choose on Map'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                              ),
                            ],
                          ),
                          
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const Spacer(),
            
            if (_selectedLocation != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap anywhere on the map to move the location pin',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}