import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/providers/theme_provider.dart';
import 'package:scompass_07/shared/widgets/connectivity_wrapper.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';

Future<void> main() async {
  // Ensure Flutter is initialized and platform channels are ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure URL strategy for web
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  
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
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
