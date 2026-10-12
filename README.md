# IQ Training app

Flutter app for Android and iOS that wraps the learner area of iqtraining.co.uk:
native bottom tabs (My Courses, Dashboard, Help), persistent login, certificate
downloads, pull to refresh and an offline screen. Course sales pages are kept
out of the app; the printed certificate can be ordered in it.

This code has not been compiled yet. It was written against the
flutter_inappwebview 6.1 API, but the first `flutter analyze` and device run
happen on your machine.

## 1. Create the platform folders

Needs Flutter 3.24 or newer. In this folder:

    flutter create --org uk.co.iqtraining --project-name iq_training --platforms android,ios .
    flutter pub get
    flutter analyze
    flutter test

`flutter create` adds `android/` and `ios/` and leaves the existing files alone.
The app IDs come out as `uk.co.iqtraining.iq_training` (Android) and
`uk.co.iqtraining.iqTraining` (iOS). Change `--org` first if IQ Training wants
something else, because the ID cannot change after the first store release.

## 2. Platform edits

**android/app/src/main/AndroidManifest.xml**

- Above `<application>` add
  `<uses-permission android:name="android.permission.INTERNET"/>`.
  Without it the release build shows a blank page (debug builds add it for you).
- Set `android:label="IQ Training"`.

**ios/Runner/Info.plist**

- Set `CFBundleDisplayName` to `IQ Training`.
- Add the strings below. The file picker for uploads offers the camera, and iOS
  closes the app if they are missing.

      <key>NSCameraUsageDescription</key>
      <string>Take a photo to upload to your course.</string>
      <key>NSPhotoLibraryUsageDescription</key>
      <string>Choose a photo to upload to your course.</string>
      <key>NSMicrophoneUsageDescription</key>
      <string>Record video to upload to your course.</string>

## 3. Settings to check in lib/config.dart

- `brandColor` is a placeholder navy. Replace it with the IQ Training colour.
- `tabs` and `startPath` use `/user-dashboard/my-courses/`, `/user-dashboard/`
  and `/frequently-asked-questions/`.
- `inAppHosts` lists payment providers that must stay inside the app during the
  certificate checkout. Add the gateway the site uses if it is not there.
- `hideChromeCss` hides the Elementor header and footer. If the dashboard relies
  on the header for log out or the cart, add those links to the dashboard page.

## 4. WordPress side

Install `wordpress/iq-training-app-mode.php` as a plugin or a Code Snippets
entry. It detects the app by its user agent (`IQTrainingApp`) and then:

- hides the header and footer,
- redirects the home page, course catalogue, bundles, team training and product
  pages to My Courses (or the login page when logged out),
- makes every product non-purchasable inside the app except the IDs returned by
  `iq_app_allowed_product_ids()`.

Two things to do:

1. Put the printed certificate product ID in `iq_app_allowed_product_ids()`.
   Until then the certificate cannot be ordered in the app.
2. In LiteSpeed Cache, go to Cache, Excludes, "Do Not Cache User Agents" and add
   `IQTrainingApp`. Otherwise the app can be served cached pages built for the
   website, with the header and buy buttons. If Cloudflare is set to cache HTML,
   add a bypass rule for the same user agent.

The app also blocks the sales pages and hides the header itself, so it behaves
before the plugin is installed. The plugin is what stops course product pages,
because the app cannot tell a course product from the certificate product.

## 5. Test before submitting

- Log in, close the app fully, reopen: still logged in.
- Open a course, play a lesson video, go full screen, complete a quiz.
- Download a certificate PDF on Android and on iOS.
- Order a printed certificate through to payment and back to the thank-you page.
- Tap a link to a course sales page from the dashboard: returns to My Courses.
- Turn on flight mode: offline screen appears, "Try again" recovers.
- Android back button steps back through pages, then exits.

## 6. Before the stores

- App icon and native splash: `flutter_launcher_icons` and
  `flutter_native_splash` are the usual packages.
- App Review notes: say the app is for existing learners, give a test login, and
  state that the only purchase is a physical printed certificate sent by post.
- Push notifications are not included. They are the strongest answer if Apple
  raises guideline 4.2 (minimum functionality).
- If people can register inside the app, Apple also requires account deletion
  inside the app. The login form on the site showed no registration option
  when this was written, so check that is still the case.
