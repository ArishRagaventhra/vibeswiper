import 'package:flutter/foundation.dart';

class RazorpayConfig {
  static const String _testKeyId = 'rzp_test_rvXfh2uxQhmN89';
  static const String _testKeySecret = 'MN6xbX0sRtgPB9K8QnojHcsj';
  
  static const String _liveKeyId = 'rzp_live_kFvwYgunb3NIEl';
  static const String _liveKeySecret = 'oLCPQrux1wDR7cAPCx8JNNip';

  // Use live keys in release mode, test keys in debug mode
  static String get keyId => kReleaseMode ? _liveKeyId : _testKeyId;
  static String get keySecret => kReleaseMode ? _liveKeySecret : _testKeySecret;

  // Constants for payment
  static const double PLATFORM_LISTING_FEE = 499.0; // Standard platform fee for listing paid events (₹499)
  static const String CURRENCY = 'INR';
  
  // Method to calculate the payment amount for event creation
  static double calculatePaymentAmount(double? vibePrice) {
    if (vibePrice == null || vibePrice <= 0) {
      return 0.0; // Free events have no fee
    }
    return PLATFORM_LISTING_FEE; // Use the standard platform fee (₹499) for all paid events
  }
  
  // Payment description text
  static String getPaymentDescription(String eventName) {
    return 'Platform fee for listing paid event: $eventName';
  }
}
