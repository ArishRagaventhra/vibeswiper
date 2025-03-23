import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:scompass_07/shared/services/ad_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class EventSearchAdItem extends ConsumerStatefulWidget {
  const EventSearchAdItem({Key? key}) : super(key: key);

  @override
  ConsumerState<EventSearchAdItem> createState() => _EventSearchAdItemState();
}

class _EventSearchAdItemState extends ConsumerState<EventSearchAdItem> {
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
      _loadingTimeout = Timer(const Duration(seconds: 10), () {
        if (!_isAdLoaded && mounted) {
          setState(() {
            _isAdFailed = true;
          });
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

  void _loadAd() {
    // Skip loading ads on web platform
    if (kIsWeb) return;
    
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
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('Native ad failed to load: ${error.message}');
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
    
    // Return empty container on web platform
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isAdLoaded && _nativeAd != null 
        ? AdWidget(ad: _nativeAd!)
        : _isAdFailed
          ? Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advertisement',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isAdFailed = false;
                            });
                            _loadAd();
                          },
                          child: const Text('Try Again'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(80, 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
    );
  }
}
