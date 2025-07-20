import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:app/dbHelper/constant.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class MarketItemModel {
  final String? id;
  final String name;
  final String? imageUrl;
  final String price;
  final String? description;
  final String username;
  final String userEmail;
  final String category;
  final LatLng? location;

  MarketItemModel({
    this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    required this.username,
    required this.userEmail,
    required this.category,
    this.location,
  });

  factory MarketItemModel.fromMap(Map<String, dynamic> map) {
    return MarketItemModel(
      id: map['_id'] is mongo.ObjectId ? map['_id'].toHexString() : map['_id'],
      name: map['name'] ?? '',
      price: map['price'] ?? '',
      imageUrl: map['imageUrl'],
      description: map['description'],
      username: map['username'] ?? '',
      userEmail: map['userEmail'] ?? '',
      category: map['category'] ?? 'All',
      location: map['location'] != null
          ? LatLng(map['location']['latitude'] ?? 0.0, map['location']['longitude'] ?? 0.0)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
      'username': username,
      'userEmail': userEmail,
      'category': category,
      'location': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

class MarketCategory {
  final String name;
  final String iconPath;

  MarketCategory({required this.name, required this.iconPath});

  static List<MarketCategory> getCategories() {
    return [
      MarketCategory(name: 'All', iconPath: 'assets/icons/all.svg'),
      MarketCategory(name: 'Electronics', iconPath: 'assets/icons/electronics.svg'),
      MarketCategory(name: 'Clothing', iconPath: 'assets/icons/clothing.svg'),
      MarketCategory(name: 'Furniture', iconPath: 'assets/icons/furniture.svg'),
    ];
  }
}

class Market extends StatefulWidget {
  const Market({Key? key}) : super(key: key);

  @override
  State<Market> createState() => _MarketState();
}

class _MarketState extends State<Market> {
  List<MarketCategory> categories = MarketCategory.getCategories();
  List<MarketItemModel> items = [];
  List<MarketItemModel> filteredItems = [];
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      await MongoDataBase.connect();
      final posts = await MongoDataBase.fetchMarketItems();
      setState(() {
        items = posts.map((e) => MarketItemModel.fromMap(e)).toList();
        _filterItems();
      });
    } catch (e) {
      print('Error loading market items: $e');
      setState(() {
        items = [];
        filteredItems = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load items: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.trim();
      _filterItems();
    });
  }

  void _filterItems() {
    filteredItems = items.where((item) {
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final matchesSearch = searchQuery.isEmpty ||
          item.name.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _onCategorySelected(String categoryName) {
    setState(() {
      selectedCategory = categoryName;
      _filterItems();
    });
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(
        onItemAdded: _loadItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _appBar(),
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchField(),
            const SizedBox(height: 20),
            _categoriesSection(),
            isLoading
                ? _loadingIndicator()
                : filteredItems.isEmpty
                    ? const Center(child: Text('No items found.'))
                    : _itemsGrid(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        child: const Icon(Icons.add),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      title: const Text(
        'Marketplace',
        style: TextStyle(color: Colors.black, fontSize: 20),
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/icons/Arrow - Left 2.svg',
            width: 20,
            height: 20,
          ),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 240, 144, 9),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: SvgPicture.asset(
            'assets/icons/dots.svg',
            width: 24,
            height: 24,
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
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
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(15),
          hintText: 'Search Marketplace',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset('assets/icons/Search.svg'),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                ),
              const VerticalDivider(
                color: Colors.black,
                indent: 10,
                endIndent: 10,
                thickness: 0.1,
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset('assets/icons/Filter.svg'),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => _onSearchChanged(),
      ),
    );
  }

  Widget _categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'Categories',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category.name;
              return GestureDetector(
                onTap: () => _onCategorySelected(category.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        category.iconPath,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          isSelected ? Colors.blue : Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.name,
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _loadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _itemsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketItemDetailPage(
                    itemId: item.id!,
                    name: item.name,
                    imageUrl: item.imageUrl,
                    price: item.price,
                    description: item.description,
                    username: item.username,
                    userEmail: item.userEmail,
                    category: item.category,
                    location: item.location,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.price,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: ${item.username}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 240, 144, 9),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ongoing Chats',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No ongoing chats.'));
                }
                final conversations = snapshot.data!;
                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final sellerEmail = conversation['sellerEmail'];
                    final itemName = conversation['itemName'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          sellerEmail[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      title: Text(
                        sellerEmail,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Item: $itemName'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatWithSeller(
                              sellerEmail: sellerEmail,
                              itemName: itemName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchConversations() async {
    try {
      await MongoDataBase.connectToChats();
      final currentUserEmail = 'k.m.navoddilshan@gmail.com';
      final sellerEmail = "";
      final messages = await MongoDataBase.fetchChatMessages(currentUserEmail, sellerEmail);
      final conversations = <Map<String, dynamic>>[];
      final seenConversations = <String>{};

      for (var message in messages) {
        final sender = message['sender'] as String;
        final receiver = message['receiver'] as String;
        final otherUser = sender == currentUserEmail ? receiver : sender;
        final itemName = message['text']?.toString().split('about ').last ?? 'Unknown Item';
        final conversationKey = '$otherUser-$itemName';

        if (!seenConversations.contains(conversationKey)) {
          conversations.add({
            'sellerEmail': otherUser,
            'itemName': itemName,
          });
          seenConversations.add(conversationKey);
        }
      }
      return conversations;
    } catch (e) {
      print('Error fetching conversations: $e');
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class LocationPickerDialog extends StatefulWidget {
  final VoidCallback onItemAdded;

  const LocationPickerDialog({Key? key, required this.onItemAdded}) : super(key: key);

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = 'Electronics';
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  bool _isLocationPermissionGranted = false;
  static const LatLng _sriLankaCenter = LatLng(7.8731, 80.7718);
  static LatLngBounds _sriLankaBounds = LatLngBounds(
    southwest: LatLng(5.9167, 79.6522),
    northeast: LatLng(9.8350, 81.8815),
  );
  static const String googleApiKey = 'AIzaSyCSHjnVgYUxWctnEfeH3S3501J-j0iYZU0';
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
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
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _addMarker(Prediction prediction) {
    if (prediction.lat != null && prediction.lng != null) {
      final lat = double.tryParse(prediction.lat!);
      final lng = double.tryParse(prediction.lng!);
      if (lat != null && lng != null) {
        setState(() {
          _selectedLocation = LatLng(lat, lng);
          _markers = {
            Marker(
              markerId: MarkerId(prediction.placeId ?? prediction.description ?? 'selected_location'),
              position: _selectedLocation!,
              infoWindow: InfoWindow(title: prediction.description ?? 'Selected Location'),
            ),
          };
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Market Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(labelText: 'Image URL (optional)'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 3,
            ),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: MarketCategory.getCategories()
                  .where((cat) => cat.name != 'All')
                  .map((cat) => DropdownMenuItem(
                        value: cat.name,
                        child: Text(cat.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value ?? 'Electronics';
                });
              },
            ),
            const SizedBox(height: 10),
            GooglePlaceAutoCompleteTextField(
              textEditingController: _searchController,
              googleAPIKey: googleApiKey,
              countries: ['LK'],
              getPlaceDetailWithLatLng: _addMarker,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: _sriLankaCenter,
                  zoom: 7.5,
                ),
                cameraTargetBounds: CameraTargetBounds(_sriLankaBounds),
                myLocationEnabled: _isLocationPermissionGranted,
                myLocationButtonEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(7.0, 15.0),
                markers: _markers,
                onTap: (LatLng location) {
                  setState(() {
                    _selectedLocation = location;
                    _markers = {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: location,
                        infoWindow: const InfoWindow(title: 'Selected Location'),
                      ),
                    };
                  });
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(location, 15.0),
                  );
                },
              ),
            ),
            if (!_isLocationPermissionGranted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: _checkAndRequestLocationPermission,
                  child: const Text('Enable Location'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty && _priceController.text.isNotEmpty) {
              final newItem = MarketItemModel(
                name: _nameController.text,
                price: _priceController.text,
                imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                username: 'Navod',
                userEmail: 'k.m.navoddilshan@gmail.com',
                category: selectedCategory,
                location: _selectedLocation,
              );
              try {
                await MongoDataBase.connect();
                await MongoDataBase.insertMarketItem(newItem.toMap());
                Navigator.pop(context);
                widget.onItemAdded();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding item: $e')),
                );
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class MarketItemDetailPage extends StatelessWidget {
  final String itemId;
  final String name;
  final String? imageUrl;
  final String price;
  final String? description;
  final String username;
  final String userEmail;
  final String category;
  final LatLng? location;

  const MarketItemDetailPage({
    Key? key,
    required this.itemId,
    required this.name,
    this.imageUrl,
    required this.price,
    this.description,
    required this.username,
    required this.userEmail,
    required this.category,
    this.location,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> reportReasons = [
      'Inappropriate content',
      'Spam or scam',
      'Misleading information',
      'Other',
    ];

    void showReportDialog() {
      String? selectedReason;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a reason for reporting:'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Reason'),
                value: selectedReason,
                items: reportReasons
                    .map((reason) => DropdownMenuItem(value: reason, child: Text(reason)))
                    .toList(),
                onChanged: (value) => selectedReason = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedReason != null) {
                  try {
                    await MongoDataBase.connectToReports();
                    await MongoDataBase.insertReport({
                      'itemId': itemId,
                      'itemName': name,
                      'sellerEmail': userEmail,
                      'reporterEmail': 'k.m.navoddilshan@gmail.com',
                      'reason': selectedReason,
                      'createdAt': DateTime.now().toIso8601String(),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error submitting report: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a reason')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icons/Arrow - Left 2.svg',
              width: 20,
              height: 20,
            ),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageUrl != null
                ? Image.network(
                    imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatWithSeller(
                                sellerEmail: userEmail,
                                itemName: name,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Chat with the Seller'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By: $username',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact: $userEmail',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: $category',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Location: ${location!.latitude}, ${location!.longitude}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    description ?? 'No description available',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (location != null)
              SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: location!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('item-location'),
                      position: location!,
                      infoWindow: InfoWindow(title: name),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  minMaxZoomPreference: const MinMaxZoomPreference(7.0, 15.0),
                  cameraTargetBounds: CameraTargetBounds(
                    LatLngBounds(
                      southwest: const LatLng(5.9167, 79.6522),
                      northeast: const LatLng(9.8350, 81.8815),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: showReportDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Report Seller'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatWithSeller extends StatefulWidget {
  final String sellerEmail;
  final String itemName;

  const ChatWithSeller({
    Key? key,
    required this.sellerEmail,
    required this.itemName,
  }) : super(key: key);

  @override
  State<ChatWithSeller> createState() => _ChatWithSellerState();
}

class _ChatWithSellerState extends State<ChatWithSeller> {
  final String currentUserEmail = 'k.m.navoddilshan@gmail.com';
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  Timer? _pollingTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _startPolling();
  }

  Future<void> _initializeChat() async {
    setState(() {
      isLoading = true;
    });
    try {
      await MongoDataBase.connectToChats();
      await _loadMessages();
    } catch (e) {
      print('Error initializing chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize chat: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final fetchedMessages = await MongoDataBase.fetchChatMessages(
        currentUserEmail,
        widget.sellerEmail,
      );
      setState(() {
        messages = fetchedMessages;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: $e')),
      );
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await _loadMessages();
      } catch (e) {
        print('Error polling messages: $e');
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await MongoDataBase.connectToChats();
      await MongoDataBase.insertChatMessage(
        currentUserEmail,
        widget.sellerEmail,
        {
          'text': _messageController.text.trim(),
          'sender': currentUserEmail,
          'receiver': widget.sellerEmail,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat about ${widget.itemName}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icons/Arrow - Left 2.svg',
              width: 20,
              height: 20,
            ),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 240, 144, 9),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isCurrentUser = message['sender'] == currentUserEmail;
                          return Align(
                            alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? const Color.fromARGB(255, 240, 144, 9)
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'] ?? '',
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.white : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    DateFormat('hh:mm a').format(
                                      DateTime.parse(message['createdAt'] ?? DateTime.now().toIso8601String()),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Color.fromARGB(255, 240, 144, 9)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}