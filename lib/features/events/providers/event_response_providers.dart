import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';

final userProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, username, avatar_url')
        .eq('id', userId)
        .single();
    
    return response;
  } catch (e) {
    return null;
  }
});
