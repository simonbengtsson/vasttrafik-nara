# Västtrafik Nära
---

Nearby stops, departures and journeys for västtrafik

App Store: https://itunes.apple.com/gb/app/arctic-tern/id1439743742?mt=8

Google Play: https://play.google.com/store/apps/details?id=com.simonbengtsson.arctictern

![Screenshot](https://is5-ssl.mzstatic.com/image/thumb/Purple128/v4/0a/75/55/0a755505-f237-7894-201d-7cf30bc9e023/pr_source.png/460x0w.png)

### Development
- Clone and `flutter pub get` and `cd ios && pod install`
- Create a env.dart from env.dart.sample
- Open main.dart and choose run (or run from xcode etc)


### Publish iOS
- Update pubspec.yaml version number
- flutter build ipa
- Open archive in xcode and distribute

### Publish Android
- Create or verify key.properties content
- Update pubspec.yaml version number
- flutter build apk
- Create new release with apk in Google Play Console (Production -> New Release)

### Publish macos
- Update pubspec.yaml version number
- flutter build macos
- Archive in xcode