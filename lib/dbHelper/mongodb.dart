import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:app/dbHelper/constant.dart';
import '../pages/market.dart'; 

class MongoDataBase {
  static mongo.Db? _dbPosts;
  static mongo.Db? _dbWishlist;
  static mongo.Db? _dbMarket;
  static mongo.Db? _dbChats;
  static mongo.Db? _dbReports;
  static mongo.DbCollection? _postsCollection;
  static mongo.DbCollection? _wishlistCollection;
  static mongo.DbCollection? _marketCollection;
  static mongo.DbCollection? _chatCollection;
  static mongo.DbCollection? _reportsCollection;
  static mongo.DbCollection? _reportedPostsCollection; // New collection for reported posts
  static bool _isConnected = false;
  static bool _isChatsConnected = false;
  static bool _isReportsConnected = false;

static Future<void> connect() async {
    try {
      if (_isConnected) return;

      _dbPosts = await mongo.Db.create(MONGO_URL_posts);
      _dbWishlist = await mongo.Db.create(MONGO_URL_wishlist);
      _dbMarket = await mongo.Db.create(MONGO_URL_market);
      await _dbPosts!.open();
      await _dbWishlist!.open();
      await _dbMarket!.open();
      _postsCollection = _dbPosts!.collection('posts');
      _wishlistCollection = _dbWishlist!.collection(await _getCurrentUserEmail()); // Dynamic collection
      _marketCollection = _dbMarket!.collection(COLLECTION_NAME_MARKET);
      _isConnected = true;
      print('MongoDB connected successfully');
      _startPeriodicPing(); // Keep connection alive
    } catch (e) {
      print('MongoDB connection error: $e');
      rethrow;
    }
  }

  static Future<String> _getCurrentUserEmail() async {
    // Placeholder: Replace with actual user email retrieval
    final userInfo = await AuthService.getUserInfo(); // Assuming AuthService is available
    return userInfo['userEmail'] ?? 'k.m.navoddilshan@gmail.com';
  }

