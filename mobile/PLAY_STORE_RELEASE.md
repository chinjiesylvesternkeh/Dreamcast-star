# Google Play release

Application ID `com.dreamcast.app` · target SDK 36 · Play Billing Library 9.1.

Everything for Play Console lives in [`../play-store/`](../play-store/):

- `PLAY_CONSOLE_DECLARATIONS.md` — App content answers (Data safety, content
  rating, target audience, ads, app access), subscription products and
  monetization setup
- `STORE_LISTING.md` — name, descriptions, graphics, release notes
- `CLOSED_TESTING.md` — the 12-tester / 14-day closed test and the production
  access application
- `testers.csv` — tester tracker

## Signing

The upload key is at `%USERPROFILE%\.dreamcast-signing\dreamcast-upload.jks`
and its passwords are in `android/key.properties` (git-ignored). **Back up
both files somewhere safe and private** (password manager or encrypted
drive). With Play App Signing, a lost upload key can be reset through Play
support, but it takes days.

## Build the release bundle

The API URL is compiled into the app, so build against the live backend
(HTTPS):

```powershell
cd mobile
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://<your-api-domain>/api/v1
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Each upload needs a higher build number: bump `version` in `pubspec.yaml`
(`1.0.0+1` → `1.0.1+2`).

> This checkout lives under a path with a space (`CHINJIE Sylvester`), which
> breaks Flutter's native-asset build step. Run Flutter through the 8.3 short
> path, e.g. `cd C:\Users\CHINJI~1\Music\DREAM-STAR\dreamcast\mobile` and
> `C:\Users\CHINJI~1\AppData\Local\flutter\bin\flutter.bat build appbundle ...`.

## Optional Firebase notifications

Firebase is bundled but not initialized, so it collects nothing. If you
enable push notifications later, add `android/app/google-services.json`,
initialize Firebase, and update the Data safety form (Device or other IDs).
