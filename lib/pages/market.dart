import 'package:app/pages/chatbot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../dbHelper/mongodb.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'marketItemPage.dart';
import 'marketChat.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;

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
      if (supabase.auth.currentSession?.isExpired ?? true) {
        await supabase.auth.refreshSession();
      }
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? user.email ?? 'Guest',
        'userId': user.id,
      };
    } catch (e) {
      print('Error refreshing session or fetching user info: $e');
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? user.email ?? 'Guest',
        'userId': user.id,
      };
    }
  }
}

class MarketItemModel {
  final String? id;
  final String name;
  final String? imageUrl;
  final String price;
  final String? description;
  final String username;
  final String userEmail;
  final String userId;
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
    required this.userId,
    required this.category,
    this.location,
  });

  factory MarketItemModel.fromMap(Map<String, dynamic> map) {
    return MarketItemModel(
      id: map['_id'] is mongo.ObjectId ? map['_id'].toHexString() : map['_id']?.toString(),
      name: map['name']?.toString() ?? '',
      price: map['price']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      description: map['description']?.toString(),
      username: map['username']?.toString() ?? 'Guest',
      userEmail: map['userEmail']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      category: map['category']?.toString() ?? 'All',
      location: map['location'] != null
          ? LatLng(
              (map['location']['latitude'] as num?)?.toDouble() ?? 0.0,
              (map['location']['longitude'] as num?)?.toDouble() ?? 0.0,
            )
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
      'userId': userId,
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
      MarketCategory(name: 'All', iconPath: 'assets/icons/all.png'),
      MarketCategory(name: 'Electronics', iconPath: 'assets/icons/electronics.png'),
      MarketCategory(name: 'Clothing', iconPath: 'assets/icons/clothing.png'),
      MarketCategory(name: 'Furniture', iconPath: 'assets/icons/furniture.png'),
      MarketCategory(name: 'Food', iconPath: 'assets/icons/food.png'),
      MarketCategory(name: 'Other', iconPath: 'assets/icons/other.png'),
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
  String? userEmail;
  String? username;
  String? userId;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  bool _isRefreshingChats = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadItems();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getUserInfo();
    setState(() {
      userEmail = userInfo['userEmail'];
      username = userInfo['username'];
      userId = userInfo['userId'];
    });
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      await MongoDataBase.connectToChats(); // Ensure connection
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
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load items: $e')),
        );
      });
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
    if (userEmail == null || userId == null || username == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => LocationPickerDialog(
        onItemAdded: _loadItems,
        userEmail: userEmail!,
        username: username!,
        userId: userId!,
      ),
    );
  }

  Future<void> _refreshConversations() async {
    setState(() {
      _isRefreshingChats = true;
    });
    try {
      await _loadUserInfo();
      setState(() {}); // Trigger rebuild to re-run _fetchConversations
      _refreshController.refreshCompleted();
    } catch (e) {
      print('Error refreshing conversations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh chats: $e')),
      );
    } finally {
      setState(() {
        _isRefreshingChats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _appBar(),
      backgroundColor: Colors.white,
      endDrawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchField(),
            const SizedBox(height: 30),
            _categoriesSection(),
            isLoading
                ? _loadingIndicator()
                : filteredItems.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(50.0),
                          child: const Text('No items found.'),
                        ),
                      )
                    : _itemsGrid(),
          ],
        ),
      ),
floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
      FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatbotPage(),
            ),
          );
        },
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        heroTag: 'chatbot',
                child: const Icon(
          Icons.chat_bubble,
          color: Color.fromARGB(255, 248, 248, 248),
        ),
      ),
    const SizedBox(height: 16), // spacing between FABs
    FloatingActionButton(
      heroTag: "btn2",
      onPressed: _showAddItemDialog,
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      child: const Icon(Icons.add),
    ),
  ],
),

    );
  }

  AppBar _appBar() {
    return AppBar(
      title: const Text(
        'Marketplace',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 240, 144, 9),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          icon: SvgPicture.asset(
            'assets/icons/dots.svg',
            width: 8,
            height: 8,
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
                      Image.asset(
                        category.iconPath,
                        width: 24,
                        height: 24,
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
                    userId: item.userId,
                    category: item.category,
                    location: item.location,
                  ),
                ),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 250,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Image load error for ${item.imageUrl}: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
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
                          "LKR ${item.price}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Inbox',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: _isRefreshingChats
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _isRefreshingChats ? null : _refreshConversations,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              onRefresh: _refreshConversations,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading chats: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No chat participants found.'));
                  }
                  final conversations = snapshot.data!;
                  return ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final participantName = conversation['username'] ?? conversation['sellerEmail'] ?? 'Unknown';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            participantName.isNotEmpty ? participantName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        title: Text(
                          participantName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        // subtitle: Text(
                        //   'Recent: ${conversation['itemName']}',
                        //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                        // ),
                        onTap: () {
                          if (userEmail == null || userId == null || username == null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatWithSeller(
                                sellerEmail: conversation['sellerEmail'] ?? '',
                                itemName: conversation['itemName'] ?? 'Unknown Item',
                                currentUserEmail: userEmail!,
                                currentUsername: username!,
                                currentUserId: userId!,
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
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchConversations() async {
    if (userEmail == null) {
      print('No user email, returning empty conversations');
      return [];
    }
    try {
      await MongoDataBase.connectToChats();
      final db = MongoDataBase.chatDb;
      final collectionNames = (await db.getCollectionNames()).whereType<String>().toList();
      final userCollections = collectionNames
          .where((name) => name.contains(userEmail!) && !name.startsWith(userEmail! + '-' + userEmail!))
          .toList();
      print('Found collections for user $userEmail: $userCollections');

      final conversations = <Map<String, dynamic>>[];
      final seenParticipants = <String>{};

      for (var collectionName in userCollections) {
        final emails = collectionName.split('-');
        final otherUserEmail = emails.firstWhere((email) => email != userEmail!, orElse: () => '');
        if (otherUserEmail.isEmpty) {
          print('Skipping invalid collection: $collectionName');
          continue;
        }
        final messages = await MongoDataBase.fetchChatMessages(userEmail!, otherUserEmail);
        String? participantUsername;
        try {
          final marketItem = await MongoDataBase.fetchMarketItemByUserEmail(otherUserEmail);
          participantUsername = marketItem?['username']?.toString() ?? otherUserEmail;
        } catch (e) {
          print('Error fetching username for $otherUserEmail: $e');
          participantUsername = otherUserEmail;
        }
        for (var message in messages) {
          final sender = message['sender']?.toString() ?? '';
          final receiver = message['receiver']?.toString() ?? '';
          final participantEmail = sender == userEmail ? receiver : sender;
          if (participantEmail.isEmpty) {
            print('Skipping message with empty sender/receiver: $message');
            continue;
          }
          final itemName = message['text']?.toString().split('about ').last ?? 'Unknown Item';
          final conversationKey = participantEmail;

          if (!seenParticipants.contains(conversationKey)) {
            conversations.add({
              'sellerEmail': participantEmail,
              'username': participantUsername,
              'itemName': itemName,
            });
            seenParticipants.add(conversationKey);
          }
        }
      }
      print('Fetched ${conversations.length} chat participants');
      return conversations;
    } catch (e) {
      print('Error fetching conversations: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch chat participants: $e')),
        );
      });
      return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}

class LocationPickerDialog extends StatefulWidget {
  final VoidCallback onItemAdded;
  final String userEmail;
  final String username;
  final String userId;

  const LocationPickerDialog({
    Key? key,
    required this.onItemAdded,
    required this.userEmail,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
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
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploadingImage = false;

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
    print('Map created in LocationPickerDialog');
  }

  Future<void> _addMarkerFromSearch() async {
    final locationName = _searchController.text.trim();
    if (locationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$locationName&components=country:LK&key=$googleApiKey',
      );
      final response = await http.get(url);

      print('Geocoding API response status: ${response.statusCode}');
      print('Geocoding API response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'OK' && json['results'].isNotEmpty) {
          final location = json['results'][0]['geometry']['location'];
          final placeName = json['results'][0]['formatted_address'] ?? locationName;
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;

          setState(() {
            _selectedLocation = LatLng(lat, lng);
            _markers = {
              Marker(
                markerId: MarkerId(placeName),
                position: _selectedLocation!,
                infoWindow: InfoWindow(title: placeName),
              ),
            };
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
          );
          _searchController.clear();
          print('Marker added at: $placeName ($lat, $lng)');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found. Try a different name')),
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
            SnackBar(content: Text('Failed to fetch location: ${response.statusCode}, $error')),
          );
        }
      }
    } catch (e) {
      print('Error adding marker from search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding location: $e')),
      );
    }
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

      const String backendUrl = 'http://localhost:3000';
      
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
          'routeConfig': ['image'],
          'metadata': null,
          'callbackUrl': 'http://example.com/callback',
          'callbackSlug': 'upload-callback',
        }),
      );

      if (prepareResponse.statusCode != 200) {
        throw Exception('Failed to prepare upload: ${prepareResponse.body}');
      }

      final prepareData = jsonDecode(prepareResponse.body);
      
      if (prepareData[0] == null || prepareData[0].isEmpty) {
        throw Exception('Invalid response from upload service');
      }

      final uploadData = prepareData[0];
      
      if (uploadData['url'] == null) {
        throw Exception('Upload URL not provided');
      }

      final uploadRequest = http.MultipartRequest('POST', Uri.parse(uploadData['url']));

      if (uploadData['fields'] != null) {
        final fields = uploadData['fields'];
        developer.log('Upload fields: $fields');

        if (fields is Map<String, dynamic>) {
          fields.forEach((key, value) {
            uploadRequest.fields[key] = value.toString();
          });
        } else if (fields is List) {
          for (var field in fields) {
            if (field is Map<String, dynamic>) {
              field.forEach((key, value) {
                uploadRequest.fields[key] = value.toString();
              });
            }
          }
        }
      }
      
      uploadRequest.files.add(
        await http.MultipartFile.fromPath('file', image.path),
      );

      final uploadResponse = await uploadRequest.send();
      final responseBody = await uploadResponse.stream.bytesToString();
      
      print('Upload response status: ${uploadResponse.statusCode}');
      print('Upload response body: $responseBody');
      
      if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201 || uploadResponse.statusCode == 204) {
        return uploadData['fileUrl'];
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add New Market Item',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color.fromARGB(255, 204, 104, 4),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_nameController, 'Item Name'),
            const SizedBox(height: 16),
            _buildTextField(_priceController, 'Price'),
            const SizedBox(height: 16),
            _buildTextField(_descriptionController, 'Description (optional)', maxLines: 3),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
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
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              child: ListTile(
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
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            _buildTextField(_searchController, 'Search for a location (e.g., Colombo, LK)', suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _addMarkerFromSearch,
            )),
            const SizedBox(height: 16),
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
                padding: const EdgeInsets.only(top: 16.0),
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
          onPressed: _isUploadingImage ? null : () async {
            if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item name and price are required')),
              );
              return;
            }
            if (widget.username == 'Guest') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in with a valid username')),
              );
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignInPage()));
              return;
            }
            String? imageUrl;
            if (_selectedImage != null) {
              imageUrl = await _uploadImage(_selectedImage!);
              if (imageUrl == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Image upload failed. Please try again.")),
                );
                return;
              }
            }
            final newItem = MarketItemModel(
              name: _nameController.text,
              price: _priceController.text,
              imageUrl: imageUrl,
              description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
              username: widget.username,
              userEmail: widget.userEmail,
              userId: widget.userId,
              category: selectedCategory,
              location: _selectedLocation,
            );
            try {
              await MongoDataBase.connectToChats();
              await MongoDataBase.insertMarketItem(newItem.toMap());
              Navigator.pop(context);
              widget.onItemAdded();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding item: $e')),
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
              : const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText, {int maxLines = 1, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: suffixIcon,
      ),
      maxLines: maxLines,
      onSubmitted: labelText.contains('location') ? (_) => _addMarkerFromSearch() : null,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
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