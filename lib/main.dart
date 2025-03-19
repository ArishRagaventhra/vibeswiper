import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/providers/theme_provider.dart';
import 'package:scompass_07/shared/widgets/connectivity_wrapper.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

// Global navigator key for accessing the navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Stream subscription for deep link events
StreamSubscription? _deepLinkSubscription;

// App links instance
AppLinks? _appLinks;

Future<void> main() async {
  // Ensure Flutter is initialized and platform channels are ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize URL strategy for web (removes the hash from URLs)
  AppRoutes.initializeUrlStrategy();
  
  // Enable edge-to-edge display and set system UI mode
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );
  
  // Set default system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Configure platform channel buffer size
  const platform = MethodChannel('flutter/lifecycle');
  ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(platform.name, (message) async {
    return null;
  });
  
  // Initialize Supabase with proper error handling
  try {
    await SupabaseConfig.initialize();
    debugPrint('Supabase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Error initializing Supabase: $e');
    debugPrint('Stack trace: $stackTrace');
    return;
  }
  
  // Initialize deep linking for mobile platforms only
  if (!kIsWeb) {
    await _initializeDeepLinks();
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Extract deep link initialization to a separate method that's only run on mobile
Future<void> _initializeDeepLinks() async {
  if (kIsWeb) return; // Skip on web platforms
  
  try {
    // Initialize AppLinks
    _appLinks = AppLinks();

    // Get the initial link that opened the app (if any)
    final Uri? initialLink = await _appLinks!.getInitialAppLink();
    if (initialLink != null) {
      debugPrint('App opened with deep link: $initialLink');
      _handleDeepLink(initialLink);
    }

    // Listen for app links while the app is running
    _deepLinkSubscription = _appLinks!.uriLinkStream.listen((Uri uri) {
      debugPrint('App received deep link while running: $uri');
      _handleDeepLink(uri);
    }, onError: (error) {
      debugPrint('Error handling deep link: $error');
    });
  } catch (e) {
    debugPrint('Error initializing deep links: $e');
  }
}

// Helper method to handle deep link navigation
void _handleDeepLink(Uri uri) {
  // Check if the URI path matches the expected format
  if (uri.path.startsWith('/events/')) {
    // Extract the event ID
    final String eventId = uri.pathSegments.last;
    
    // Use navigatorKey to navigate to the event details screen
    if (eventId.isNotEmpty) {
      debugPrint('Navigating to event: $eventId');
      // Delay navigation slightly to ensure the app is fully loaded
      Future.delayed(Duration(milliseconds: 300), () {
        navigatorKey.currentState?.pushNamed('/events/$eventId');
      });
    }
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    
    return EdgeToEdgeContainer(
      child: MaterialApp.router(
        title: 'Vibeswiper',
        theme: AppTheme.getLightTheme(),
        darkTheme: AppTheme.getDarkTheme(),
        themeMode: themeMode,
        routerConfig: AppRoutes.router(ref),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            // Apply a scale factor for text based on the platform's text scale factor
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
            ),
            child: ConnectivityWrapper(
              child: child!,
            ),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
