import 'package:app/models/category_model.dart';
import 'package:app/models/beach_model.dart';
import 'package:app/models/hotel_model.dart';
import 'package:app/models/wild_model.dart';
import 'package:app/models/entertainment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  List<CategoryModel> categories = [];
  List<BeachLocationModel> beaches = [];
  List<HotelLocationModel> hotels = [];
  List<WildLocationModel> wildLocations = [];
  List<EntertainmentModel> entertainmentLocations = [];
  String? selectedCategory;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCategories();
  }

  void _getCategories() {
    categories = CategoryModel.getCategories();
  }

  Future<void> _getBeaches() async {
    setState(() {
      isLoading = true;
    });
    try {
      beaches = await BeachLocationModel.getBeachLocations();
    } catch (e) {
      print('Error loading beaches: $e');
      beaches = [];
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _getHotels() async {
    setState(() {
      isLoading = true;
    });
    try {
      hotels = await HotelLocationModel.getHotelLocations();
      print('Fetched hotels: ${hotels.length}');
    } catch (e) {
      print('Error loading hotels: $e');
      hotels = [];
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _getWildLocations() async {
    setState(() {
      isLoading = true;
    });
    try {
      wildLocations = await WildLocationModel.getWildLocation();
    } catch (e) {
      print('Error loading wild locations: $e');
      wildLocations = [];
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _getEntertainmentLocations() async {
    setState(() {
      isLoading = true;
    });
    try {
      entertainmentLocations = await EntertainmentModel.getEntertainmentLocations();
    } catch (e) {
      print('Error loading entertainment locations: $e');
      entertainmentLocations = [];
    }
    setState(() {
      isLoading = false;
    });
  }

  void _onCategorySelected(String categoryName) {
    setState(() {
      selectedCategory = categoryName;
    });
    switch (categoryName.toLowerCase()) {
      case 'beaches':
        _getBeaches();
        break;
      case 'hotels':
        _getHotels();
        break;
      case 'wildlife':
        _getWildLocations();
        break;
      case 'entertainment':
        _getEntertainmentLocations();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          const SizedBox(height: 40),
          _categoriesSection(),
          Expanded(
            child: isLoading
                ? _loadingIndicator()
                : selectedCategory == null
                    ? const Center(child: Text('Select a category to view locations.'))
                    : selectedCategory!.toLowerCase() == 'beaches'
                        ? _beachListSection()
                        : selectedCategory!.toLowerCase() == 'hotels'
                            ? _hotelListSection()
                            : selectedCategory!.toLowerCase() == 'wildlife'
                                ? _wildListSection()
                                : selectedCategory!.toLowerCase() == 'entertainment'
                                    ? _entertainmentListSection()
                                    : const Center(child: Text('Select a category to view locations.')),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      title: const Text(
        'HomePage',
        style: TextStyle(color: Colors.black, fontSize: 20),
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 240, 144, 9),
      leading: GestureDetector(
        onTap: () {},
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
    );
  }

  Container _searchField() {
    return Container(
      margin: const EdgeInsets.only(top: 40, left: 20, right: 20),
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
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color.fromARGB(255, 255, 255, 255),
          contentPadding: const EdgeInsets.all(15),
          hintText: 'search',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SvgPicture.asset('assets/icons/Search.svg'),
          ),
          suffixIcon: Container(
            width: 100,
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const VerticalDivider(
                    color: Colors.black,
                    indent: 10,
                    endIndent: 10,
                    thickness: 0.1,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset('assets/icons/Filter.svg'),
                  ),
                ],
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Column _categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'Category',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 120,
          color: const Color.fromARGB(255, 255, 255, 255),
          child: ListView.separated(
            itemCount: categories.length,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20),
            separatorBuilder: (context, index) => const SizedBox(width: 25),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _onCategorySelected(categories[index].name),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: categories[index].boxColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SvgPicture.asset(categories[index].iconPath),
                        ),
                      ),
                      Text(
                        categories[index].name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
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

  Widget _beachListSection() {
    if (beaches.isEmpty) {
      return const Center(child: Text('No beaches found.'));
    }
    return SizedBox(
      height: 400,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: beaches.length,
        itemBuilder: (context, index) {
          final beach = beaches[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationDetailPage(
                      name: beach.name,
                      imageUrl: beach.imageUrl,
                      description: beach.description,
                      rating: beach.rating,
                      category: 'beaches',
                      reviews: beach.reviews,
                    ),
                  ),
                );
              },
              leading: beach.imageUrl != null
                  ? Image.network(
                      beach.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 40,
                    ),
              title: Text(
                beach.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rating: ${beach.rating ?? 'N/A'}'),
                  Text(
                    beach.description ?? 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hotelListSection() {
    if (hotels.isEmpty) {
      return const Center(child: Text('No hotels found.'));
    }
    return SizedBox(
      height: 400,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: hotels.length,
        itemBuilder: (context, index) {
          final hotel = hotels[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationDetailPage(
                      name: hotel.name,
                      imageUrl: hotel.imageUrl,
                      description: hotel.description,
                      rating: hotel.rating,
                      category: 'hotels',
                      city: hotel.city,
                      reviews: hotel.reviews,
                    ),
                  ),
                );
              },
              leading: hotel.imageUrl != null
                  ? Image.network(
                      hotel.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 40,
                    ),
              title: Text(
                hotel.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rating: ${hotel.rating ?? 'N/A'}'),
                  Text(
                    hotel.description ?? 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wildListSection() {
    if (wildLocations.isEmpty) {
      return const Center(child: Text('No wildlife locations found.'));
    }
    return SizedBox(
      height: 400,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: wildLocations.length,
        itemBuilder: (context, index) {
          final wild = wildLocations[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationDetailPage(
                      name: wild.name,
                      imageUrl: wild.imageUrl,
                      description: wild.description,
                      rating: wild.rating,
                      category: 'wildlife',
                      reviews: wild.reviews,
                    ),
                  ),
                );
              },
              leading: wild.imageUrl != null
                  ? Image.network(
                      wild.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 40,
                    ),
              title: Text(
                wild.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rating: ${wild.rating ?? 'N/A'}'),
                  Text(
                    wild.description ?? 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _entertainmentListSection() {
    if (entertainmentLocations.isEmpty) {
      return const Center(child: Text('No entertainment locations found.'));
    }
    return SizedBox(
      height: 400,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: entertainmentLocations.length,
        itemBuilder: (context, index) {
          final entertainment = entertainmentLocations[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationDetailPage(
                      name: entertainment.name,
                      imageUrl: entertainment.imageUrl,
                      description: entertainment.description,
                      rating: entertainment.rating,
                      category: 'entertainment',
                      reviews: entertainment.reviews,
                    ),
                  ),
                );
              },
              leading: entertainment.imageUrl != null
                  ? Image.network(
                      entertainment.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 40,
                    ),
              title: Text(
                entertainment.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rating: ${entertainment.rating ?? 'N/A'}'),
                  Text(
                    entertainment.description ?? 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LocationDetailPage extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final String? description;
  final String? rating;
  final String? category;
  final String? city;
  final List<Map<String, dynamic>>? reviews;

  const LocationDetailPage({
    super.key,
    required this.name,
    this.imageUrl,
    this.description,
    this.rating,
    this.category,
    this.city,
    this.reviews,
  });

  @override
  _LocationDetailPageState createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<LocationDetailPage> {
  Future<void> _launchURL(String url, BuildContext context) async {
    print('Attempting to launch URL: $url');
    if (await canLaunchUrl(Uri.parse(url))) {
      try {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
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
    final encodedName = Uri.encodeComponent(widget.name);
    final encodedCity = widget.city != null && widget.city!.isNotEmpty && widget.city != widget.name
        ? Uri.encodeComponent(widget.city!)
        : 'Colombo';
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
    await Clipboard.setData(ClipboardData(text: widget.name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "${widget.name}" to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            backgroundColor: const Color.fromARGB(255, 240, 144, 9),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.name,
                style: const TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
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
            child: widget.imageUrl != null
                ? Image.network(
                    widget.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Image load error for ${widget.imageUrl}: $error');
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
                          widget.name,
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
                    'Rating: ${widget.rating ?? 'N/A'}',
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
                      widget.description ?? 'No description available',
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
                  if (widget.category?.toLowerCase() == 'hotels') ...[
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
                  ],
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
                  if (widget.reviews == null || widget.reviews!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8.0,0,8.0,0),
                      child: Text('No reviews available.'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(8.0,0,8.0,0),
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
                        itemCount: widget.reviews!.length,
                        itemBuilder: (context, index) {
                          final review = widget.reviews![index];
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
                                    // maxLines: 10,
                                    // overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}