import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';

class RequestDetailScreen extends StatefulWidget {
  final ScreenshotRequestItem request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    _printDebugLogs();
  }

  void _printDebugLogs() {
    final adminCtrl = Get.find<AdminController>();
    final targetName = adminCtrl.getDeviceDisplayName(widget.request.targetDeviceId);
    final req = widget.request;

    if (req.status == 'failed') {
      final logOutput = '''
================ [FAILED REQUEST DIAGNOSTICS] ================
Request ID: ${req.requestId}
Type: ${req.requestType}
Target Device: ${req.targetDeviceId} ($targetName)
Status: ${req.status}
Requested At: ${req.requestedAt}
Completed/Failed At: ${req.completedAt}
Background Woken: ${req.backgroundAttemptedAt}
Error: ${req.error}
Failure Reason: ${req.failureReason}
Screenshot URL: ${req.screenshotUrl}
==============================================================
''';
      debugPrint(logOutput);
    }
  }

  String _getDiagnosticsText() {
    final adminCtrl = Get.find<AdminController>();
    final targetName = adminCtrl.getDeviceDisplayName(widget.request.targetDeviceId);
    final req = widget.request;

    return '''
[Request Diagnostics]
ID: ${req.requestId}
Type: ${req.requestType}
Target: $targetName (${req.targetDeviceId})
Status: ${req.status}
Requested At: ${req.requestedAt}
Completed/Failed At: ${req.completedAt}
Error: ${req.error ?? 'None'}
Failure Reason: ${req.failureReason ?? 'None'}
Media URL: ${req.screenshotUrl ?? 'None'}
''';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      case 'active':
      case 'live':
      case 'offer_created':
        return Colors.amberAccent;
      case 'stopped':
        return Colors.grey;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _requestIcon(String type) {
    switch (type.toLowerCase()) {
      case 'camera_capture':
        return Icons.camera_alt_rounded;
      case 'camera_stream':
        return Icons.videocam_rounded;
      case 'screen_share':
        return Icons.screen_share_rounded;
      case 'location_ping':
        return Icons.location_on_rounded;
      case 'wake_up':
        return Icons.bolt_rounded;
      default:
        return Icons.screenshot_rounded;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year $hour:$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final adminCtrl = Get.find<AdminController>();
    final targetName = adminCtrl.getDeviceDisplayName(widget.request.targetDeviceId);
    final statusColor = _statusColor(widget.request.status);
    final isFailed = widget.request.status == 'failed' && (widget.request.error != null || widget.request.failureReason != null);

    return GetBuilder<ThemeController>(
      builder: (themeState) {
        final theme = themeState.currentTheme;

        return Scaffold(
          backgroundColor: theme.cardBg,
          appBar: AppBar(
            backgroundColor: theme.boardBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.textPrimary, size: 20),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Request Details',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, size: 20),
                tooltip: 'Copy Diagnostics Log',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _getDiagnosticsText()));
                  Get.snackbar(
                    'Diagnostics Copied',
                    'Request error logs copied to clipboard.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.blueGrey.shade900,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.only(right: 16, left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  widget.request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Overview Card
                Card(
                  color: theme.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.gridLine),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.blue.withOpacity(0.15),
                              child: Icon(
                                _requestIcon(widget.request.requestType),
                                color: theme.blue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.request.requestType.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Target: $targetName',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: theme.gridLine),
                        const SizedBox(height: 12),
                        _buildInfoRow('Request ID', widget.request.requestId, theme),
                        const SizedBox(height: 8),
                        _buildInfoRow('Requested At', _formatDate(widget.request.requestedAt), theme),
                        if (widget.request.completedAt != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Completed At', _formatDate(widget.request.completedAt), theme),
                        ],
                        if (widget.request.backgroundAttemptedAt != null) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Background Woken', _formatDate(widget.request.backgroundAttemptedAt), theme),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Image Capture Preview (if available)
                if (widget.request.screenshotUrl != null && widget.request.screenshotUrl!.isNotEmpty) ...[
                  Card(
                    color: theme.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.gridLine),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: theme.blue.withOpacity(0.08),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Captured Media (Pinch to Zoom)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_browser, size: 20, color: Colors.blueAccent),
                                tooltip: 'Open Full Image in Browser',
                                onPressed: () async {
                                  final uri = Uri.parse(widget.request.screenshotUrl!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          color: Colors.black,
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.network(
                              widget.request.screenshotUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 250,
                                  alignment: Alignment.center,
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_rounded, size: 40, color: Colors.white54),
                                    SizedBox(height: 8),
                                    Text('Could not load image', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Error / Failure Card (if failed)
                if (isFailed) ...[
                  Card(
                    color: Colors.red.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Execution Failure Details',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _getDiagnosticsText()));
                                  Get.snackbar('Copied', 'Error logs copied to clipboard.');
                                },
                                icon: const Icon(Icons.copy, size: 14, color: Colors.redAccent),
                                label: const Text('Copy', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (widget.request.error != null) ...[
                            Text(
                              'Error Message:',
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              widget.request.error!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ],
                          if (widget.request.failureReason != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reason / Diagnostics:',
                              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              widget.request.failureReason!,
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Quick Action Retry Button
                ElevatedButton.icon(
                  onPressed: () async {
                    if (widget.request.requestType == 'camera_capture') {
                      await adminCtrl.requestCameraCapture(widget.request.targetDeviceId, cameraFacing: 'front');
                    } else if (widget.request.requestType == 'camera_stream') {
                      await adminCtrl.requestCameraStream(widget.request.targetDeviceId, cameraFacing: 'front');
                    } else if (widget.request.requestType == 'screen_share') {
                      await adminCtrl.requestScreenShare(widget.request.targetDeviceId);
                    } else if (widget.request.requestType == 'wake_up') {
                      await adminCtrl.wakeDevice(widget.request.targetDeviceId);
                    } else {
                      await adminCtrl.requestScreenshot(widget.request.targetDeviceId);
                    }
                    Get.back();
                    Get.snackbar(
                      'Request Dispatched',
                      'Re-sent ${widget.request.requestType} command to $targetName',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.indigo.shade800,
                      colorText: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('Re-dispatch ${widget.request.requestType.replaceAll('_', ' ')}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, dynamic theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
