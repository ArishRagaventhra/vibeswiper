# App Links Configuration

To enable proper App Links functionality for both Android and iOS, follow these hosting instructions:

## For Android App Links

1. Host the `assetlinks.json` file at:
   ```
   https://vibeswiper.scompasshub.com/.well-known/assetlinks.json
   ```

2. Verify it's accessible by opening the URL in a browser. You should see the JSON content.

## For iOS Universal Links

1. Host the `apple-app-site-association` file at:
   ```
   https://vibeswiper.scompasshub.com/.well-known/apple-app-site-association
   ```

2. Before hosting, replace `YOUR_TEAM_ID` in the file with your actual Apple Developer Team ID.

3. Verify it's accessible by opening the URL in a browser. You should see the JSON content.

## Important Notes

- The files MUST be served with Content-Type: `application/json` and without any redirection.
- For iOS, the file shouldn't have any extension when hosted.
- HTTPS is required for both platforms.
- Make sure your web server supports the `.well-known` path.

## Testing App Links

### Android

1. Create a signed APK with:
   ```
   flutter build apk --release
   ```

2. Install the app on your device.

3. Open a browser and navigate to:
   ```
   https://vibeswiper.scompasshub.com/events/123
   ```

4. The app should launch and navigate to the event details screen.

### iOS

1. Create a signed IPA with:
   ```
   flutter build ipa --release
   ```

2. Install the app on your device.

3. Open Safari and navigate to:
   ```
   https://vibeswiper.scompasshub.com/events/123
   ```

4. The app should launch and navigate to the event details screen.
