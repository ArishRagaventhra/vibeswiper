import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final GoRouter router;
  StreamSubscription? _linkSubscription;
  bool _isInitialized = false;
  late AppLinks _appLinks;

  DeepLinkService({required this.router}) {
    _appLinks = AppLinks();
  }

  Future<void> init() async {
    // This method can be called multiple times, but we'll re-init if already initialized
    // to ensure we capture any changes in app startup conditions
    if (_isInitialized) {
      debugPrint('Deep link service already initialized, but reinitializing for robustness');
      _linkSubscription?.cancel(); // Cancel existing subscription to avoid duplicates
    }
    
    // Handle the case when app is started by a link
    if (!kIsWeb) {
      try {
        // Get the initial link that opened the app
        debugPrint('Checking for initial app link');
        final initialUri = await _appLinks.getInitialAppLink();
        if (initialUri != null) {
          debugPrint('🔗 DEEP LINK: App opened with link: $initialUri');
          _handleDeepLink(initialUri);
        } else {
          debugPrint('No initial app link found');
        }
      } on PlatformException catch (e) {
        debugPrint('Failed to get initial app link: ${e.message}');
      } catch (e) {
        debugPrint('Unexpected error getting initial app link: $e');
      }

      // Handle the case when app is already running and a link is opened
      // Only set up the stream listener on mobile platforms
      try {
        _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
          debugPrint('🔗 DEEP LINK: Received while app is running: $uri');
          _handleDeepLink(uri);
        }, onError: (err) {
          debugPrint('App Link stream error: $err');
        });
        debugPrint('URI link stream listener set up successfully');
      } catch (e) {
        debugPrint('Error setting up URI link stream: $e');
      }
    } else {
      // For web platforms, we can handle initial links via window.location.href
      // but we don't need to set up the stream listener as it's not supported
      debugPrint('Deep link service initialized for web (limited functionality)');
    }

    _isInitialized = true;
    debugPrint('App Link service initialization complete ✅');
  }

  void _handleDeepLink(Uri uri) {
    final path = _parseUriToPath(uri);
    if (path.isEmpty) {
      debugPrint('❌ Error: Could not parse valid path from URI: $uri');
      return;
    }
    
    debugPrint('✅ Successfully parsed path: $path from URI: $uri');
    
    // Specific handling for known paths with logging
    if (path.startsWith('/events/')) {
      final eventId = path.substring('/events/'.length);
      debugPrint('📱 Navigating to event details with ID: $eventId');
    } else if (path == '/booking-history') {
      debugPrint('📱 Navigating to booking history');
    }
    
    // Execute navigation with try-catch to identify issues
    try {
      debugPrint('🧭 Attempting to navigate to path: $path');
      router.go(path);
      debugPrint('✅ Navigation appears successful');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      // Fallback to events page if navigation fails
      try {
        debugPrint('⚠️ Attempting fallback navigation to /events');
        router.go('/events');
      } catch (e) {
        debugPrint('💥 Fatal navigation error: $e');
      }
    }
  }

  String _parseUriToPath(Uri uri) {
    // Log the full URI for debugging purposes
    debugPrint('Parsing URI: $uri');
    
    // Handle different URI schemes
    if (uri.scheme == 'vibeswiper') {
      // Handle custom scheme: vibeswiper://events/123
      final path = '/${uri.path}';
      debugPrint('Parsed custom scheme path: $path');
      return path;
    } else if (uri.host == 'vibeswiper.scompasshub.com') {
      // Handle web URL: https://vibeswiper.scompasshub.com/events/123 or with hash fragment
      
      // First check if there's a hash fragment (SPA routing style)
      final hashPath = uri.fragment;
      if (hashPath.isNotEmpty) {
        // If the fragment already starts with /, return it as is
        if (hashPath.startsWith('/')) {
          debugPrint('Found hash route with leading slash: $hashPath');
          return hashPath;
        } else {
          // Otherwise add the leading slash
          debugPrint('Found hash route, adding leading slash: /$hashPath');
          return '/$hashPath';
        }
      }
      
      // If no fragment, use the path
      if (uri.path.isNotEmpty && uri.path != '/') {
        // Process specific paths
        String path = uri.path;
        
        // Check for known paths directly
        if (path.startsWith('/booking-history')) {
          debugPrint('Detected booking-history path: $path');
          return path;
        }
        
        // Check for event path pattern
        if (path.startsWith('/events/')) {
          debugPrint('Detected events path: $path');
          return path;
        }
        
        debugPrint('Using path from URL: $path');
        return path;
      }
      
      // If we get here, both fragment and path are empty, so return home
      debugPrint('No path or fragment found, returning home route');
      return '/';
    } else if (kDebugMode && (uri.host == 'localhost' || uri.host.contains('127.0.0.1'))) {
      // Handle local development URL
      final hashPath = uri.fragment;
      if (hashPath.isNotEmpty) {
        // If the fragment already starts with /, return it as is
        if (hashPath.startsWith('/')) {
          return hashPath;
        } else {
          // Otherwise add the leading slash
          return '/$hashPath'; 
        }
      }
      return uri.path;
    }
    
    // If no pattern matched, log error and return empty
    debugPrint('WARNING: No pattern matched for URI: $uri');
    return '';
  }

  // Generate shareable links for different platforms
  String generateShareableLink(String path) {
    // Remove leading slash if present
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // Ensure path is not empty to avoid double slashes
    final pathSegment = path.isEmpty ? '' : '/$path';
    
    // Debug output to see what URLs are being generated
    final url = 'https://vibeswiper.scompasshub.com$pathSegment';
    debugPrint('Generated shareable link: $url');
    
    if (kIsWeb) {
      // Web platform - use the current origin or the production URL
      return url;
    } else {
      // For App Links/Universal Links, use HTTPS URL instead of custom scheme
      return url;
      // Keep the custom scheme for backwards compatibility with older versions
      // return 'vibeswiper://$path';
    }
  }

  // Generate a deep link for a specific event
  String generateEventLink(String eventId) {
    return generateShareableLink('events/$eventId');
  }

  // Generate a deep link for user profile
  String generateProfileLink(String userId) {
    return generateShareableLink('profile/$userId');
  }

  // Generate a deep link for any other screen based on path segments
  String generateScreenLink(List<String> pathSegments) {
    return generateShareableLink(pathSegments.join('/'));
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
