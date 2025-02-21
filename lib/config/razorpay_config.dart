import 'package:flutter/foundation.dart';

class RazorpayConfig {
  static const String _testKeyId = 'rzp_test_rvXfh2uxQhmN89';
  static const String _testKeySecret = 'MN6xbX0sRtgPB9K8QnojHcsj';
  
  static const String _liveKeyId = 'rzp_live_kFvwYgunb3NIEl';
  static const String _liveKeySecret = 'oLCPQrux1wDR7cAPCx8JNNip';

  // Use live keys in release mode, test keys in debug mode
  static String get keyId => kReleaseMode ? _liveKeyId : _testKeyId;
  static String get keySecret => kReleaseMode ? _liveKeySecret : _testKeySecret;

  // Constants for event creation
  static const double EVENT_CREATION_FEE = 99.0; // Rs. 99 - Platform fee for creating an event
  static const String CURRENCY = 'INR';
}
