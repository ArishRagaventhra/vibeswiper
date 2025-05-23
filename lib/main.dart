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
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:scompass_07/shared/services/ad_service.dart';
import 'package:scompass_07/shared/widgets/native_ad_factory.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scompass_07/services/fcm_service.dart';
import 'package:scompass_07/services/deep_link_service.dart';


// Global navigator key for accessing the navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensure Flutter is initialized and platform channels are ready
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // Only initialize Firebase on non-web platforms since FCM is only needed for mobile
  if (!kIsWeb) {
    try {
      debugPrint('Starting Firebase initialization...');
      
      // Initialize Firebase for mobile
      await Firebase.initializeApp();
      debugPrint('Firebase core initialized successfully');
      
      // Initialize FCM service
      final fcmService = FCMService();
      await fcmService.initialize();
      
      // Get FCM token again and print it for debugging
      final token = await fcmService.getToken();
      debugPrint('============= FIREBASE TOKEN FOR TESTING ===============');
      debugPrint('FCM TOKEN: $token');
      debugPrint('=======================================================');
      
      debugPrint('Firebase and FCM service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing Firebase/FCM: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Initialize Google Mobile Ads SDK
  if (!kIsWeb) {
    // Initialize AdMob for mobile platforms only
    await MobileAds.instance.initialize();
    
    // Explicitly initialize AdService
    final adService = AdService();
    await adService.initialize();
    
    // Note: Native ad factories should be registered in platform-specific code
    // Android: MainActivity.java
    // iOS: AppDelegate.swift
  }
  
  // Initialize Supabase with proper error handling
  try {
    await SupabaseConfig.initialize();
    debugPrint('Supabase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Error initializing Supabase: $e');
    debugPrint('Stack trace: $stackTrace');
    return;
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  // Flag to prevent multiple initialization attempts
  bool _deepLinksInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize deep link service properly with proper sequencing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeepLinks();
    });
  }
  
  Future<void> _initializeDeepLinks() async {
    // Prevent multiple initialization attempts
    if (_deepLinksInitialized) return;
    _deepLinksInitialized = true;
    
    // Log initialization start
    debugPrint('🔄 Starting deep link service initialization...');
    
    try {
      // Ensure all initialization is complete before handling deep links
      // This delay helps ensure GoRouter is fully ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Now initialize deep links
      debugPrint('🚀 Initializing deep link service');
      await ref.read(deepLinkServiceProvider).init();
      debugPrint('✅ Deep link service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing deep links: $e');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, re-initialize deep links
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed, re-initializing deep link service');
      ref.read(deepLinkServiceProvider).init();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
