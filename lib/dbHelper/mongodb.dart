import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'constant.dart';

class MongoDataBase {
  static Db? _dbPosts;
  static Db? _dbWishlist;
  static bool _isConnectingPosts = false;
  static bool _isConnectingWishlist = false;

  // Initialize and connect to MongoDB for posts
  static Future<void> connectPosts() async {
    if (_dbPosts != null && _dbPosts!.isConnected) {
      log('MongoDB posts already connected');
      return; // Already connected
    }

    if (_isConnectingPosts) {
      log('Waiting for existing posts connection attempt');
      while (_isConnectingPosts) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    try {
      _isConnectingPosts = true;
      log('Attempting to connect to MongoDB posts with URL: $MONGO_URL_posts');
      _dbPosts = await Db.create(MONGO_URL_posts);
      await _dbPosts!.open();
      inspect(_dbPosts);
      log('Connected to MongoDB posts');
    } catch (e) {
      log('Error connecting to MongoDB posts: $e');
      rethrow;
    } finally {
      _isConnectingPosts = false;
    }
  }

  // Initialize and connect to MongoDB for wishlist
  static Future<void> connectWishlist() async {
    if (_dbWishlist != null && _dbWishlist!.isConnected) {
      log('MongoDB wishlist already connected');
      return; // Already connected
    }

    if (_isConnectingWishlist) {
      log('Waiting for existing wishlist connection attempt');
      while (_isConnectingWishlist) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    try {
      _isConnectingWishlist = true;
      log('Attempting to connect to MongoDB wishlist with URL: $MONGO_URL_wishlist');
      _dbWishlist = await Db.create(MONGO_URL_wishlist);
      await _dbWishlist!.open();
      inspect(_dbWishlist);
      log('Connected to MongoDB wishlist');
    } catch (e) {
      log('Error connecting to MongoDB wishlist: $e');
      rethrow;
    } finally {
      _isConnectingWishlist = false;
    }
  }

  // Get the posts collection
  static Future<DbCollection> getPostsCollection() async {
    await connectPosts();
    if (_dbPosts == null) {
      log('Posts database is null after connect');
      throw Exception('Failed to initialize posts database');
    }
    log('Retrieving posts collection: $COLLECTION_NAME_POSTS');
    return _dbPosts!.collection(COLLECTION_NAME_POSTS);
  }

  // Get the wishlist collection for a user
  static Future<DbCollection> getWishlistCollection(String userEmail) async {
    await connectWishlist();
    if (_dbWishlist == null) {
      log('Wishlist database is null after connect');
      throw Exception('Failed to initialize wishlist database');
    }
    log('Retrieving wishlist collection: $userEmail');
    return _dbWishlist!.collection(userEmail);
  }

  // Insert a post
  static Future<void> insertPost(Map<String, dynamic> postData) async {
    try {
      final collection = await getPostsCollection();
      postData['likedBy'] = postData['likedBy'] ?? [];
      await collection.insertOne(postData);
      log('Post inserted: $postData');
    } catch (e) {
      log('Error inserting post: $e');
      rethrow;
    }
  }

  // Insert a wishlist item
  static Future<void> insertWishlistItem(String userEmail, Map<String, dynamic> wishlistData) async {
    try {
      final collection = await getWishlistCollection(userEmail);
      await collection.insertOne(wishlistData);
      log('Wishlist item inserted for $userEmail: $wishlistData');
    } catch (e) {
      log('Error inserting wishlist item: $e');
      rethrow;
    }
  }

  // Fetch posts
  static Future<List<Map<String, dynamic>>> fetchPosts() async {
    try {
      final collection = await getPostsCollection();
      final posts = await collection
        .find(where.sortBy('createdAt', descending: true).limit(20))
        .toList();

      log('Fetched ${posts.length} posts');
      return posts;
    } catch (e) {
      log('Error fetching posts: $e');
      rethrow;
    }
  }

  // Check if a user has liked a post
  static Future<bool> hasUserLiked(String postId, String userId) async {
    try {
      final collection = await getPostsCollection();
      final post = await collection.findOne(where.eq('_id', ObjectId.parse(postId)));
      final likedBy = post?['likedBy'] as List<dynamic>? ?? [];
      return likedBy.contains(userId);
    } catch (e) {
      log('Error checking if user liked post: $e');
      rethrow;
    }
  }

  // Like a post
  static Future<void> likePost(String postId, String userId) async {
    try {
      final collection = await getPostsCollection();
      final post = await collection.findOne(where.eq('_id', ObjectId.parse(postId)));
      final likedBy = post?['likedBy'] as List<dynamic>? ?? [];
      if (likedBy.contains(userId)) {
        log('User $userId already liked post $postId');
        return;
      }
      await collection.updateOne(
        where.eq('_id', ObjectId.parse(postId)),
        ModifierBuilder()
            .push('likedBy', userId)
            .inc('likes', 1),
      );
      log('User $userId liked post $postId');
    } catch (e) {
      log('Error liking post: $e');
      rethrow;
    }
  }

  // Increment comments for a post
  static Future<void> incrementComments(String postId) async {
    try {
      final collection = await getPostsCollection();
      await collection.updateOne(
        where.eq('_id', ObjectId.parse(postId)),
        ModifierBuilder().inc('comments', 1),
      );
      log('Incremented comments for post: $postId');
    } catch (e) {
      log('Error incrementing comments: $e');
      rethrow;
    }
  }

  // Increment shares for a post
  static Future<void> incrementShares(String postId) async {
    try {
      final collection = await getPostsCollection();
      await collection.updateOne(
        where.eq('_id', ObjectId.parse(postId)),
        ModifierBuilder().inc('shares', 1),
      );
      log('Incremented shares for post: $postId');
    } catch (e) {
      log('Error incrementing shares: $e');
      rethrow;
    }
  }

  // Close connections
  static Future<void> close() async {
    if (_dbPosts != null && _dbPosts!.isConnected) {
      await _dbPosts!.close();
      _dbPosts = null;
      log('MongoDB posts connection closed');
    }
    if (_dbWishlist != null && _dbWishlist!.isConnected) {
      await _dbWishlist!.close();
      _dbWishlist = null;
      log('MongoDB wishlist connection closed');
    }
  }
}