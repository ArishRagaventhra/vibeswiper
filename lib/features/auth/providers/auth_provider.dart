import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.data(null)) {
    // Initialize with current user if exists
    final currentUser = SupabaseConfig.currentUser;
    if (currentUser != null) {
      state = AsyncValue.data(currentUser);
    }
  }

  final _supabase = SupabaseConfig.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    try {
      state = const AsyncValue.loading();
      debugPrint('Starting sign up process for email: $email');

      // Step 1: Create auth user with metadata
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Sign up failed: No user returned');
      }

      debugPrint('Auth user created successfully with ID: ${authResponse.user!.id}');

      // Wait briefly for the trigger to create the profile
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify profile exists and update if needed
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', authResponse.user!.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint('Profile not created by trigger, creating manually');
        // Create profile if trigger didn't work
        await _createUserProfile(
          userId: authResponse.user!.id,
          email: email,
          username: username,
          fullName: fullName,
        );
      } else {
        debugPrint('Profile created successfully by trigger');
      }

      state = AsyncValue.data(authResponse.user);
    } catch (error, stackTrace) {
      debugPrint('Error during sign up: $error');
      debugPrint('Stack trace: $stackTrace');
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String username,
    required String fullName,
  }) async {
    try {
      debugPrint('Creating user profile for ID: $userId');
      
      final userData = {
        'id': userId,
        'email': email,
        'username': username,
        'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'role': 'user',
        'is_verified': false,
      };

      await _supabase.from('profiles').upsert(userData);
      debugPrint('User profile created successfully');
      
      // Verify the profile was created
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
          
      debugPrint('Profile verification successful: ${profile['username']}');
      
    } catch (error) {
      debugPrint('Error creating user profile: $error');
      // Attempt to delete the auth user if profile creation fails
      try {
        await _supabase.auth.admin.deleteUser(userId);
      } catch (e) {
        debugPrint('Failed to cleanup auth user after profile creation error: $e');
      }
      throw Exception('Failed to create user profile: $error');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      state = const AsyncValue.loading();
      
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      // Check if this was a deleted account that's being recovered
      final profile = await _supabase
          .from('profiles')
          .select('deleted_at')
          .eq('id', authResponse.user!.id)
          .single();

      if (profile != null && profile['deleted_at'] != null) {
        // Show recovery message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been successfully recovered!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      state = AsyncValue.data(authResponse.user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }

  Future<void> resetPassword(String email) async {
    try {
      state = const AsyncValue.loading();
      debugPrint('Sending password reset email to: $email');
      
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: '${SupabaseConfig.supabaseUrl}/auth/v1/callback',
      );
      
      debugPrint('Password reset email sent successfully');
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      debugPrint('Error sending password reset email: $error');
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      state = const AsyncValue.loading();
      debugPrint('Updating password for current user');
      
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
      
      if (response.user == null) {
        throw Exception('Failed to update password: No user returned');
      }
      
      debugPrint('Password updated successfully');
      state = AsyncValue.data(response.user);
    } catch (error, stackTrace) {
      debugPrint('Error updating password: $error');
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
