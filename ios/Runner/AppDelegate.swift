import Flutter
import UIKit
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register the native ad factory
    let factoryId = "listTile"
    let listTileFactory = ListTileNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self.registrar(forPlugin: "io.flutter.plugins.googlemobileads")!,
        factoryId: factoryId,
        nativeAdFactory: listTileFactory)
        
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    // Unregister the native ad factory when the app terminates
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
        self.registrar(forPlugin: "io.flutter.plugins.googlemobileads")!,
        factoryId: "listTile")
  }
}
