import 'package:flutter/foundation.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/events/chat/models/payment_type.dart';

enum PaymentInteractionType {
  qrCodeScan,
  linkClick
}

class PaymentAnalytics {
  final String id;
  final String eventId;
  final String? userId;
  final DateTime timestamp;
  final PaymentType paymentType;
  final PaymentInteractionType interactionType;
  final String? paymentInfo; // UPI ID or payment URL

  PaymentAnalytics({
    required this.id,
    required this.eventId,
    this.userId,
    required this.timestamp,
    required this.paymentType,
    required this.interactionType,
    this.paymentInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'payment_type': paymentType.name,
      'interaction_type': interactionType.name,
      'payment_info': paymentInfo,
    };
  }

  factory PaymentAnalytics.fromMap(Map<String, dynamic> map) {
    return PaymentAnalytics(
      id: map['id'],
      eventId: map['event_id'],
      userId: map['user_id'],
      timestamp: DateTime.parse(map['timestamp']),
      paymentType: PaymentType.values.firstWhere(
        (type) => type.name == map['payment_type'],
        orElse: () => PaymentType.upi,
      ),
      interactionType: PaymentInteractionType.values.firstWhere(
        (type) => type.name == map['interaction_type'],
        orElse: () => PaymentInteractionType.linkClick,
      ),
      paymentInfo: map['payment_info'],
    );
  }
}

class PaymentAnalyticsService {
  // Track when a user interacts with a payment method (QR scan or link click)
  static Future<void> trackPaymentInteraction({
    required String eventId,
    required PaymentType paymentType,
    required PaymentInteractionType interactionType,
    String? paymentInfo,
  }) async {
    try {
      // Get current user if authenticated
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      
      // Insert analytics data into Supabase
      await SupabaseConfig.client.from('payment_analytics').insert({
        'event_id': eventId,
        'user_id': userId,
        'payment_type': paymentType.name,
        'interaction_type': interactionType.name,
        'payment_info': paymentInfo,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Payment interaction tracked: $paymentType - $interactionType');
    } catch (e) {
      // Silent fail for analytics - should not interrupt user experience
      debugPrint('Failed to track payment interaction: $e');
    }
  }

  // Get analytics for an event
  static Future<List<PaymentAnalytics>> getEventPaymentAnalytics(String eventId) async {
    try {
      final response = await SupabaseConfig.client
          .from('payment_analytics')
          .select()
          .eq('event_id', eventId)
          .order('timestamp', ascending: false);
      
      return (response as List)
          .map((data) => PaymentAnalytics.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('Failed to get payment analytics: $e');
      return [];
    }
  }

  // Get analytics summary for an event
  static Future<Map<String, int>> getEventAnalyticsSummary(String eventId) async {
    try {
      final analytics = await getEventPaymentAnalytics(eventId);
      
      // Count interactions by type - only focusing on link clicks
      int linkClicks = analytics.where((a) => 
          a.interactionType == PaymentInteractionType.linkClick).length;
      
      // Count by payment type
      int upiInteractions = analytics.where((a) => 
          a.paymentType == PaymentType.upi).length;
      
      int razorpayInteractions = analytics.where((a) => 
          a.paymentType == PaymentType.razorpay).length;
      
      return {
        'total_interactions': linkClicks, // Total is now just link clicks
        'link_clicks': linkClicks,
        'upi_interactions': upiInteractions,
        'razorpay_interactions': razorpayInteractions,
      };
    } catch (e) {
      debugPrint('Failed to get analytics summary: $e');
      return {
        'total_interactions': 0,
        'link_clicks': 0,
        'upi_interactions': 0,
        'razorpay_interactions': 0,
      };
    }
  }
}
