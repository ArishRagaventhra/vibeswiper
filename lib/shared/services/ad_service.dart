import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Singleton instance
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Native Ad Unit ID (Replace with test ad unit ID for development)
  final String _adUnitId = 'ca-app-pub-9257197098746508/5199207971';
  
  // Test Ad Unit IDs
  final String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110'; // Google's test native ad unit ID
  
  // Flag to use test ads
  final bool _useTestAds = true; // Set to true temporarily to validate implementation works
  
  String get adUnitId => _useTestAds ? _testAdUnitId : _adUnitId;
  
  bool _isInitialized = false;
  
  // Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final initFuture = MobileAds.instance.initialize();
      await initFuture;
      
      // Explicitly set test device IDs to empty to ensure production mode
      RequestConfiguration requestConfiguration = RequestConfiguration(
        testDeviceIds: [],
      );
      MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      
      debugPrint('AdMob SDK initialized successfully with production credentials');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing AdMob: $e');
    }
  }
  
  // Load a native ad
  Future<NativeAd?> loadNativeAd({
    required Function(NativeAd ad) onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Create ad request with test device IDs explicitly cleared
      final adRequest = const AdRequest(
        keywords: ['event', 'concert', 'entertainment', 'festival'], // Optional keywords
        contentUrl: 'https://vibeswiper.com', // Optional content URL
      );
      
      // Configure the native ad options
      final nativeAdOptions = NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.landscape,
        adChoicesPlacement: AdChoicesPlacement.topRightCorner,
      );
      
      // Create a native ad with enhanced debugging
      debugPrint('Creating NativeAd with ID: $adUnitId');
      final nativeAd = NativeAd(
        adUnitId: adUnitId,
        request: adRequest,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('Native ad loaded successfully: ${ad.responseInfo?.responseId}');
            onAdLoaded(ad as NativeAd);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Native ad failed to load. Error code: ${error.code}, message: ${error.message}, domain: ${error.domain}');
            ad.dispose();
            if (onAdFailedToLoad != null) {
              onAdFailedToLoad(error);
            }
          },
          onAdOpened: (ad) => debugPrint('Native ad opened.'),
          onAdClosed: (ad) => debugPrint('Native ad closed.'),
          onAdClicked: (ad) => debugPrint('Native ad clicked.'),
          onAdImpression: (ad) => debugPrint('Native ad impression.'),
        ),
        nativeAdOptions: nativeAdOptions,
        factoryId: 'listTile',
      );
      
      // Load the ad
      await nativeAd.load();
      return nativeAd;
    } catch (e) {
      debugPrint('Error loading native ad: $e');
      if (onAdFailedToLoad != null) {
        onAdFailedToLoad(LoadAdError(
          0, // code
          'AdService', // domain
          'Error loading native ad: $e', // message
          ResponseInfo(responseExtras: {}, responseId: '', mediationAdapterClassName: '') // responseInfo
        ));
      }
      return null;
    }
  }
}

// Provider for AdService
final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

// Provider for the native ad controller
final nativeAdControllerProvider = StateNotifierProvider<NativeAdController, AsyncValue<NativeAd?>>((ref) {
  final adService = ref.watch(adServiceProvider);
  return NativeAdController(adService);
});

// Controller for Native Ad state management
class NativeAdController extends StateNotifier<AsyncValue<NativeAd?>> {
  final AdService _adService;
  
  NativeAdController(this._adService) : super(const AsyncValue.loading()) {
    loadAd();
  }
  
  Future<void> loadAd() async {
    state = const AsyncValue.loading();
    try {
      final ad = await _adService.loadNativeAd(
        onAdLoaded: (ad) {
          state = AsyncValue.data(ad);
        },
        onAdFailedToLoad: (error) {
          state = AsyncValue.error(error, StackTrace.current);
          // Retry loading after a delay
          Future.delayed(const Duration(minutes: 1), loadAd);
        },
      );
      
      if (ad == null) {
        state = AsyncValue.error('Failed to load ad', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  @override
  void dispose() {
    final ad = state.value;
    if (ad != null) {
      ad.dispose();
    }
    super.dispose();
  }
}

// Widget to display native ad
class NativeAdWidget extends ConsumerWidget {
  final double height;
  final EdgeInsetsGeometry margin;
  
  const NativeAdWidget({
    Key? key,
    this.height = 120,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final adAsync = ref.watch(nativeAdControllerProvider);
    
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: adAsync.when(
        data: (ad) {
          if (ad == null) {
            return const SizedBox.shrink();
          }
          
          return AdWidget(ad: ad);
        },
        loading: () => Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        error: (error, stack) {
          // Don't show error to users, just return empty space
          debugPrint('Error loading ad: $error');
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
