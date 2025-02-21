import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/profile/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider for the current user's profile
final currentProfileProvider = StateNotifierProvider<CurrentProfileNotifier, AsyncValue<Profile?>>((ref) {
  return CurrentProfileNotifier();
});

// Provider for any user's profile (including current user)
final profileProvider = StateNotifierProvider.family<ProfileNotifier, AsyncValue<Profile?>, String>((ref, userId) {
  return ProfileNotifier(userId);
});

// Base profile notifier with shared functionality
abstract class BaseProfileNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final _supabase = SupabaseConfig.client;
  final _imagePicker = ImagePicker();
  StreamSubscription? _profileSubscription;

  BaseProfileNotifier() : super(const AsyncValue.loading()) {
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription?.cancel();
    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              state = AsyncValue.data(Profile.fromJson(data.first));
            }
          },
          onError: (error) {
            debugPrint('Error in profile subscription: $error');
          },
        );
  }

  Future<void> fetchProfile(String targetUserId) async {
    try {
      if (targetUserId.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _fetchProfile(targetUserId);

      if (profile == null) {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      debugPrint('Error fetching profile: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<Profile?> _fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      return Profile.fromJson(data);
    } catch (error) {
      debugPrint('Error in _fetchProfile: $error');
      rethrow;
    }
  }

  Future<String> _uploadImage(XFile image) async {
    try {
      final filename = path.basename(image.path);
      final ext = path.extension(filename).toLowerCase();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      String contentType;
      switch (ext) {
        case '.jpg':
        case '.jpeg':
          contentType = 'image/jpeg';
          break;
        case '.png':
          contentType = 'image/png';
          break;
        case '.gif':
          contentType = 'image/gif';
          break;
        case '.webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'image/jpeg';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'avatars/${userId}_$timestamp$ext';

      debugPrint('Uploading image to profile-images bucket: $storagePath');

      Uint8List bytes;
      if (kIsWeb) {
        bytes = await image.readAsBytes();
      } else {
        bytes = await File(image.path).readAsBytes();
      }

      await _supabase.storage.from('profile-images').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final imageUrl = _supabase.storage
          .from('profile-images')
          .getPublicUrl(storagePath);

      // Add cache-busting parameter to force refresh
      return '$imageUrl?v=$timestamp';
    } catch (error) {
      debugPrint('Error uploading image: $error');
      rethrow;
    }
  }

  Future<void> updateAvatar() async {
    try {
      state = const AsyncValue.loading();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        state = await AsyncValue.guard(() => _fetchProfile(userId));
        return;
      }

      final imageUrl = await _uploadImage(image);

      await _supabase
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);

      // Force immediate refresh of profile data
      final updatedProfile = await _fetchProfile(userId);
      if (updatedProfile != null) {
        state = AsyncValue.data(updatedProfile);
      }
    } catch (error, stackTrace) {
      debugPrint('Error updating avatar: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}

// Notifier for current user's profile
class CurrentProfileNotifier extends BaseProfileNotifier {
  CurrentProfileNotifier() {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId != null) {
      fetchProfile(userId);
    }
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? website,
  }) async {
    try {
      state = const AsyncValue.loading();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final updates = {
        if (username != null) 'username': username,
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (website != null) 'website': website,
      };

      if (updates.isEmpty) return;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      state = await AsyncValue.guard(() => _fetchProfile(userId));
    } catch (error, stackTrace) {
      debugPrint('Error updating profile: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Notifier for other user's profiles
class ProfileNotifier extends BaseProfileNotifier {
  final String userId;

  ProfileNotifier(this.userId) {
    fetchProfile(userId);
  }
}
