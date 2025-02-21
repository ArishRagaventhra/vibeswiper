import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ulfqstrzcotvubimikzm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVsZnFzdHJ6Y290dnViaW1pa3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE3NDgxMjQsImV4cCI6MjA0NzMyNDEyNH0.DCW0iiXosHFBaiD86zxezlpcnVE6ynC_XwPxkDqhbbo';

  static late final SupabaseClient client;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Supabase already initialized');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 2,
        ),
        debug: kDebugMode,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('Supabase initialization completed successfully');
    } catch (e) {
      debugPrint('Error during Supabase initialization: $e');
      rethrow;
    }
  }

  // Utility methods for common Supabase operations
  static User? get currentUser => client.auth.currentUser;

  static Session? get currentSession => client.auth.currentSession;

  static bool get isAuthenticated => currentUser != null;

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  static Stream<AuthState> authStateChanges() {
    return client.auth.onAuthStateChange;
  }

  // Error handling
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    } else if (error is PostgrestException) {
      return error.message;
    } else {
      return 'An unexpected error occurred';
    }
  }

  // Storage bucket names
  static const String avatarsBucket = 'avatars';
  static const String communityImagesBucket = 'community-images';
  static const String eventImagesBucket = 'event-media';
  static const String postAttachmentsBucket = 'post-attachments';
}
