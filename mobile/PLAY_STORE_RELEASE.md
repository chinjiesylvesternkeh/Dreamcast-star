# Google Play release checklist

The app is configured for an Android App Bundle with application ID
`com.dreamcast.app`, target SDK 35, and Play Billing. It is not uploadable
until the release signing and service configuration below are completed.

## Required local setup

1. Install Flutter and Android Studio with Android SDK Platform 35 and build
   tools. Run `flutter doctor` until the Android toolchain is healthy.
2. Create a dedicated upload key:

   ```powershell
   keytool -genkeypair -v -keystore C:\secure\dreamcast-upload-keystore.jks `
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

3. Copy `android/key.properties.example` to `android/key.properties`, fill in
   the credentials and keystore path, and keep both files private.
4. Configure the production API endpoint and build:

   ```powershell
   flutter pub get
   flutter build appbundle --release `
     --dart-define=API_BASE_URL=https://api.dreamcast.app/api/v1
   ```

   The bundle is written to `build/app/outputs/bundle/release/app-release.aab`.

## Google Play Console

1. Create the app with package name `com.dreamcast.app`.
2. Create and activate the subscription product `dreamcast_pro_monthly`.
3. Upload the first AAB to an internal testing track.
4. Add license testers and test signup, dream submission, restore purchases,
   cancelled subscriptions, and payment failures.
5. Register the backend service account with Play Console subscription access,
   then set `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` and
   `GOOGLE_PLAY_PACKAGE_NAME=com.dreamcast.app` on the backend.
6. Configure Real-time Developer Notifications and route them to the backend
   Google Play webhook endpoint.

## Optional Firebase notifications

Push notifications are not initialized by the current app, so Firebase is
optional for the current release. If notifications are enabled later, create
an Android Firebase app for `com.dreamcast.app`, place its
`google-services.json` in `android/app/`, and initialize Firebase before using
messaging. The Gradle plugin is applied automatically only when that file is
present.

## Store listing requirements

Prepare the Play Console privacy policy URL, app icon, feature graphic,
phone screenshots, content rating, Data safety answers, target audience,
and account deletion flow before production submission.