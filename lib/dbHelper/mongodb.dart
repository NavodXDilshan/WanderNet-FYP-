import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:app/dbHelper/constant.dart';

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
      _wishlistCollection = _dbWishlist!.collection('k.m.navoddilshan@gmail.com');
      _marketCollection = _dbMarket!.collection(COLLECTION_NAME_MARKET);
      _isConnected = true;
      print('MongoDB connected successfully');
    } catch (e) {
      print('MongoDB connection error: $e');
      rethrow;
    }
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
    if (!_isReportsConnected || _dbReports == null || _reportsCollection == null) {
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
          .find(mongo.where.sortBy('createdAt', descending: true))
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

  static Future<void> insertReport(Map<String, dynamic> reportData) async {
    try {
      _ensureReportsInitialized();
      await _reportsCollection!.insertOne(reportData);
      print('Report inserted successfully');
    } catch (e) {
      print('Error inserting report: $e');
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

  
}