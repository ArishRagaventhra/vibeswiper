import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Profile model to represent user profile data
class UserProfile {
  final String id;
  final String username;
  final String? fullName;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final bool isVerified;
  final DateTime? lastSeen;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.isVerified,
    this.lastSeen,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      isVerified: json['is_verified'] ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_verified': isVerified,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

final currentProfileProvider = StateNotifierProvider<CurrentProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  final authState = ref.watch(authProvider);
  return CurrentProfileNotifier(authState.value?.id);
});

class CurrentProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final String? _userId;
  Timer? _debounceTimer;
  StreamSubscription? _profileSubscription;

  CurrentProfileNotifier(this._userId) : super(const AsyncValue.loading()) {
    if (_userId != null) {
      _loadProfile();
      _subscribeToProfileChanges();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  void _subscribeToProfileChanges() {
    if (_userId == null) return;
    
    _profileSubscription?.cancel();
    _profileSubscription = SupabaseConfig.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId!)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            state = AsyncValue.data(UserProfile.fromJson(data.first));
          }
        });
  }

  Future<void> _loadProfile() async {
    if (_userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .single();
      
      if (response != null) {
        state = AsyncValue.data(UserProfile.fromJson(response));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_userId == null) return;

    try {
      state = const AsyncValue.loading();
      
      final updates = <String, Object>{};
      
      if (username != null) updates['username'] = username;
      if (fullName != null) updates['full_name'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) return;

      // Cancel any pending debounce timer
      _debounceTimer?.cancel();

      await SupabaseConfig.client
          .from('profiles')
          .update(updates)
          .eq('id', _userId!);

      // Immediately load the updated profile
      await _loadProfile();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}

// Provider to fetch a profile by specific user ID
final profileByIdProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    
    return response != null ? UserProfile.fromJson(response) : null;
  } catch (error) {
    print('Error fetching profile for user $userId: $error');
    return null;
  }
});
