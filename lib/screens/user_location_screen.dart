import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/admin_service.dart';
import '../services/backend_bridge_service.dart';
import '../utils/app_alert.dart';
import '../utils/app_feedback.dart';

class UserLocationScreen extends StatefulWidget {
  const UserLocationScreen({
    super.key,
    required this.device,
  });

  final AdminDevice device;

  @override
  State<UserLocationScreen> createState() => _UserLocationScreenState();
}

class _UserLocationScreenState extends State<UserLocationScreen> {
  late final Rx<AdminDevice> _liveDevice;
  Worker? _adminDevicesWorker;
  StreamSubscription<dynamic>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _liveDevice = Rx<AdminDevice>(widget.device);

    final adminCtrl = Get.isRegistered<AdminController>() ? Get.find<AdminController>() : null;
    if (adminCtrl != null) {
      final matched = adminCtrl.devices.firstWhereOrNull((d) => d.deviceId == widget.device.deviceId);
      if (matched != null) {
        _liveDevice.value = matched;
      }
      _adminDevicesWorker = ever(adminCtrl.devices, (List<AdminDevice> list) {
        final updated = list.firstWhereOrNull((d) => d.deviceId == widget.device.deviceId);
        if (updated != null) {
          _liveDevice.value = updated;
        }
      });
    }

    // Stream device updates from BackendBridgeService (dual-cloud Firestore + Supabase)
    _deviceSub = BackendBridgeService.streamDevice(widget.device.deviceId).listen(
      (data) {
        if (data != null) {
          _liveDevice.value = AdminDevice.fromMap(data);
        }
      },
      onError: (e) {
        debugPrint('UserLocationScreen device stream error: $e');
      },
    );

    // Auto-ping target device once on screen open for on-demand fresh coordinates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendLocationPingRequest(silent: true);
    });
  }

  @override
  void dispose() {
    _adminDevicesWorker?.dispose();
    _deviceSub?.cancel();
    super.dispose();
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final Uri googleMapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication)) {
      AppAlert.showError('Could not open Google Maps.', title: 'Launch Failed');
    }
  }

  Future<void> _sendLocationPingRequest({bool silent = false}) async {
    try {
      final adminCtrl = Get.find<AdminController>();
      final payload = AdminService.buildRequestPayload(
        requestType: 'location_ping',
        targetDeviceId: widget.device.deviceId,
        requestedByDeviceId: adminCtrl.currentDeviceId.value,
      );
      await BackendBridgeService.createScreenshotRequest(payload);

      if (!silent) {
        AppAlert.showSuccess(
          'Target device has been pinged for a fresh GPS location update.',
          title: 'Ping Sent Successfully',
        );
      }
    } catch (e) {
      if (!silent) {
        AppAlert.showError(e.toString(), title: 'Ping Failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location: ${widget.device.username}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            tooltip: 'Manual Refresh Location',
            onPressed: () {
              AppFeedback.buttonPress();
              _sendLocationPingRequest();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            final dev = _liveDevice.value;
            final lat = dev.latitude;
            final lng = dev.longitude;
            final accuracy = dev.accuracy;
            final lastTime = dev.lastLocationTime;

            final hasLocation = lat != null && lng != null;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Card(
                    color: theme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: theme.gridLine),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                            backgroundImage: dev.photoUrl != null &&
                                    dev.photoUrl!.isNotEmpty
                                ? NetworkImage(dev.photoUrl!)
                                : null,
                            child: dev.photoUrl == null ||
                                    dev.photoUrl!.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.blueAccent, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.username,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dev.email ?? dev.deviceId,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: hasLocation
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      hasLocation
                                          ? 'GPS Position Locked'
                                          : 'No GPS Fix Yet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: hasLocation
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Coordinates & Action Container
                  Expanded(
                    child: Card(
                      color: theme.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: theme.gridLine),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: (hasLocation ? Colors.blueAccent : Colors.grey)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasLocation
                                    ? Icons.location_on_rounded
                                    : Icons.location_off_rounded,
                                size: 56,
                                color: hasLocation
                                    ? Colors.blueAccent
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (hasLocation) ...[
                              Text(
                                'Coordinates',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (accuracy != null)
                                Text(
                                  'Accuracy: ~${accuracy.toStringAsFixed(1)} meters',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              if (lastTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reported: ${lastTime.toLocal().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: () {
                                  AppFeedback.buttonPress();
                                  _openInGoogleMaps(lat, lng);
                                },
                                icon: const Icon(Icons.map_rounded, size: 22),
                                label: const Text(
                                  'OPEN IN GOOGLE MAPS',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  AppFeedback.buttonPress();
                                  _sendLocationPingRequest();
                                },
                                icon: const Icon(Icons.radar, size: 20),
                                label: const Text('PING FOR FRESH LOCATION'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                  side: const BorderSide(color: Colors.blueAccent),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Waiting for target device to report GPS coordinates...',
                                style: TextStyle(color: theme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _sendLocationPingRequest,
                                icon: const Icon(Icons.radar, size: 24),
                                label: const Text(
                                  'PING LATEST LOCATION',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