  static void _startPeriodicPing() {
    // Periodic ping to keep connection alive
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 5));
      if (_dbWishlist != null && _dbWishlist!.isConnected) {
        try {
          await _dbWishlist!.collection('test').findOne();
          print('Wishlist connection ping successful');
        } catch (e) {
          print('Wishlist ping failed: $e');
          await MongoDataBase.reconnect();
        }
      }
      return true; // Continue looping
    });
  }

  static Future<void> connectToChats() async {
    try {
      if (_isChatsConnected) return;

      _dbChats = await mongo.Db.create(MONGO_URL_chats);
      await _dbChats!.open();
      _isChatsConnected = true;
      print('MongoDB chats database connected successfully');
    } catch (e) {
      print('Error connecting to chats MongoDB: $e');
      rethrow;
    }
  }

  static Future<void> connectToReports() async {
    try {
      if (_isReportsConnected) return;

      _dbReports = await mongo.Db.create(MONGO_URL_reports);
      await _dbReports!.open();
      _reportsCollection = _dbReports!.collection('reported-markets');
      _reportedPostsCollection = _dbReports!.collection('reported-posts'); // Initialize reported-posts collection
      _isReportsConnected = true;
      print('MongoDB reports database connected successfully');
    } catch (e) {
      print('Error connecting to reports MongoDB: $e');
      rethrow;
    }
  }

  static void _ensureInitialized() {
    if (!_isConnected || _marketCollection == null || _postsCollection == null || _wishlistCollection == null) {
      throw StateError('MongoDataBase is not initialized. Call connect() first.');
    }
  }

  static void _ensureChatsInitialized() {
    if (!_isChatsConnected || _dbChats == null) {
      throw StateError('Chats database is not initialized. Call connectToChats() first.');
    }
  }

  static void _ensureReportsInitialized() {
    if (!_isReportsConnected || _dbReports == null || _reportsCollection == null || _reportedPostsCollection == null) {
      throw StateError('Reports database is not initialized. Call connectToReports() first.');
    }
  }

  static Future<void> insertMarketItem(Map<String, dynamic> itemData) async {
    _ensureInitialized();
    try {
      await _marketCollection!.insert(itemData);
    } catch (e) {
      print('Error inserting market item: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMarketItems() async {
    _ensureInitialized();
    try {
      final items = await _marketCollection!
          .find(mongo.where.sortBy('createdAt', descending: true))
          .toList();
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching market items: $e');
      return [];
    }
  }

  static Future<void> insertPost(Map<String, dynamic> postData) async {
    _ensureInitialized();
    try {
      await _postsCollection!.insert(postData);
    } catch (e) {
      print('Error inserting post: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPosts() async {
    _ensureInitialized();
    try {
      final posts = await _postsCollection!
          .find(mongo.where.eq('valid', 'true').sortBy('createdAt', descending: true))
          .toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  static Future<void> likePost(String postId, String userId) async {
    _ensureInitialized();
    try {
      await _postsCollection!.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)),
        {
          '\$inc': {'likes': 1},
          '\$addToSet': {'likedBy': userId}
        },
      );
    } catch (e) {
      print('Error liking post: $e');
      rethrow;
    }
  }

  static Future<void> unlikePost(String postId, String userId) async {
    _ensureInitialized();
    try {
      await _postsCollection!.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)),
        {
          '\$inc': {'likes': -1},
          '\$pull': {'likedBy': userId}
        },
      );
    } catch (e) {
      print('Error unliking post: $e');
      rethrow;
    }
  }

  static Future<bool> hasUserLiked(String postId, String userId) async {
    _ensureInitialized();
    try {
      final post = await _postsCollection!.findOne(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)).eq('likedBy', userId),
      );
      return post != null;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  static Future<void> incrementComments(String postId) async {
    _ensureInitialized();
    try {
      await _postsCollection!.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)),
        {
          '\$inc': {'comments': 1}
        },
      );
    } catch (e) {
      print('Error incrementing comments: $e');
      rethrow;
    }
  }

  static Future<void> incrementShares(String postId) async {
    _ensureInitialized();
    try {
      await _postsCollection!.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)),
        {
          '\$inc': {'shares': 1}
        },
      );
    } catch (e) {
      print('Error incrementing shares: $e');
      rethrow;
    }
  }

  static Future<void> insertWishlistItem(String userEmail, Map<String, dynamic> wishlistData) async {
    _ensureInitialized();
    try {
      final collection = _dbWishlist!.collection(userEmail);
      await collection.insert(wishlistData);
    } catch (e) {
      print('Error inserting wishlist item: $e');
      rethrow;
    }
  }

  static Future<void> removeWishlistItem(String userEmail, String placeId) async {
    _ensureInitialized();
    try {
      final collection = _dbWishlist!.collection(userEmail);
      await collection.remove(mongo.where.eq('placeId', placeId));
    } catch (e) {
      print('Error removing wishlist item: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWishlistItems(String userEmail) async {
    _ensureInitialized();
    try {
      final collection = _dbWishlist!.collection(userEmail);
      final items = await collection.find().toList();
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching wishlist items: $e');
      return [];
    }
  }

  static Future<void> updateWishlistItem(String userEmail, String itemId, double? rating, double? switchWeight) async {
    _ensureInitialized();
    try {
      final collection = _dbWishlist!.collection(userEmail);
      final updateFields = <String, dynamic>{};
      if (rating != null) {
        updateFields['rating'] = rating;
      }
      if (switchWeight != null) {
        updateFields['switchWeight'] = switchWeight;
      }
      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(itemId)),
        {'\$set': updateFields},
      );
    } catch (e) {
      print('Error updating wishlist item: $e');
      rethrow;
    }
  }

  static Future<void> insertComment(String postId, String userId, String userName, String content) async {
    _ensureInitialized();
    try {
      final comment = {
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _postsCollection!.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)),
        {
          '\$push': {'commentsList': comment},
          '\$inc': {'comments': 1},
        },
      );
      print('Comment inserted for post $postId by $userId');
    } catch (e) {
      print('Error inserting comment: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    _ensureInitialized();
    try {
      final post = await _postsCollection!.findOne(mongo.where.eq('_id', mongo.ObjectId.fromHexString(postId)));
      if (post != null && post['commentsList'] != null) {
        return List<Map<String, dynamic>>.from(post['commentsList']);
      }
      return [];
    } catch (e) {
      print('Error fetching comments: $e');
      rethrow;
    }
  }

  static Future<void> insertChatMessage(String senderEmail, String receiverEmail, Map<String, dynamic> message) async {
    try {
      _ensureChatsInitialized();
      final collectionName = _getChatCollectionName(senderEmail, receiverEmail);
      _chatCollection = _dbChats!.collection(collectionName);
      await _chatCollection!.insertOne(message);
      print('Chat message inserted successfully in $collectionName');
    } catch (e) {
      print('Error inserting chat message: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages(String senderEmail, String receiverEmail) async {
    try {
      _ensureChatsInitialized();
      final collectionName = _getChatCollectionName(senderEmail, receiverEmail);
      _chatCollection = _dbChats!.collection(collectionName);
      final messages = await _chatCollection!
          .find(mongo.where.sortBy('createdAt', descending: false))
          .toList();
      return messages.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching chat messages: $e');
      return [];
    }
  }

  // Existing method for reporting markets (unchanged)
  static Future<void> insertReport(Map<String, dynamic> reportData) async {
    try {
      _ensureReportsInitialized();
      await _reportsCollection!.insertOne(reportData);
      print('Market report inserted successfully');
    } catch (e) {
      print('Error inserting market report: $e');
      rethrow;
    }
  }

  // New method for reporting posts
  static Future<void> insertPostReport(Map<String, dynamic> reportData) async {
    try {
      _ensureReportsInitialized();
      await _reportedPostsCollection!.insertOne(reportData);
      print('Post report inserted successfully');
    } catch (e) {
      print('Error inserting post report: $e');
      rethrow;
    }
  }

  // Fetch reported posts
  static Future<List<Map<String, dynamic>>> fetchReportedPosts() async {
    try {
      _ensureReportsInitialized();
      final reports = await _reportedPostsCollection!
          .find(mongo.where.sortBy('reportedAt', descending: true))
          .toList();
      return reports.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching reported posts: $e');
      return [];
    }
  }

  // Fetch reported markets (for consistency)
  static Future<List<Map<String, dynamic>>> fetchReportedMarkets() async {
    try {
      _ensureReportsInitialized();
      final reports = await _reportsCollection!
          .find(mongo.where.sortBy('reportedAt', descending: true))
          .toList();
      return reports.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching reported markets: $e');
      return [];
    }
  }

  // Update report status (can be used for both posts and markets)
  static Future<void> updateReportStatus(String reportId, String status, {bool isPostReport = false}) async {
    try {
      _ensureReportsInitialized();
      final collection = isPostReport ? _reportedPostsCollection! : _reportsCollection!;
      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(reportId)),
        {
          '\$set': {
            'status': status,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        },
      );
      print('Report status updated successfully');
    } catch (e) {
      print('Error updating report status: $e');
      rethrow;
    }
  }

  static String _getChatCollectionName(String senderEmail, String receiverEmail) {
    final emails = [senderEmail, receiverEmail]..sort();
    return '${emails[0]}-${emails[1]}';
  }

  static mongo.Db get chatDb {
    _ensureChatsInitialized();
    return _dbChats!;
  }

  static mongo.Db get reportsDb {
    _ensureReportsInitialized();
    return _dbReports!;
  }

  /// Checks the connection status for all databases.
  static Future<void> checkConnection() async {
    try {
      await _checkSpecificConnection(_dbPosts, _isConnected);
      await _checkSpecificConnection(_dbWishlist, _isConnected);
      await _checkSpecificConnection(_dbMarket, _isConnected);
      await _checkSpecificConnection(_dbChats, _isChatsConnected);
      await _checkSpecificConnection(_dbReports, _isReportsConnected);
    } catch (e) {
      print('Connection check failed: $e');
      throw e; // Let the caller handle reconnection
    }
  }

  /// Helper method to check a specific database connection.
  static Future<void> _checkSpecificConnection(mongo.Db? db, bool isConnectedFlag) async {
    if (db == null || !db.isConnected) {
      isConnectedFlag = false;
      throw Exception('Database connection lost');
    }
    try {
      // Use a lightweight query to test connection
      await db.collection('test').findOne();
      isConnectedFlag = true;
    } catch (e) {
      isConnectedFlag = false;
      print('Connection check failed for ${db.databaseName}: $e');
      throw Exception('Connection lost for ${db.databaseName}: $e');
    }
  }

  /// Reconnects all databases with exponential backoff.
  static Future<void> reconnect() async {
    int retryCount = 0;
    const int maxRetries = 5;
    const int maxDelaySeconds = 16;

    while (retryCount < maxRetries) {
      try {
        await _reconnectSpecific(_dbPosts, 'posts', connect, _isConnected);
        await _reconnectSpecific(_dbWishlist, 'wishlist', connect, _isConnected);
        await _reconnectSpecific(_dbMarket, 'market', connect, _isConnected);
        await _reconnectSpecific(_dbChats, 'chats', connectToChats, _isChatsConnected);
        await _reconnectSpecific(_dbReports, 'reports', connectToReports, _isReportsConnected);
        print('All MongoDB databases reconnected successfully');
        break;
      } catch (e) {
        retryCount++;
        final delay = Duration(seconds: (1 << retryCount).clamp(1, maxDelaySeconds));
        print('Reconnection attempt $retryCount/$maxRetries failed: $e. Retrying in $delay');
        await Future.delayed(delay);
      }
    }
    if (retryCount >= maxRetries) {
      print('Max retry attempts reached. MongoDB reconnection failed.');
      throw Exception('Failed to reconnect to MongoDB after $maxRetries attempts');
    }
  }

  /// Helper method to reconnect a specific database.
  static Future<void> _reconnectSpecific(mongo.Db? db, String dbName, Future<void> Function() connectMethod, bool isConnectedFlag) async {
    if (db != null) {
      try {
        await db.close();
      } catch (e) {
        print('Error closing $dbName database: $e');
      }
    }
    await connectMethod();
    isConnectedFlag = true;
    print('$dbName database reconnected successfully');
  }
}