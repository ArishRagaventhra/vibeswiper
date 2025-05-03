import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:scompass_07/services/token_service.dart';

/// Service class to handle Firebase Cloud Messaging (FCM) functionality
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  /// Initialize FCM services
  Future<void> initialize() async {
    debugPrint('Starting FCM initialization...');
    
    // Request permission (iOS and Android 13+)
    final permissionStatus = await _requestPermission();
    debugPrint('FCM Permission status: $permissionStatus');
    
    // Initialize local notifications
    await _initLocalNotifications();
    debugPrint('Local notifications initialized');
    
    // Set up foreground notification handler
    await _setupForegroundNotificationHandler();
    debugPrint('Foreground notification handler set up');
    
    // Set up background/terminated handlers
    _setupBackgroundTerminatedHandlers();
    debugPrint('Background/terminated handlers set up');
    
    // Get and log the FCM token
    final token = await getToken();
    debugPrint('=============================================');
    debugPrint('FCM TOKEN: $token');
    debugPrint('=============================================');
    
    // Set up token refresh listener
    _messaging.onTokenRefresh.listen((String token) {
      debugPrint('FCM token refreshed: $token');
      // Save refreshed token to Supabase
      TokenService().saveFcmToken(token);
    });
    
    debugPrint('FCM initialization complete');
  }
  
  /// Request notification permission
  Future<AuthorizationStatus> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('FCM Permission Status: ${settings.authorizationStatus}');
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('Error requesting FCM permission: $e');
      return AuthorizationStatus.denied;
    }
  }
  
  /// Initialize local notifications for displaying when app is in foreground
  Future<void> _initLocalNotifications() async {
    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // Initialize settings for iOS
    final DarwinInitializationSettings initializationSettingsIOS = 
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    // Combined initialization settings
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response);
      },
    );
    
    // Create high importance notification channel for Android
    await _createNotificationChannel();
  }
  
  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// Set up foreground notification handler
  Future<void> _setupForegroundNotificationHandler() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification!.title}');
        
        // Show local notification
        _showLocalNotification(message);
      }
    });
  }
  
  /// Set up background and terminated notification handlers
  void _setupBackgroundTerminatedHandlers() {
    // Set the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification tap when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification!');
        // Handle the notification tap from terminated state
        _handleTerminatedNotificationTap(message);
      }
    });
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background state via notification!');
      // Handle the notification tap from background state
      _handleBackgroundNotificationTap(message);
    });
  }
  
  /// Show local notification
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;
    
    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android.smallIcon ?? '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }
  
  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    // Parse the payload and handle the tap
    if (response.payload != null) {
      debugPrint('Notification payload: ${response.payload}');
      
      // TODO: Navigate to appropriate screen based on payload
    }
  }
  
  /// Handle notification tap from terminated state
  void _handleTerminatedNotificationTap(RemoteMessage message) {
    // TODO: Navigate to appropriate screen based on message data
    final data = message.data;
    debugPrint('Terminated notification data: $data');
  }
  
  /// Handle notification tap from background state
  void _handleBackgroundNotificationTap(RemoteMessage message) {
    // TODO: Navigate to appropriate screen based on message data
    final data = message.data;
    debugPrint('Background notification data: $data');
  }
  
  /// Get FCM token for the device and save it to Supabase if user is logged in
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('Retrieved FCM token: $token');
      
      if (token != null) {
        try {
          // Save token to Supabase if a user is authenticated
          await TokenService().saveFcmToken(token);
          debugPrint('Token saved to Supabase successfully');
        } catch (e) {
          debugPrint('Error saving FCM token to Supabase: $e');
          // Continue even if token can't be saved to Supabase
          // This way testing can work without the Supabase table
        }
      } else {
        debugPrint('FCM token is null - Firebase may not be properly initialized');
      }
      
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
  
  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
  
  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to initialize Firebase to handle background messages
  // Note: This is done automatically in newer versions of the plugin
  debugPrint('Handling a background message: ${message.messageId}');
}
