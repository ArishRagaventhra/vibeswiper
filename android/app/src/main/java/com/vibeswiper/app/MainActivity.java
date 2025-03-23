package com.vibeswiper.app;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Register the native ad factory with the 'listTile' factory ID
        // This ID needs to match the one used in the NativeAd constructor in Dart
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, 
            "listTile", 
            new NativeAdFactoryImpl(getContext())
        );
    }

    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
        // Unregister the native ad factory when the engine is cleaned up
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile");
        super.cleanUpFlutterEngine(flutterEngine);
    }
}
