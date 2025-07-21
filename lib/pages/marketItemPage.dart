import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'marketChat.dart';
import 'market.dart'; // Import market.dart for AuthService

class MarketItemDetailPage extends StatelessWidget {
  final String itemId;
  final String name;
  final String? imageUrl;
  final String price;
  final String? description;
  final String username;
  final String userEmail;
  final String userId;
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
    required this.userId,
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

    void showReportDialog() async {
      String? selectedReason;
      final userInfo = await Supabase.instance.client.auth.currentUser != null
          ? {
              'userEmail': Supabase.instance.client.auth.currentUser!.email,
              'userId': Supabase.instance.client.auth.currentUser!.id,
            }
          : {'userEmail': null, 'userId': null};
      final reporterEmail = userInfo['userEmail'];
      final reporterId = userInfo['userId'];
      if (reporterEmail == null || reporterId == null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
        return;
      }
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
                      'sellerId': userId,
                      'reporterEmail': reporterEmail,
                      'reporterId': reporterId,
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
                        onPressed: () async {
                          try {
                            final userInfo = await AuthService.getUserInfo();
                            final currentUserEmail = userInfo['userEmail'];
                            final currentUsername = userInfo['username'];
                            final currentUserId = userInfo['userId'];
                            print('User info: email=$currentUserEmail, username=$currentUsername, userId=$currentUserId');
                            if (currentUserEmail == null || currentUserId == null || currentUsername == null || currentUsername == 'Guest') {
                              print('Navigation to SignInPage due to missing or invalid user info');
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
                              return;
                            }
                            print('Navigating to ChatWithSeller with sellerEmail=$userEmail, itemName=$name');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatWithSeller(
                                  sellerEmail: userEmail,
                                  itemName: name,
                                  currentUserEmail: currentUserEmail,
                                  currentUsername: currentUsername,
                                  currentUserId: currentUserId,
                                ),
                              ),
                            );
                          } catch (e) {
                            print('Error fetching user info for chat: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error starting chat: $e')),
                            );
                          }
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