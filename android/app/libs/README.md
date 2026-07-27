Place a prebuilt google-webrtc AAR here if Gradle cannot reach the WebRTC Maven repository.

Steps:
1. Obtain `google-webrtc.aar` for Android (matching the expected ABI and version).
   - Official builds may be available from https://maven.webrtc.org or project release pages.
   - Alternatively extract the AAR from a device build cache or a plugin distribution.
2. Copy the AAR into this folder: `android/app/libs/google-webrtc.aar`.
3. Re-run your build: `flutter build apk`.

This project prefers a local AAR when present; otherwise it attempts to fetch the remote artifact `org.webrtc:google-webrtc:1.0.32006`.
