import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/admin_service.dart';

class AdminDevice {
  final String deviceId;
  final String platform;
  final DateTime? lastSeenAt;

  AdminDevice({required this.deviceId, required this.platform, this.lastSeenAt});

  factory AdminDevice.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return AdminDevice(
      deviceId: snapshot.id,
      platform: data['platform'] as String? ?? 'unknown',
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ScreenshotRequestItem {
  final String requestId;
  final String targetDeviceId;
  final String requestedByDeviceId;
  final String status;
  final String? screenshotUrl;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final String? error;

  ScreenshotRequestItem({
    required this.requestId,
    required this.targetDeviceId,
    required this.requestedByDeviceId,
    required this.status,
    this.screenshotUrl,
    this.requestedAt,
    this.completedAt,
    this.error,
  });

  factory ScreenshotRequestItem.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ScreenshotRequestItem(
      requestId: snapshot.id,
      targetDeviceId: data['targetDeviceId'] as String? ?? '',
      requestedByDeviceId: data['requestedByDeviceId'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      screenshotUrl: data['screenshotUrl'] as String?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      error: data['error'] as String?,
    );
  }
}

class AdminController extends GetxController {
  final RxString currentDeviceId = ''.obs;
  final RxList<AdminDevice> devices = <AdminDevice>[].obs;
  final RxList<ScreenshotRequestItem> screenshotRequests = <ScreenshotRequestItem>[].obs;
  final RxBool isReady = false.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _devicesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingRequestsSubscription;

  Future<void> initialize() async {
    await AdminService.registerDevice();
    currentDeviceId.value = await AdminService.getOrCreateDeviceId();
    _listenToDevices();
    _listenToOwnRequests();
    _listenToIncomingRequests();
    isReady.value = true;
  }

  void _listenToDevices() {
    _devicesSubscription?.cancel();
    _devicesSubscription = AdminService.watchDevices().listen((snapshot) {
      devices.value = snapshot.docs.map(AdminDevice.fromSnapshot).toList();
    }, onError: (error) {
      debugPrint('Admin device listener error: $error');
    });
  }

  void _listenToOwnRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = AdminService.watchOwnRequests(currentDeviceId.value).listen((snapshot) {
      screenshotRequests.value = snapshot.docs.map(ScreenshotRequestItem.fromSnapshot).toList();
    }, onError: (error) {
      debugPrint('Admin request listener error: $error');
    });
  }

  void _listenToIncomingRequests() {
    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = AdminService.watchPendingRequestsForDevice(currentDeviceId.value).listen((snapshot) {
      for (final doc in snapshot.docs) {
        AdminService.fulfillScreenshotRequest(doc.id);
      }
    }, onError: (error) {
      debugPrint('Incoming screenshot listener error: $error');
    });
  }

  Future<void> refreshDeviceList() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('devices').orderBy('lastSeenAt', descending: true).get();
    devices.value = querySnapshot.docs.map(AdminDevice.fromSnapshot).toList();
  }

  Future<void> requestScreenshot(String targetDeviceId) async {
    if (targetDeviceId.isEmpty) return;
    await AdminService.sendScreenshotRequest(targetDeviceId, currentDeviceId.value);
  }

  int get otherInstalledDevicesCount {
    return devices.where((device) => device.deviceId != currentDeviceId.value).length;
  }

  @override
  void onClose() {
    _devicesSubscription?.cancel();
    _requestsSubscription?.cancel();
    _incomingRequestsSubscription?.cancel();
    super.onClose();
  }
}
