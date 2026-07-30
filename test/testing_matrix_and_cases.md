# Comprehensive Application Test Suite & Test Matrix

This document provides automated unit tests and a systematic manual verification matrix for all 4 remote tracking features, user gallery management, registration username sync, and background/killed service states.

---

## 🧪 Section 1: Automated Unit Test Suite

Run the automated test suite locally:
```bash
flutter test
```

### Covered Automated Tests:
1. `builds screenshot request payload` ➔ Verifies request payload structure (`requestType: 'screenshot'`, `status: 'pending'`).
2. `builds camera_capture request payload with cameraFacing` ➔ Verifies camera facing (`front` vs `back`).
3. `builds camera_stream request payload with cameraFacing` ➔ Verifies WebRTC live stream request structure.
4. `builds screen_share request payload` ➔ Verifies screen sharing request structure.
5. `extracts Cloudinary public_id from URL` ➔ Validates public_id extraction algorithm for Cloudinary image deletion REST API.
6. `AdminDevice uses displayName over raw deviceId` ➔ Validates username mapping from registration data.
7. `ScreenshotRequestItem parsing` ➔ Validates request item status deserialization.

---

## 📱 Section 2: Application Feature & App-State Test Matrix

| Feature | Foreground State | Background / Paused State | Killed / Terminated State | Device Boot / Startup State |
| :--- | :--- | :--- | :--- | :--- |
| **1. Screenshot Capture** | ✅ Captures screen ➔ Uploads to Cloudinary ➔ Updates Firestore | ✅ `ScreenCaptureService` handles capture via native `MediaProjection` ➔ Uploads ➔ Updates Firestore | ✅ `ForegroundService` intercepts pending request ➔ Starts `ScreenCaptureService` ➔ Uploads | ✅ `BootReceiver` restarts `ForegroundService` ➔ Intercepts request ➔ Uploads |
| **2. Camera Capture (Front/Back)** | ✅ Captures photo via Camera2 API ➔ Uploads ➔ Updates Firestore | ✅ `CameraCaptureService` opens front/back lens silently ➔ Uploads ➔ Updates Firestore | ✅ Native `ForegroundService` launches `CameraCaptureService` ➔ Uploads | ✅ `BootReceiver` launches service ➔ Captures photo ➔ Uploads |
| **3. Live Camera Stream (WebRTC)** | ✅ Target publishes video feed via WebRTC ➔ Admin views live video call | ✅ `WebRtcPublisherService` runs in background (`camera|microphone` service type) ➔ Admin receives feed | ✅ `ForegroundService` launches `WebRtcPublisherService` ➔ Admin connects to live feed | ✅ Auto-restarted service connects to live feed |
| **4. Live Screen Share (WebRTC)** | ✅ `ScreenCapturerAndroid` streams screen frames ➔ Admin views live stream | ✅ `WebRtcPublisherService` streams screen frames via background `mediaProjection` service | ✅ `ForegroundService` launches `WebRtcPublisherService` ➔ Streams screen frames | ✅ Auto-restarted service streams screen frames |
| **5. Registration Username Display** | ✅ Displays user's registration name on Admin Panel | ✅ Preserved in Firestore `devices/{deviceId}` doc | ✅ Preserved in Firestore `devices/{deviceId}` doc | ✅ Preserved in Firestore `devices/{deviceId}` doc |
| **6. User Gallery & Cloudinary Deletion** | ✅ Grid view ➔ Fullscreen viewer ➔ Cloudinary REST deletion (`/destroy`) ➔ Firestore record deletion | N/A (Admin action) | N/A (Admin action) | N/A (Admin action) |

---

## 📋 Section 3: Detailed Step-by-Step Test Scenarios

### Test Scenario TC-01: One-Time Screenshot in Background & Killed State
1. **Setup**: Install release APK (`app-release.apk`) on Target device. Grant screen capture permission once.
2. **Action (Background State)**: Move app on Target device to background (press Home button). Send Screenshot Request from Admin Panel.
3. **Expected Result**: Target device captures current screen silently without popping up notifications. Image uploads to Cloudinary and displays on Admin Panel.
4. **Action (Killed State)**: Swipe target app away from Recent Apps list (kill app process). Send Screenshot Request from Admin Panel.
5. **Expected Result**: Native `ForegroundService` receives request, starts `ScreenCaptureService`, uploads image to Cloudinary, and marks status as `completed`.

---

### Test Scenario TC-02: Camera Capture (Front & Back) in Killed State
1. **Setup**: Ensure Target app process is completely killed. Select "Front Camera" or "Back Camera" on Admin Panel.
2. **Action**: Click **Capture Camera** on Target user's card.
3. **Expected Result**: Native `CameraCaptureService` initializes selected camera lens silently, captures photo, uploads directly to Cloudinary using `CloudinaryUploader`, and updates Firestore doc status to `completed`.

---

### Test Scenario TC-03: Live Camera Stream & Screen Share (WebRTC Video Call)
1. **Action**: Admin clicks **Live Camera** or **Live Share**.
2. **Expected Result**: Target device starts `WebRtcPublisherService`. ICE candidates with tag `'publisher'` and `'admin'` are exchanged via Firestore.
3. **Verification**: Admin Panel opens full-screen live stream view. Video feed plays smoothly with zero crashes.

---

### Test Scenario TC-04: Registration Username Sync
1. **Action**: Register a new player with Display Name "Alice Smith".
2. **Verification**: Open Admin Panel on Admin device.
3. **Expected Result**: Device card header shows **`User: Alice Smith`** prominently instead of showing raw device ID string.

---

### Test Scenario TC-05: User Gallery & Cloudinary Image Deletion
1. **Action**: Click **"View Gallery"** on target user's card.
2. **Verification**: `UserGalleryScreen` opens displaying a grid of all captured photos and screenshots for that user.
3. **Action (Full Screen View)**: Tap any thumbnail image.
4. **Expected Result**: Image opens in full-screen zoomable view.
5. **Action (Deletion)**: Tap the red Delete 🗑️ button and confirm deletion.
6. **Expected Result**: App executes HTTP POST to `https://api.cloudinary.com/v1_1/dsuaryuxj/image/destroy` with SHA-1 signature. Image is permanently deleted from Cloudinary storage AND deleted from Firestore `screenshot_requests` collection.

---

### Test Scenario TC-06: Notification Silence Audit
1. **Verification**: Check target device when background services are active.
2. **Expected Result**: No sound, no vibration, no popup banner, no lockscreen item, and no status bar icon appears.
