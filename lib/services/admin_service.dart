import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_screenshot_service.dart';

class AdminService {
  AdminService._();

  static const String deviceIdPref = 'game_tracker_device_id';
  static const String cloudinaryCloudName = '<YOUR_CLOUDINARY_CLOUD_NAME>';
  static const String cloudinaryUploadPreset = '<YOUR_UNSIGNED_UPLOAD_PRESET>';
  static const String screenshotRequestsCollection = 'screenshot_requests';
  static const String devicesCollection = 'devices';

  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(deviceIdPref);
    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    deviceId = 'device_${timestamp}_$random';
    await prefs.setString(deviceIdPref, deviceId);
    return deviceId;
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

  static Future<void> registerDevice() async {
    try {
      final deviceId = await getOrCreateDeviceId();
      await firestore.collection(devicesCollection).doc(deviceId).set(
        {
          'deviceId': deviceId,
          'platform': platformName,
          'registeredAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Device registration failed: $error');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchDevices() {
    return firestore.collection(devicesCollection).orderBy('lastSeenAt', descending: true).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnRequests(String deviceId) {
    return firestore
        .collection(screenshotRequestsCollection)
        .where('requestedByDeviceId', isEqualTo: deviceId)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingRequestsForDevice(String deviceId) {
    return firestore
        .collection(screenshotRequestsCollection)
        .where('targetDeviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  static Future<String> sendScreenshotRequest(String targetDeviceId, String requestedByDeviceId) async {
    final doc = firestore.collection(screenshotRequestsCollection).doc();
    await doc.set({
      'requestId': doc.id,
      'targetDeviceId': targetDeviceId,
      'requestedByDeviceId': requestedByDeviceId,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> fulfillScreenshotRequest(String requestId) async {
    final screenshotBytes = await AppScreenshotService.captureScreenshot();
    if (screenshotBytes == null) {
      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'failed',
        'error': 'Could not capture screenshot',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final url = await _uploadToCloudinary(screenshotBytes);
    if (url == null) {
      await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
        'status': 'failed',
        'error': 'Cloudinary upload failed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await firestore.collection(screenshotRequestsCollection).doc(requestId).update({
      'status': 'completed',
      'screenshotUrl': url,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> _uploadToCloudinary(Uint8List bytes) async {
    if (cloudinaryCloudName.contains('<') || cloudinaryUploadPreset.contains('<')) {
      debugPrint('Cloudinary configuration is missing. Please set cloudinaryCloudName and cloudinaryUploadPreset in AdminService.');
      return null;
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');
    final base64Data = base64Encode(bytes);
    final response = await http.post(uri, body: {
      'file': 'data:image/png;base64,$base64Data',
      'upload_preset': cloudinaryUploadPreset,
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Cloudinary upload failed: ${response.statusCode} ${response.body}');
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['secure_url'] as String?;
  }
}
