import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/notifications/models/notification_item.dart';

class NotificationsService {
  final _supabase = Supabase.instance.client;
  final _notificationController = StreamController<NotificationItem>.broadcast();

  Stream<NotificationItem> get onNotification => _notificationController.stream;

  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      debugPrint('Fetching notifications for user: ${_supabase.auth.currentUser?.id}');
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _supabase.auth.currentUser?.id ?? '')
          .order('created_at', ascending: false);

      final notifications = (response as List<dynamic>);
      debugPrint('Raw notifications response: $response');

      return notifications.map((notification) {
        final avatarUrl = notification['sender_avatar_url'];
        debugPrint('Processing notification: ${notification['id']}');
        debugPrint('Avatar URL from database: $avatarUrl');
        
        if (avatarUrl != null) {
          final bool isValidUrl = avatarUrl.toString().isNotEmpty && 
              (avatarUrl.toString().startsWith('http://') || 
               avatarUrl.toString().startsWith('https://'));
          debugPrint('Is valid avatar URL: $isValidUrl');
          
          if (!isValidUrl) {
            debugPrint('Invalid avatar URL format: $avatarUrl');
            notification['sender_avatar_url'] = null;
          }
        }
        
        final notificationItem = NotificationItem.fromJson(notification);
        debugPrint('Final avatar URL in notification item: ${notificationItem.senderAvatarUrl}');
        
        return notificationItem;
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Error in fetchNotifications: $e');
      debugPrint('Stack trace: $stackTrace');
      throw 'Failed to fetch notifications: ${e.toString()}';
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', _supabase.auth.currentUser?.id ?? '');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      throw 'Failed to mark notification as read: ${e.toString()}';
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _supabase.auth.currentUser?.id ?? '');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      throw 'Failed to mark all notifications as read: ${e.toString()}';
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', _supabase.auth.currentUser?.id ?? '');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      throw 'Failed to delete notification: ${e.toString()}';
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', _supabase.auth.currentUser?.id ?? '');
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
      throw 'Failed to clear all notifications: ${e.toString()}';
    }
  }

  void dispose() {
    _notificationController.close();
  }
}
