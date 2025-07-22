import 'package:app/models/searchLocationModel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';


class SearchLocationDetailPage extends StatefulWidget {
  final SearchLocationModel location;

  const SearchLocationDetailPage({super.key, required this.location});

  @override
  _SearchLocationDetailPageState createState() => _SearchLocationDetailPageState();
}

class _SearchLocationDetailPageState extends State<SearchLocationDetailPage> {
  late Future<SearchLocationModel> _detailedLocation;

  @override
  void initState() {
    super.initState();
    _detailedLocation = SearchLocationModel.fetchDetails(widget.location.locationId ?? '');
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    print('Attempting to launch URL: $url');
    if (await canLaunchUrl(Uri.parse(url))) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        print('Launch error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    } else {
      print('Failed to launch URL: $url - CanLaunch returned false');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  String _getBookingUrl(String platform) {
    final encodedName = Uri.encodeComponent(widget.location.name);
    const encodedCity = 'Colombo'; // Default city; could be refined with API data
    switch (platform.toLowerCase()) {
      case 'tripadvisor':
        return 'https://www.tripadvisor.com/Search?q=$encodedName%20$encodedCity';
      case 'airbnb':
        return 'https://www.airbnb.com/s/$encodedName--$encodedCity';
      case 'booking.com':
        return 'https://www.booking.com/searchresults.html?ss=$encodedName,$encodedCity';
      default:
        return '';
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.location.name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "${widget.location.name}" to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<SearchLocationModel>(
        future: _detailedLocation,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading details: ${snapshot.error}'));
          }
          final location = snapshot.data ?? widget.location;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 60.0,
                backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    location.name,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 10),
                ),
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
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      width: 30,
                      child: SvgPicture.asset('assets/icons/dots.svg'),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 240, 144, 9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: location.imageUrl != null
                    ? Image.network(
                        location.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image load error for ${location.imageUrl}: $error');
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.grey,
                            ),
                          );
                        },
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
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              location.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 24, color: Colors.grey),
                            tooltip: 'Copy name',
                            onPressed: () => _copyToClipboard(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rating: ${location.rating ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(221, 0, 192, 0),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 231, 169, 93),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.grey,
                              spreadRadius: 2,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          location.description ?? 'No description available',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _launchURL(_getBookingUrl('TripAdvisor'), context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(200, 48),
                            ),
                            child: const Text(
                              'Book on TripAdvisor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _launchURL(_getBookingUrl('airbnb'), context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(200, 48),
                            ),
                            child: const Text(
                              'Book on AirBnb',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _launchURL(_getBookingUrl('Booking.com'), context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 240, 144, 9),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              minimumSize: const Size(200, 48),
                            ),
                            child: const Text(
                              'Book on Booking.com',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Most Recent TripAdvisor Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color.fromARGB(255, 247, 183, 45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (location.reviews == null || location.reviews!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
                          child: Text('No reviews available.'),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: location.reviews!.length,
                            itemBuilder: (context, index) {
                              final review = location.reviews![index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6.0),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Rating: ${review['rating'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color.fromARGB(221, 0, 192, 0),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.star,
                                            color: Color.fromARGB(221, 255, 215, 0),
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        review['text'] ?? 'No review text',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
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
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}