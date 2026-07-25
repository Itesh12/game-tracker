import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Required runtime permissions list
  static List<Permission> get requiredPermissions => [
        Permission.locationWhenInUse,
        Permission.locationAlways,
        Permission.microphone,
        Permission.camera,
        Permission.photos,
        Permission.storage,
      ];

  // Check if ALL required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    for (var permission in [
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.camera,
    ]) {
      final status = await permission.status;
      if (!status.isGranted) return false;
    }

    // Check gallery / photo storage
    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    if (!photosStatus.isGranted && !storageStatus.isGranted) {
      return false;
    }

    return true;
  }

  // Request all permissions
  static Future<bool> requestAllPermissions() async {
    final permissionsToRequest = [
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ];

    await permissionsToRequest.request();

    // Request background location if foreground is granted
    final locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isGranted) {
      await Permission.locationAlways.request();
    }

    return await areAllPermissionsGranted();
  }

  // Show mandatory permission dialog blocking game start if permissions denied
  static void showMandatoryPermissionDialog(
      BuildContext context, VoidCallback onAllGranted) async {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
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
                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                    // Prompt again if still not granted
                    showMandatoryPermissionDialog(context, onAllGranted);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Grant All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
