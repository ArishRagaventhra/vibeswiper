import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:scompass_07/services/token_service.dart';

/// Service to handle sending FCM notifications
/// This is a simplified version for testing - in production,
/// notifications should be sent from your secure backend
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Your Firebase server key (this should be stored securely in a backend)
  // In a production app, this should NOT be in client-side code
  // This is only for testing purposes
  final String _serverKey = 'YOUR_FIREBASE_SERVER_KEY';
  final String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  /// Send a notification to a specific user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM tokens
      final tokens = await TokenService().getUserTokens(userId);
      
      if (tokens.isEmpty) {
        debugPrint('No active tokens found for user: $userId');
        return false;
      }
      
      // Send notifications to all user devices
      bool anySuccess = false;
      for (final token in tokens) {
        final success = await _sendNotification(
          token: token,
          title: title,
          body: body,
          data: data,
        );
        
        if (success) anySuccess = true;
      }
      
      return anySuccess;
    } catch (e) {
      debugPrint('Error sending notification to user: $e');
      return false;
    }
  }

  /// Send notification to a specific topic
  Future<bool> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _sendNotification(
        to: '/topics/$topic',
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('Error sending notification to topic: $e');
      return false;
    }
  }

  /// Send notification to multiple devices
  Future<bool> sendNotificationToDevices({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return false;
    
    try {
      return await _sendNotification(
        registration_ids: tokens,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('Error sending notification to devices: $e');
      return false;
    }
  }

  /// Private method to send the actual notification
  Future<bool> _sendNotification({
    String? token,
    String? to,
    List<String>? registration_ids,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Ensure at least one targeting parameter is provided
      if (token == null && to == null && (registration_ids == null || registration_ids.isEmpty)) {
        throw ArgumentError('Either token, topic or registration_ids must be provided');
      }
      
      // Build the FCM payload
      final Map<String, dynamic> notification = {
        'title': title,
        'body': body,
        'sound': 'default',
      };
      
      final Map<String, dynamic> payload = {
        'notification': notification,
        'priority': 'high',
        'data': data ?? {},
      };
      
      // Add the appropriate targeting parameter
      if (token != null) {
        payload['to'] = token;
      } else if (to != null) {
        payload['to'] = to;
      } else if (registration_ids != null) {
        payload['registration_ids'] = registration_ids;
      }
      
      // Convert the payload to JSON
      final String jsonPayload = jsonEncode(payload);
      
      // Send the HTTP request
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonPayload,
      );
      
      // Log the response
      debugPrint('FCM Response: ${response.statusCode} - ${response.body}');
      
      // Check if the request was successful
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error in _sendNotification: $e');
      return false;
    }
  }
}
