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
  static const double PLATFORM_LISTING_FEE = 0.0; // Free events have no fee
  static const String CURRENCY = 'INR';
  
  // For backward compatibility - keeping this constant but it's no longer used in new code
  static const double EVENT_CREATION_FEE = 499.0; // Rs. 499 - Legacy constant (deprecated)
  
  // Method to calculate the payment amount based on vibe price
  static double calculatePaymentAmount(double? vibePrice) {
    if (vibePrice == null || vibePrice <= 0) {
      return 0.0; // Free events have no fee
    }
    return vibePrice; // Use the vibe price for paid events
  }
}
