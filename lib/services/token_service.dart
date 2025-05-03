import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle FCM token management with Supabase
class TokenService {
  static final TokenService _instance = TokenService._internal();
  final _supabase = Supabase.instance.client;
  
  factory TokenService() => _instance;
  TokenService._internal();

  /// Save FCM token to Supabase for the current user
  ///
  /// This associates the FCM token with the user in the database
  /// so they can receive targeted notifications
  Future<void> saveFcmToken(String token) async {
    try {
      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        debugPrint('Cannot save FCM token: No authenticated user');
        return;
      }
      
      // Check if a record for this user & token already exists
      final existingData = await _supabase
          .from('device_tokens')
          .select()
          .eq('user_id', userId)
          .eq('token', token);
          
      if (existingData.isNotEmpty) {
        debugPrint('FCM token already exists for this user');
        return;
      }
      
      // Insert the new token
      await _supabase.from('device_tokens').insert({
        'user_id': userId,
        'token': token,
        'device_type': _getPlatformType(),
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true
      });
      
      debugPrint('FCM token saved successfully');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
  
  /// Remove FCM token from Supabase for the current user
  ///
  /// This should be called on logout to stop receiving notifications
  Future<void> removeFcmToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        debugPrint('Cannot remove FCM token: No authenticated user');
        return;
      }
      
      // Soft delete by setting is_active to false
      await _supabase
          .from('device_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('token', token);
          
      debugPrint('FCM token removed successfully');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }
  
  /// Get all active FCM tokens for a specific user
  Future<List<String>> getUserTokens(String userId) async {
    try {
      final response = await _supabase
          .from('device_tokens')
          .select('token')
          .eq('user_id', userId)
          .eq('is_active', true);
          
      return List<String>.from(response.map((item) => item['token']));
    } catch (e) {
      debugPrint('Error getting user tokens: $e');
      return [];
    }
  }
  
  /// Get device platform type
  String _getPlatformType() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    } else {
      return 'web';
    }
  }
}
