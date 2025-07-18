import 'package:mongo_dart/mongo_dart.dart';
import 'package:app/dbHelper/constant.dart';

class MongoDataBase {
  static late Db _dbPosts;
  static late Db _dbWishlist;
  static late DbCollection _postsCollection;
  static late DbCollection _wishlistCollection;

  static Future<void> connect() async {
    try {
      _dbPosts = await Db.create(MONGO_URL_posts);
      _dbWishlist = await Db.create(MONGO_URL_wishlist);
      await _dbPosts.open();
      await _dbWishlist.open();
      _postsCollection = _dbPosts.collection('posts');
      _wishlistCollection = _dbWishlist.collection('k.m.navoddilshan');
    } catch (e) {
      print('MongoDB connection error: $e');
      rethrow;
    }
  }

  static Future<void> insertPost(Map<String, dynamic> postData) async {
    try {
      await _postsCollection.insert(postData);
    } catch (e) {
      print('Error inserting post: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPosts() async {
    try {
      final posts = await _postsCollection
          .find(where.sortBy('createdAt', descending: true))
          .toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  static Future<void> likePost(String postId, String userId) async {
    try {
      await _postsCollection.update(
        where.eq('_id', ObjectId.fromHexString(postId)),
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
    try {
      await _postsCollection.update(
        where.eq('_id', ObjectId.fromHexString(postId)),
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
    try {
      final post = await _postsCollection.findOne(
        where.eq('_id', ObjectId.fromHexString(postId)).eq('likedBy', userId),
      );
      return post != null;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  static Future<void> incrementComments(String postId) async {
    try {
      await _postsCollection.update(
        where.eq('_id', ObjectId.fromHexString(postId)),
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
    try {
      await _postsCollection.update(
        where.eq('_id', ObjectId.fromHexString(postId)),
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
    try {
      final collection = _dbWishlist.collection(userEmail);
      await collection.insert(wishlistData);
    } catch (e) {
      print('Error inserting wishlist item: $e');
      rethrow;
    }
  }

  static Future<void> removeWishlistItem(String userEmail, String placeId) async {
    try {
      final collection = _dbWishlist.collection(userEmail);
      await collection.remove(where.eq('placeId', placeId));
    } catch (e) {
      print('Error removing wishlist item: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWishlistItems(String userEmail) async {
    try {
      final collection = _dbWishlist.collection(userEmail);
      final items = await collection.find().toList();
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching wishlist items: $e');
      return [];
    }
  }

  static Future<void> updateWishlistItem(String userEmail, String itemId, double? rating, double? switchWeight) async {
    try {
      final collection = _dbWishlist.collection(userEmail);
      final updateFields = <String, dynamic>{};
      if (rating != null) {
        updateFields['rating'] = rating;
      }
      if (switchWeight != null) {
        updateFields['switchWeight'] = switchWeight;
      }
      await collection.update(
        where.eq('_id', ObjectId.fromHexString(itemId)),
        {'\$set': updateFields},
      );
    } catch (e) {
      print('Error updating wishlist item: $e');
      rethrow;
    }
  }

  static Future<void> insertComment(String postId, String userId, String userName, String content) async {
    try {
      final comment = {
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _postsCollection.update(
        where.eq('_id', ObjectId.fromHexString(postId)),
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
    try {
      final post = await _postsCollection.findOne(where.eq('_id', ObjectId.fromHexString(postId)));
      if (post != null && post['commentsList'] != null) {
        return List<Map<String, dynamic>>.from(post['commentsList']);
      }
      return [];
    } catch (e) {
      print('Error fetching comments: $e');
      rethrow;
    }
  }
}