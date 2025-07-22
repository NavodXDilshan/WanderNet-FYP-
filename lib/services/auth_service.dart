import 'package:supabase_flutter/supabase_flutter.dart';

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
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('user_id', user.id)
          .single();
      return {
        'userEmail': user.email,
        'username': response['username'] as String? ?? 'Guest',
        'userId': user.id
      };
    } catch (e) {
      print('Error fetching username from profiles: $e');
      return {
        'userEmail': user.email,
        'username': user.userMetadata?['username'] as String? ?? 'Guest',
        'userId': user.id
      };
    }
  }
}