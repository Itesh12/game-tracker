# game_tracker

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase and Admin Panel

The app now includes a hidden admin panel. Open the home screen and long-press the title text to reveal the admin login prompt.

To use the Firebase features, configure a Firebase project and add your
platform files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

Also update `lib/services/admin_service.dart` with your Cloudinary
`cloudinaryCloudName` and `cloudinaryUploadPreset` values before using
remote screenshot upload.
