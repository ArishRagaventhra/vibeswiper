package com.vibeswiper.app;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.graphics.Color;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import com.google.android.gms.ads.nativead.MediaView;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory;
import java.util.Map;

/**
 * Implementation of Native Ad Factory for Android
 * This creates native ad views that match the app's design
 */
public class NativeAdFactoryImpl implements NativeAdFactory {
    private final Context context;

    public NativeAdFactoryImpl(Context context) {
        this.context = context;
    }

    @Override
    public NativeAdView createNativeAd(
            NativeAd nativeAd, Map<String, Object> customOptions) {
        
        NativeAdView adView = new NativeAdView(context);
        
        // Use a simpler layout structure with better compatibility
        LinearLayout adLayout = new LinearLayout(context);
        adLayout.setOrientation(LinearLayout.VERTICAL);
        adLayout.setPadding(20, 20, 20, 20);
        adLayout.setBackgroundColor(Color.parseColor("#1F1F1F"));
        
        // Create headline text view
        TextView headlineView = new TextView(context);
        headlineView.setTextColor(Color.WHITE);
        headlineView.setTextSize(18);
        headlineView.setPadding(0, 0, 0, 10);
        
        // Create media view for images/videos
        MediaView mediaView = new MediaView(context);
        LinearLayout.LayoutParams mediaParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 
                dpToPx(context, 180));
        mediaView.setLayoutParams(mediaParams);
        
        // Create body text view
        TextView bodyView = new TextView(context);
        bodyView.setTextColor(Color.LTGRAY);
        bodyView.setTextSize(14);
        bodyView.setPadding(0, 10, 0, 10);
        
        // Create call to action button
        Button callToActionButton = new Button(context);
        callToActionButton.setBackgroundColor(Color.parseColor("#2196F3"));
        callToActionButton.setTextColor(Color.WHITE);
        callToActionButton.setPadding(20, 10, 20, 10);
        
        // Add all views to the layout
        adLayout.addView(headlineView);
        adLayout.addView(mediaView);
        adLayout.addView(bodyView);
        adLayout.addView(callToActionButton);
        
        // Set layout params for main layout
        LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        
        // Add the layout to the ad view
        adView.addView(adLayout, layoutParams);
        
        // Set the native ad's assets to the created views
        adView.setHeadlineView(headlineView);
        adView.setMediaView(mediaView);
        adView.setBodyView(bodyView);
        adView.setCallToActionView(callToActionButton);
        
        // Populate the native ad views with content
        if (nativeAd.getHeadline() != null) {
            ((TextView) adView.getHeadlineView()).setText(nativeAd.getHeadline());
        }
        
        if (nativeAd.getBody() != null) {
            ((TextView) adView.getBodyView()).setText(nativeAd.getBody());
        } else {
            adView.getBodyView().setVisibility(View.INVISIBLE);
        }
        
        if (nativeAd.getCallToAction() != null) {
            ((Button) adView.getCallToActionView()).setText(nativeAd.getCallToAction());
        } else {
            adView.getCallToActionView().setVisibility(View.INVISIBLE);
        }
        
        // Associate the native ad with the view
        adView.setNativeAd(nativeAd);
        
        return adView;
    }
    
    // Helper method to convert dp to pixels
    private static int dpToPx(Context context, int dp) {
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }
}
