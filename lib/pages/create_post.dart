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

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  LatLng? _selectedLocation;
  String? _locationName;
  GoogleMapController? _mapController;
  bool _isLoadingLocation = false;
  
  // Image upload related variables
  File? _selectedImage;
  bool _isUploadingImage = false;
  String? _uploadedImageUrl;
  final ImagePicker _picker = ImagePicker();

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
    const String backendUrl = 'http://10.0.2.2:3000'; // Update this
    
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
    });
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    _mapController?.dispose();
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
                    'userName': 'Navod Dilshan',
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
                    trailing: _selectedLocation != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _removeLocation,
                          )
                        : null,
                    onTap: _selectedLocation == null ? _getCurrentLocation : null,
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
                  
                  if (_selectedLocation == null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Current Location'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              LatLng defaultLocation = const LatLng(37.7749, -122.4194);
                              setState(() {
                                _selectedLocation = defaultLocation;
                              });
                              _getLocationName(defaultLocation);
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Choose on Map'),
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