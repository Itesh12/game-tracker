import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/admin_service.dart';

class UserGalleryScreen extends StatelessWidget {
  const UserGalleryScreen({
    super.key,
    required this.device,
  });

  final AdminDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>().currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${device.username}\'s Gallery'),
        backgroundColor: theme.blue,
      ),
      body: Obx(() {
        final adminCtrl = Get.find<AdminController>();
        final items = adminCtrl.screenshotRequests
            .where((item) =>
                item.targetDeviceId == device.deviceId &&
                item.status == 'completed' &&
                item.screenshotUrl != null &&
                item.screenshotUrl!.isNotEmpty)
            .toList();

        items.sort((a, b) {
          final tA = a.completedAt ?? a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tB = b.completedAt ?? b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tB.compareTo(tA);
        });

        if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: theme.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No captured images for ${device.username}',
                    style: TextStyle(fontSize: 16, color: theme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _GalleryItemCard(
                item: item,
                theme: theme,
                onTap: () => _showFullScreenImage(context, item, theme),
                onDelete: () => _confirmDelete(context, item),
            );
          },
        );
      }),
    );
  }

  void _showFullScreenImage(BuildContext context, ScreenshotRequestItem item, dynamic theme) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(_getTypeLabel(item.requestType)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () async {
                  final deleted = await _confirmDelete(context, item);
                  if (deleted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                tooltip: 'Delete Image',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                item.screenshotUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, ScreenshotRequestItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image? It will be removed from Cloudinary and database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      Get.snackbar('Deleting...', 'Removing image from Cloudinary and database', snackPosition: SnackPosition.BOTTOM);
      await AdminService.deleteCapturedImage(item.requestId, item.screenshotUrl);
      Get.snackbar('Deleted', 'Image deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    return false;
  }

  static String _getTypeLabel(String requestType) {
    switch (requestType) {
      case 'camera_capture':
        return 'Camera Photo';
      case 'screen_share':
        return 'Screen Stream Frame';
      case 'camera_stream':
        return 'Camera Stream Frame';
      default:
        return 'Screenshot';
    }
  }
}

class _GalleryItemCard extends StatelessWidget {
  const _GalleryItemCard({
    required this.item,
    required this.theme,
    required this.onTap,
    required this.onDelete,
  });

  final ScreenshotRequestItem item;
  final dynamic theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = item.completedAt != null
        ? '${item.completedAt!.hour.toString().padLeft(2, '0')}:${item.completedAt!.minute.toString().padLeft(2, '0')} - ${item.completedAt!.day}/${item.completedAt!.month}'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: theme.cardBg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                item.screenshotUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade900,
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  UserGalleryScreen._getTypeLabel(item.requestType),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black54,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
              ),
            ),
            if (dateStr.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: Colors.black.withOpacity(0.6),
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
