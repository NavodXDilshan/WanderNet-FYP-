import 'package:flutter/material.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/pages/planner.dart' as planner;

class Settings extends StatefulWidget {
  final VoidCallback onWishlistUpdated; // Callback to notify Planner of changes

  const Settings({super.key, required this.onWishlistUpdated});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String? userEmail;
  String? userId;
  List<Map<String, dynamic>> wishlistItems = [];
  Map<String, TextEditingController> ratingControllers = {};
  Map<String, TextEditingController> weightControllers = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await planner.AuthService.getUserInfo();
      setState(() {
        userEmail = userInfo['userEmail'];
        userId = userInfo['userId'];
      });
      if (userEmail != null && userId != null) {
        await _loadWishlistItems();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const planner.SignInPage()),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading user info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user info: $e')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const planner.SignInPage()),
      );
    }
  }

  Future<void> _loadWishlistItems() async {
    if (userEmail == null || userId == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const planner.SignInPage()),
      );
      return;
    }
    try {
      final items = await MongoDataBase.fetchWishlistItems(userEmail!);
      setState(() {
        wishlistItems = items;
        for (var item in items) {
          final itemId = item['_id'].toHexString();
          ratingControllers[itemId] = TextEditingController(
            text: item['rating']?.toString() ?? '',
          );
          weightControllers[itemId] = TextEditingController(
            text: item['switchWeight']?.toString() ?? '',
          );
        }
        isLoading = false;
      });
      print('Loaded wishlist items for $userEmail: ${wishlistItems.length}');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Failed to load wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load wishlist: $e')),
      );
    }
  }

  Future<void> _submitChanges() async {
    if (userEmail == null || userId == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const planner.SignInPage()),
      );
      return;
    }
    try {
      for (var item in wishlistItems) {
        final itemId = item['_id'].toHexString();
        final ratingText = ratingControllers[itemId]?.text;
        final weightText = weightControllers[itemId]?.text;

        final rating = ratingText != null && ratingText.isNotEmpty
            ? double.tryParse(ratingText)
            : null;
        final switchWeight = weightText != null && weightText.isNotEmpty
            ? double.tryParse(weightText)
            : null;

        if (rating != null && (rating < 1.0 || rating > 5.0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rating for ${item['placeName']} must be between 1.0 and 5.0')),
          );
          return;
        }
        if (switchWeight != null && (switchWeight < 0.0 || switchWeight > 100.0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Explore time for ${item['placeName']} must be between 0.0 and 100.0 hours')),
          );
          return;
        }

        if (rating != null || switchWeight != null) {
          await MongoDataBase.updateWishlistItem(userEmail!, itemId, rating, switchWeight);
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wishlist updated successfully')),
      );
      await _loadWishlistItems(); // Refresh Settings list
      widget.onWishlistUpdated(); // Notify Planner to refresh
    } catch (e) {
      print('Failed to update wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update wishlist: $e')),
      );
    }
  }

  @override
  void dispose() {
    ratingControllers.forEach((_, controller) => controller.dispose());
    weightControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 240, 144, 9),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistItems.isEmpty
              ? const Center(child: Text('No wishlist items found. Add some places in the Planner!'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: wishlistItems.length,
                        itemBuilder: (context, index) {
                          final item = wishlistItems[index];
                          final itemId = item['_id'].toHexString();
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['placeName'] ?? 'Unknown Place',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: ratingControllers[itemId],
                                    decoration: const InputDecoration(
                                      labelText: 'Rating (1.0 to 5.0)',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: weightControllers[itemId],
                                    decoration: const InputDecoration(
                                      labelText: 'Exploration Time (hours)',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: _submitChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
    );
  }
}