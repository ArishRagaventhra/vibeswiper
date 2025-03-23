import Flutter
import GoogleMobileAds

class ListTileNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: GADNativeAd,
                      customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView? {
        // Create a native ad view
        let nibView = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first
        guard let nativeAdView = nibView as? GADNativeAdView else {
            // In a real implementation, you would return a proper GADNativeAdView here
            // For now, let's create a simple one programmatically
            let adView = GADNativeAdView()
            
            // Create and configure headline view
            let headlineView = UILabel()
            headlineView.text = nativeAd.headline
            adView.headlineView = headlineView
            adView.addSubview(headlineView)
            
            // Configure layout constraints for headlineView
            headlineView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                headlineView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
                headlineView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
                headlineView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10)
            ])
            
            // You would add more ad elements here in a full implementation
            
            return adView
        }
        
        // Set up required ad elements
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        
        // Set up other ad elements like body, icon, call to action, etc.
        if let bodyView = nativeAdView.bodyView as? UILabel {
            bodyView.text = nativeAd.body
            bodyView.isHidden = nativeAd.body == nil
        }
        
        if let iconView = nativeAdView.iconView as? UIImageView {
            iconView.image = nativeAd.icon?.image
            iconView.isHidden = nativeAd.icon == nil
        }
        
        if let callToActionView = nativeAdView.callToActionView as? UIButton {
            callToActionView.setTitle(nativeAd.callToAction, for: .normal)
            callToActionView.isHidden = nativeAd.callToAction == nil
        }
        
        // Associate the native ad with the view
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
}
