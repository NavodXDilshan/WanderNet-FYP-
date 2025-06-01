import 'package:flutter_dotenv/flutter_dotenv.dart';  

var MONGO_URL_posts=dotenv.env['MONGO_URL_posts'] ?? 'default_url';
const COLLECTION_NAME_POSTS="posts";

var MONGO_URL_users=dotenv.env['MONGO_URL_users'] ?? 'default_url';
const COLLECTION_NAME_USERS="";

var MONGO_URL_wishlist=dotenv.env['MONGO_URL_wishlist'] ?? 'default_url';
const COLLECTION_NAME_LIST="posts";

