import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../controllers/theme_controller.dart';
import '../widgets/live_share_view.dart';
import 'request_detail_screen.dart';

class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  int _currentPage = 1;
  static const int _pageSize = 10;
  String _selectedFilter = 'all'; // 'all', 'screenshot', 'camera_capture', 'stream', 'location_ping'

  String _formatRequestTime(DateTime? dt) {
    if (dt == null) return 'Time: Just now';
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}, $hour:$min:$sec $ampm';
  }

  bool _isStreamActive(ScreenshotRequestItem r) {
    if (r.status != 'active' && r.status != 'live' && r.status != 'offer_created') return false;
    if (r.completedAt != null || r.status == 'stopped' || r.status == 'failed') return false;
    if (r.requestedAt != null) {
      if (DateTime.now().difference(r.requestedAt!).inMinutes > 10) {
        return false;
      }
    }
    return true;
  }

  void _openFullscreenStream(String requestId, String requestType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenLiveStreamPage(
          requestId: requestId,
          requestType: requestType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminCtrl = Get.find<AdminController>();

    return GetBuilder<ThemeController>(
      builder: (themeState) {
        final theme = themeState.currentTheme;

        return Scaffold(
          backgroundColor: theme.boardBg,
          appBar: AppBar(
            backgroundColor: theme.cardBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.textPrimary, size: 20),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Activity & Request History',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: () {
                  adminCtrl.refreshDeviceList();
                  Get.snackbar(
                    'Refreshed',
                    'Synced latest requests and devices.',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 1),
                  );
                },
              ),
            ],
          ),
          body: Obx(() {
            final allRequests = adminCtrl.screenshotRequests;

            // Apply filter
            final filtered = allRequests.where((req) {
              if (_selectedFilter == 'all') return true;
              if (_selectedFilter == 'stream') {
                return req.requestType == 'screen_share' || req.requestType == 'camera_stream';
              }
              return req.requestType == _selectedFilter;
            }).toList();

            final totalItems = filtered.length;
            final totalPages = (totalItems / _pageSize).ceil().clamp(1, 9999);
            if (_currentPage > totalPages) {
              _currentPage = totalPages;
            }

            final startIndex = (_currentPage - 1) * _pageSize;
            final pageItems = filtered.skip(startIndex).take(_pageSize).toList();

            return Column(
              children: [
                // Filter Tabs Header
                Container(
                  color: theme.cardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', theme, totalItems: allRequests.length),
                        const SizedBox(width: 8),
                        _buildFilterChip('Screenshots', 'screenshot', theme),
                        const SizedBox(width: 8),
                        _buildFilterChip('Camera Captures', 'camera_capture', theme),
                        const SizedBox(width: 8),
                        _buildFilterChip('Live Streams', 'stream', theme),
                        const SizedBox(width: 8),
                        _buildFilterChip('Location Pings', 'location_ping', theme),
                      ],
                    ),
                  ),
                ),

                // Request List or Empty State
                Expanded(
                  child: pageItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 64, color: theme.textSecondary.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'No requests found for this filter',
                                style: TextStyle(color: theme.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: pageItems.length,
                          itemBuilder: (context, idx) {
                            final request = pageItems[idx];
                            final targetName = adminCtrl.getDeviceDisplayName(request.targetDeviceId);

                            return Card(
                              color: theme.cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: theme.gridLine),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Get.to(() => RequestDetailScreen(request: request)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: theme.blue.withOpacity(0.15),
                                                child: Icon(
                                                  _requestIcon(request.requestType),
                                                  size: 18,
                                                  color: theme.blue,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    request.requestType.replaceAll('_', ' ').toUpperCase(),
                                                    style: TextStyle(
                                                      color: theme.textPrimary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Text(
                                                    targetName,
                                                    style: TextStyle(
                                                      color: theme.textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _statusBgColor(request.status),
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
                                      const SizedBox(height: 8),
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
                                           _isStreamActive(request)) ...[
                                         const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _openFullscreenStream(
                                                  request.requestId,
                                                  request.requestType,
                                                ),
                                                icon: const Icon(Icons.fullscreen, size: 16),
                                                label: const Text('Open Stream', style: TextStyle(fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: theme.blue,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  await adminCtrl.stopScreenShare(request.requestId);
                                                  Get.snackbar(
                                                    'Stream Stopped',
                                                    'Stopped ${request.requestType} successfully.',
                                                    snackPosition: SnackPosition.BOTTOM,
                                                  );
                                                },
                                                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                                                label: const Text('Stop Stream', style: TextStyle(fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Pagination Footer Bar
                Container(
                  color: theme.cardBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: $totalItems | Page $_currentPage of $totalPages',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _currentPage > 1
                                ? () => setState(() => _currentPage--)
                                : null,
                            color: theme.textPrimary,
                            disabledColor: theme.textSecondary.withOpacity(0.3),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_currentPage',
                              style: TextStyle(color: theme.blue, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: _currentPage < totalPages
                                ? () => setState(() => _currentPage++)
                                : null,
                            color: theme.textPrimary,
                            disabledColor: theme.textSecondary.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, dynamic theme, {int? totalItems}) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        totalItems != null ? '$label ($totalItems)' : label,
        style: TextStyle(
          color: isSelected ? Colors.white : theme.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.blue,
      backgroundColor: theme.boardBg,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
            _currentPage = 1;
          });
        }
      },
    );
  }

  IconData _requestIcon(String type) {
    switch (type.toLowerCase()) {
      case 'camera_capture':
        return Icons.camera_alt;
      case 'screen_share':
        return Icons.screenshot_monitor;
      case 'camera_stream':
        return Icons.videocam;
      case 'location_ping':
        return Icons.location_on;
      case 'wake_up':
        return Icons.bolt;
      default:
        return Icons.photo_camera;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'active':
      case 'live':
        return Colors.blue.shade700;
      case 'failed':
        return Colors.red.shade700;
      case 'stopped':
        return Colors.grey.shade700;
      default:
        return Colors.amber.shade800;
    }
  }
}
