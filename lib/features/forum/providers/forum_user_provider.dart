import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/current_profile_provider.dart';

// Cache user profiles to avoid repeated fetches
final forumUserProfileProvider = AsyncNotifierProviderFamily<ForumUserProfileNotifier, UserProfile?, String>(() {
  return ForumUserProfileNotifier();
});

class ForumUserProfileNotifier extends FamilyAsyncNotifier<UserProfile?, String> {
  @override
  Future<UserProfile?> build(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      if (data == null) return null;
      
      return UserProfile(
        id: data['id'],
        username: data['username'],
        fullName: data['full_name'],
        email: data['email'],
        avatarUrl: data['avatar_url'],
        bio: data['bio'],
        isVerified: data['is_verified'] ?? false,
        lastSeen: data['last_seen'] != null ? DateTime.parse(data['last_seen']) : null,
        createdAt: DateTime.parse(data['created_at']),
      );
    } catch (e) {
      return null;
    }
  }
}
