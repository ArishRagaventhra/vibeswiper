import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../config/razorpay_config.dart';

class RazorpayOrderService {
  // Create a singleton instance
  static final RazorpayOrderService _instance = RazorpayOrderService._internal();
  
  factory RazorpayOrderService() {
    return _instance;
  }
  
  RazorpayOrderService._internal();
  
  /// Creates a Razorpay order using the Orders API
  /// This is required for auto-capture to work properly
  Future<Map<String, dynamic>> createOrder({
    required double amount,
    required String currency,
    required String receiptId,
    Map<String, dynamic>? notes,
  }) async {
    try {
      // Razorpay requires amount in smallest currency unit (paise for INR)
      final amountInSmallestUnit = (amount * 100).toInt();
      
      // Prepare the URL and authentication
      final url = Uri.parse('https://api.razorpay.com/v1/orders');
      
      // Create Basic Auth header from key_id:key_secret
      final authString = '${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}';
      final authBytes = utf8.encode(authString);
      final authBase64 = base64.encode(authBytes);
      final headers = {
        'Authorization': 'Basic $authBase64',
        'Content-Type': 'application/json',
      };
      
      // Prepare request body
      final body = jsonEncode({
        'amount': amountInSmallestUnit,
        'currency': currency,
        'receipt': receiptId,
        'notes': notes ?? {},
        'payment_capture': 1, // Auto capture the payment
      });
      
      debugPrint('Creating Razorpay order: $body');
      
      // Make API request
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      
      // Parse response
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Razorpay order created: ${responseData['id']}');
        return responseData;
      } else {
        debugPrint('Error creating Razorpay order: ${response.body}');
        throw Exception('Failed to create order: ${responseData['error']['description']}');
      }
    } catch (e) {
      debugPrint('Error creating Razorpay order: $e');
      rethrow;
    }
  }
}
