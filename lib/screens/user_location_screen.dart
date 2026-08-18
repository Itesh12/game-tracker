import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';

class UserLocationScreen extends StatelessWidget {
  const UserLocationScreen({
    super.key,
    required this.device,
  });

  final AdminDevice device;

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        'Launch Failed',
        'Could not open Google Maps.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _sendLocationPingRequest() async {
    try {
      final adminCtrl = Get.find<AdminController>();
      await FirebaseFirestore.instance.collection('screenshot_requests').add({
        'targetDeviceId': device.deviceId,
        'requestedByDeviceId': adminCtrl.currentDeviceId.value,
        'requestType': 'location_ping',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        'Refreshing Location',
        'Location ping request sent to device.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Ping Failed',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location: ${device.username}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            tooltip: 'Manual Refresh Location',
            onPressed: _sendLocationPingRequest,
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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('devices')
                .doc(device.deviceId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading location: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final liveDevice = AdminDevice.fromSnapshot(snapshot.data!);
              final lat = liveDevice.latitude;
              final lng = liveDevice.longitude;
              final accuracy = liveDevice.accuracy;
              final lastTime = liveDevice.lastLocationTime;

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
                              backgroundColor: Colors.blueAccent.withOpacity(0.2),
                              backgroundImage: liveDevice.photoUrl != null && liveDevice.photoUrl!.isNotEmpty
                                  ? NetworkImage(liveDevice.photoUrl!)
                                  : null,
                              child: liveDevice.photoUrl == null || liveDevice.photoUrl!.isEmpty
                                  ? const Icon(Icons.person, color: Colors.blueAccent, size: 32)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    liveDevice.username,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Device ID: ${liveDevice.deviceId}',
                                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.greenAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Auto-Syncing every 5 sec',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
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

                    // Coordinates Display Card
                    Expanded(
                      child: Card(
                        color: theme.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasLocation ? Icons.location_on : Icons.location_off,
                                size: 64,
                                color: hasLocation ? Colors.redAccent : Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasLocation ? 'REALTIME GPS COORDINATES' : 'LOCATION UNAVAILABLE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: theme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (hasLocation) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.boardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.gridLine),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Latitude:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          SelectableText(
                                            lat.toStringAsFixed(6),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Longitude:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          SelectableText(
                                            lng.toStringAsFixed(6),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (accuracy != null) ...[
                                        const Divider(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('GPS Accuracy:', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text(
                                              '±${accuracy.toStringAsFixed(1)} m',
                                              style: TextStyle(color: theme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                       if (lastTime != null) ...[
                                         const Divider(height: 20),
                                         Row(
                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                           children: [
                                             const Text('Last Updated:', style: TextStyle(fontWeight: FontWeight.bold)),
                                             Text(
                                               '${lastTime.day.toString().padLeft(2, '0')}/${lastTime.month.toString().padLeft(2, '0')}/${lastTime.year} ${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}:${lastTime.second.toString().padLeft(2, '0')}',
                                               style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600),
                                             ),
                                           ],
                                         ),
                                       ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                ElevatedButton.icon(
                                  onPressed: () => _openInGoogleMaps(lat, lng),
                                  icon: const Icon(Icons.map_rounded, size: 28),
                                  label: const Text(
                                    'OPEN IN GOOGLE MAPS',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 6,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Waiting for target device to report GPS coordinates...',
                                  style: TextStyle(color: theme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: _sendLocationPingRequest,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Send Manual Location Ping'),
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
            },
          ),
        ),
      ),
    );
  }
}
