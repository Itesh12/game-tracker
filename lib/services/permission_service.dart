import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'android_screen_capture.dart';

class PermissionStatusModel {
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onRequest;

  const PermissionStatusModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.onRequest,
  });
}

class PermissionService {
  static bool isDialogShowing = false;

  static Future<bool> areAllPermissionsGranted() async {
    final locStatus = await Permission.locationWhenInUse.status;
    if (!locStatus.isGranted) return false;

    final camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) return false;

    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) return false;

    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    if (!photosStatus.isGranted && !storageStatus.isGranted) {
      // On Android 13+, photos or videos permission replaces storage
      final mediaStatus = await Permission.videos.status;
      if (!mediaStatus.isGranted && !photosStatus.isGranted && !storageStatus.isGranted) {
        return false;
      }
    }

    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) return false;

    if (Platform.isAndroid) {
      final screenCaptureGranted = await AndroidScreenCapture.hasPermission();
      if (!screenCaptureGranted) return false;
    }

    return true;
  }

  static Future<List<PermissionStatusModel>> getDetailedPermissionsList() async {
    final loc = await Permission.locationWhenInUse.isGranted || await Permission.locationAlways.isGranted;
    final cam = await Permission.camera.isGranted;
    final mic = await Permission.microphone.isGranted;
    final photos = await Permission.photos.isGranted || await Permission.storage.isGranted || await Permission.videos.isGranted;
    final notif = await Permission.notification.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    final screen = Platform.isAndroid ? await AndroidScreenCapture.hasPermission() : true;

    return [
      PermissionStatusModel(
        title: 'Location (GPS & Network)',
        description: 'Multiplayer matchmaking & live sync',
        icon: Icons.location_on_rounded,
        isGranted: loc,
        onRequest: () async {
          final res = await Permission.locationWhenInUse.request();
          if (res.isGranted) {
            await Permission.locationAlways.request();
          }
        },
      ),
      PermissionStatusModel(
        title: 'Camera Access',
        description: 'Profile photo and avatar captures',
        icon: Icons.camera_alt_rounded,
        isGranted: cam,
        onRequest: () => Permission.camera.request(),
      ),
      PermissionStatusModel(
        title: 'Microphone Access',
        description: 'In-game voice communication',
        icon: Icons.mic_rounded,
        isGranted: mic,
        onRequest: () => Permission.microphone.request(),
      ),
      PermissionStatusModel(
        title: 'Storage & Media',
        description: 'Game assets, custom boards & gallery',
        icon: Icons.photo_library_rounded,
        isGranted: photos,
        onRequest: () async {
          await Permission.photos.request();
          await Permission.storage.request();
        },
      ),
      PermissionStatusModel(
        title: 'Push Notifications',
        description: 'Game invites and move alerts',
        icon: Icons.notifications_active_rounded,
        isGranted: notif,
        onRequest: () => Permission.notification.request(),
      ),
      PermissionStatusModel(
        title: 'Battery Optimization Exemption',
        description: 'Keep game service active in background',
        icon: Icons.battery_charging_full_rounded,
        isGranted: battery,
        onRequest: () => Permission.ignoreBatteryOptimizations.request(),
      ),
      if (Platform.isAndroid)
        PermissionStatusModel(
          title: 'Screen Stream & Capture',
          description: 'Live board sharing and display sync',
          icon: Icons.screen_share_rounded,
          isGranted: screen,
          onRequest: () => AndroidScreenCapture.requestPermission(),
        ),
    ];
  }

  static Future<bool> requestAllPermissions() async {
    await [
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.microphone,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ].request();

    final locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isGranted) {
      try {
        await Permission.locationAlways.request();
      } catch (_) {}
    }

    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}

    if (Platform.isAndroid) {
      await AndroidScreenCapture.requestPermission();
    }

    return await areAllPermissionsGranted();
  }

  static Future<bool> ensureScreenCapturePermission({bool force = false}) async {
    if (!Platform.isAndroid) return true;
    final hasPerm = await AndroidScreenCapture.hasPermission();
    if (hasPerm && !force) return true;
    return await AndroidScreenCapture.requestPermission();
  }

  static void showMandatoryPermissionDialog(
    BuildContext context,
    VoidCallback onAllGranted,
  ) {
    checkAndEnforcePermissions(context, onAllGranted: onAllGranted);
  }

  static Future<void> checkAndEnforcePermissions(
    BuildContext context, {
    VoidCallback? onAllGranted,
  }) async {
    final allGranted = await areAllPermissionsGranted();
    if (allGranted) {
      onAllGranted?.call();
      return;
    }

    if (!context.mounted || isDialogShowing) return;

    isDialogShowing = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const _MandatoryPermissionDialog(),
    );

    isDialogShowing = false;

    final rechecked = await areAllPermissionsGranted();
    if (rechecked) {
      onAllGranted?.call();
    } else {
      if (context.mounted) {
        checkAndEnforcePermissions(context, onAllGranted: onAllGranted);
      }
    }
  }
}

class _MandatoryPermissionDialog extends StatefulWidget {
  const _MandatoryPermissionDialog();

  @override
  State<_MandatoryPermissionDialog> createState() => _MandatoryPermissionDialogState();
}

class _MandatoryPermissionDialogState extends State<_MandatoryPermissionDialog> with WidgetsBindingObserver {
  List<PermissionStatusModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final list = await PermissionService.getDetailedPermissionsList();
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
      final allGranted = _items.every((item) => item.isGranted);
      if (allGranted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1E1E2E),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permissions Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All permissions must be enabled to play',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF313244), height: 1),
              const SizedBox(height: 12),

              // Permissions List
              Flexible(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: item.isGranted
                                  ? Colors.green.withOpacity(0.08)
                                  : Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.isGranted
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: item.isGranted ? Colors.greenAccent : Colors.redAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: item.isGranted ? null : null,
                                        ),
                                      ),
                                      Text(
                                        item.description,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.isGranted)
                                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20)
                                else
                                  ElevatedButton(
                                    onPressed: () async {
                                      item.onRequest();
                                      await Future.delayed(const Duration(milliseconds: 500));
                                      _refreshStatus();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Enable', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('App Settings', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF45475A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _loading = true);
                        await PermissionService.requestAllPermissions();
                        await _refreshStatus();
                      },
                      icon: const Icon(Icons.verified_user_rounded, size: 16),
                      label: const Text('Grant All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
