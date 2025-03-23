import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:scompass_07/shared/services/ad_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class EventCardAd extends ConsumerStatefulWidget {
  const EventCardAd({Key? key}) : super(key: key);

  @override
  ConsumerState<EventCardAd> createState() => _EventCardAdState();
}

class _EventCardAdState extends ConsumerState<EventCardAd> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadAd();
      // Add timeout to prevent infinite loading
      _loadingTimeout = Timer(const Duration(seconds: 15), () {
        if (!_isAdLoaded && mounted) {
          setState(() {
            _isAdFailed = true;
          });
          // Try to reload the ad after timeout
          _retryLoadAd();
        }
      });
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _loadingTimeout?.cancel();
    super.dispose();
  }

  // Retry mechanism for ad loading
  void _retryLoadAd() {
    debugPrint('Retrying ad load...');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadAd();
      }
    });
  }

  void _loadAd() {
    // Skip loading ads on web platform
    if (kIsWeb) return;
    
    debugPrint('Attempting to load native ad...');
    final adService = ref.read(adServiceProvider);
    
    adService.loadNativeAd(
      onAdLoaded: (ad) {
        _loadingTimeout?.cancel();
        if (mounted) {
          setState(() {
            _nativeAd = ad;
            _isAdLoaded = true;
            _isAdFailed = false;
          });
          debugPrint('Native ad loaded successfully');
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('Native ad failed to load: ${error.message}. Code: ${error.code}');
        _loadingTimeout?.cancel();
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _isAdFailed = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    // Return empty container on web platform
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 320, // Fixed height works better with AdMob
        width: size.width * 0.9,
        color: theme.colorScheme.surface,
        child: _isAdLoaded && _nativeAd != null 
          ? AdWidget(ad: _nativeAd!)
          : _isAdFailed
            ? Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Advertisement',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load ad content',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          debugPrint('Manually retrying ad load...');
                          setState(() {
                            _isAdFailed = false;
                          });
                          _loadAd();
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Advertisement',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
