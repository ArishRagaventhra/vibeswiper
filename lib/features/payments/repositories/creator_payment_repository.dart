import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/creator_payment_settings.dart';

class CreatorPaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'creator_payment_settings';

  // Get payment settings for a specific creator
  Future<CreatorPaymentSettings?> getCreatorPaymentSettings(String userId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return CreatorPaymentSettings.fromJson(response);
    } catch (e) {
      debugPrint('Error getting creator payment settings: $e');
      return null;
    }
  }

  // Save or update payment settings
  Future<CreatorPaymentSettings?> saveCreatorPaymentSettings({
    required String userId,
    String? existingId,
    required String upiId,
  }) async {
    try {
      final now = DateTime.now();
      final id = existingId ?? const Uuid().v4();
      
      final data = {
        'id': id,
        'user_id': userId,
        'upi_id': upiId,
        'created_at': existingId == null ? now.toIso8601String() : null,
        'updated_at': now.toIso8601String(),
      };

      // Remove null values to avoid overwriting existing data with nulls
      data.removeWhere((key, value) => value == null);

      if (existingId == null) {
        // Creating new record
        final response = await _supabase
            .from(_tableName)
            .insert(data)
            .select()
            .single();
        
        return CreatorPaymentSettings.fromJson(response);
      } else {
        // Updating existing record
        final response = await _supabase
            .from(_tableName)
            .update(data)
            .eq('id', existingId)
            .select()
            .single();
        
        return CreatorPaymentSettings.fromJson(response);
      }
    } catch (e) {
      debugPrint('Error saving creator payment settings: $e');
      return null;
    }
  }

  // Delete payment settings
  Future<bool> deleteCreatorPaymentSettings(String id) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting creator payment settings: $e');
      return false;
    }
  }

  // Validate UPI ID format
  static bool isValidUpiId(String upiId) {
    // Basic UPI ID validation - username@provider format
    final upiRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$');
    return upiRegex.hasMatch(upiId);
  }

  // Validate IFSC code format
  static bool isValidIfscCode(String ifsc) {
    // IFSC code format validation - 11 characters, first 4 alphabets represent bank
    final ifscRegex = RegExp(r'^[A-Za-z]{4}[0-9]{7}$');
    return ifscRegex.hasMatch(ifsc);
  }
}
