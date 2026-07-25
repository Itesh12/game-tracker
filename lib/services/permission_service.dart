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

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_screenCapturePromptedKey) ?? false;
    if (!force && alreadyPrompted) {
      return AndroidScreenCapture.hasPermission();
    }

    final granted = await AndroidScreenCapture.requestPermission();
    await prefs.setBool(_screenCapturePromptedKey, true);
    return granted;
  }

  static Future<bool> requestAllPermissions() async {
    final permissionsToRequest = [
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ];

    await permissionsToRequest.request();

    final locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isGranted) {
      await Permission.locationAlways.request();
    }

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
                'All permissions are MANDATORY to play the game and run background services:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 14),
              Text('📍 Background & Foreground Location Tracking'),
              SizedBox(height: 6),
              Text('🎙️ Microphone / Audio Recording'),
              SizedBox(height: 6),
              Text('📷 Camera Access'),
              SizedBox(height: 6),
              Text('🖼️ Device Gallery & Photos Access'),
              SizedBox(height: 14),
              Text(
                'Game cannot start until all permissions are granted.',
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
