# AdMob Native Ads Integration

This document describes how AdMob native ads have been integrated into the Vibe Swiper app.

## Setup Details

### AdMob Credentials
- App ID: `ca-app-pub-9257197098746508~3753010075`
- Native Ad Unit ID: `ca-app-pub-9257197098746508/5199207971`

### Files Added/Modified

1. **Ad Service**
   - `lib/shared/services/ad_service.dart`: Manages ad loading and initialization

2. **Native Ad Factory**
   - `lib/shared/widgets/native_ad_factory.dart`: Custom factory for native ad rendering

3. **Ad Widgets**
   - `lib/features/events/widgets/event_search_ad_item.dart`: Ad widget for event search screen
   - `lib/features/events/widgets/event_card_ad.dart`: Ad widget for Tinder-like event cards

4. **Platform Configuration**
   - Android: Updated `AndroidManifest.xml` with AdMob App ID
   - iOS: Updated `Info.plist` with AdMob App ID and required network identifiers

## Ad Implementation

### Event Search Screen
- Ads appear in the event list after the 4th item
- Maintains the same design style as event list items

### Event List Screen (Tinder Cards)
- Ads appear after every 3 swipes
- Integrated into the card stack with the same card design
- Preserves the Tinder-like swiping experience

## Testing

- For testing purposes, you can set `_useTestAds = true` in `ad_service.dart`
- Test Ad Unit ID: `ca-app-pub-3940256099942544/2247696110` (Google's standard test ID)

## Production Considerations

- Ensure the test ad flag is set to `false` before releasing the app
- Monitor ad performance through the AdMob dashboard
- Ad frequency can be adjusted by modifying:
  - Event search: Index at which ad appears in the list
  - Event cards: Number of swipes before showing an ad

## Known Limitations

- On web platforms, ads are not displayed (AdMob is mobile-only)
- The first ad might take a moment to load on first app launch
