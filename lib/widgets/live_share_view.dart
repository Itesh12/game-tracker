import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import '../controllers/admin_controller.dart';
import '../services/admin_service.dart';
import '../services/backend_bridge_service.dart';
import '../services/live_share_service.dart';
import '../utils/app_alert.dart';
import '../utils/app_feedback.dart';

class LiveShareView extends StatefulWidget {
  const LiveShareView({
    super.key,
    required this.requestId,
    this.fullScreen = false,
  });

  final String requestId;
  final bool fullScreen;

  @override
  State<LiveShareView> createState() => LiveShareViewState();
}

class LiveShareViewState extends State<LiveShareView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  final GlobalKey _repaintKey = GlobalKey();
  bool _ready = false;
  bool _hasVideoFrame = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _renderer.initialize();
    _renderer.onResize = () {
      if (mounted) setState(() {});
    };
    _renderer.onFirstFrameRendered = () {
      if (mounted) {
        setState(() => _hasVideoFrame = true);
      }
    };
    await LiveShareService.instance
        .attachToRequest(widget.requestId, _renderer);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<Uint8List?> captureFrame() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing live stream frame: $e');
      return null;
    }
  }

  @override
  void dispose() {
    LiveShareService.instance.detach(widget.requestId);
    try {
      _renderer.srcObject = null;
    } catch (_) {}
    try {
      _renderer.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoContent = Container(
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 12),
        child: RepaintBoundary(
          key: _repaintKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                RTCVideoView(
                  _renderer,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              if (!_hasVideoFrame)
                Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 14),
                      Text(
                        'Connecting live stream…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.fullScreen) {
      return SizedBox.expand(child: videoContent);
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: videoContent,
    );
  }
}

class FullScreenLiveStreamPage extends StatefulWidget {
  const FullScreenLiveStreamPage({
    super.key,
    required this.requestId,
    required this.requestType,
    this.targetDeviceId,
  });

  final String requestId;
  final String requestType;
  final String? targetDeviceId;

  @override
  State<FullScreenLiveStreamPage> createState() =>
      _FullScreenLiveStreamPageState();
}

class _FullScreenLiveStreamPageState extends State<FullScreenLiveStreamPage> {
  final GlobalKey<LiveShareViewState> _liveShareKey =
      GlobalKey<LiveShareViewState>();
  bool _isCapturing = false;
  double _volume = 1.0;
  bool _isMuted = false;

  void _toggleMute() {
    AppFeedback.buttonPress();
    setState(() {
      _isMuted = !_isMuted;
    });
    final session = LiveShareService.instance.getSession(widget.requestId);
    if (_isMuted) {
      session?.setVolume(0.0);
      AppAlert.showInfo('Stream audio muted', title: 'Audio');
    } else {
      final vol = _volume <= 0.05 ? 0.8 : _volume;
      _volume = vol;
      session?.setVolume(vol);
      AppAlert.showInfo('Stream audio unmuted (${(vol * 100).round()}%)',
          title: 'Audio');
    }
  }

  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAudioOutput();
  }

  Future<void> _checkInitialAudioOutput() async {
    try {
      final devices = await Helper.audiooutputs;
      final hasHeadphones = devices.any((d) {
        final label = (d.label).toLowerCase();
        final id = (d.deviceId).toLowerCase();
        return label.contains('head') ||
            label.contains('bluetooth') ||
            label.contains('wired') ||
            id.contains('head') ||
            id.contains('bluetooth') ||
            id.contains('wired');
      });
      if (hasHeadphones && mounted) {
        setState(() {
          _isSpeakerOn = false;
        });
      }
    } catch (_) {}
  }

  void _toggleAudioOutput() {
    AppFeedback.buttonPress();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    final session = LiveShareService.instance.getSession(widget.requestId);
    session?.setSpeakerphoneOn(_isSpeakerOn);
    if (_isSpeakerOn) {
      AppAlert.showInfo('Audio routed to Speakerphone', title: 'Audio Output');
    } else {
      AppAlert.showInfo('Audio routed to Headphones / Headset',
          title: 'Audio Output');
    }
  }

  void _onVolumeChanged(double val) {
    AppFeedback.selectionChanged();
    setState(() {
      _volume = val;
      _isMuted = val <= 0.01;
    });
    final session = LiveShareService.instance.getSession(widget.requestId);
    session?.setVolume(val);
  }

  Future<void> _captureSnapshot() async {
    if (_isCapturing) return;
    AppFeedback.buttonPress();
    setState(() => _isCapturing = true);

    try {
      final bytes = await _liveShareKey.currentState?.captureFrame();
      if (bytes == null || bytes.isEmpty) {
        AppAlert.showError('Unable to capture frame from stream.',
            title: 'Capture Failed');
        return;
      }

      AppAlert.showInfo('Uploading snapshot to Cloudinary…',
          title: 'Processing');
      final uploadedUrl = await AdminService.uploadBytesToCloudinary(bytes);

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        AppAlert.showError('Failed to upload snapshot to Cloudinary.',
            title: 'Upload Failed');
        return;
      }

      final adminCtrl = Get.find<AdminController>();
      String targetDevId = widget.targetDeviceId ?? '';
      if (targetDevId.isEmpty) {
        final req = adminCtrl.screenshotRequests
            .firstWhereOrNull((r) => r.requestId == widget.requestId);
        targetDevId = req?.targetDeviceId ?? '';
      }

      final snapshotReqId = 'snap_${DateTime.now().millisecondsSinceEpoch}';
      final nowIso = DateTime.now().toIso8601String();
      final payload = {
        'id': snapshotReqId,
        'target_device_id': targetDevId,
        'requested_by_device_id': adminCtrl.currentDeviceId.value,
        'request_type': 'stream_snapshot',
        'status': 'completed',
        'screenshot_url': uploadedUrl,
        'requested_at': nowIso,
        'completed_at': nowIso,
      };

      await BackendBridgeService.createScreenshotRequest(payload);
      adminCtrl.screenshotRequests.refresh();

      AppAlert.showSuccess(
        'Snapshot captured and uploaded to Cloudinary! It is now visible in the gallery.',
        title: 'Snapshot Saved',
      );
    } catch (e) {
      AppAlert.showError('Error taking snapshot: $e', title: 'Error');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LiveShareView(
                key: _liveShareKey,
                requestId: widget.requestId,
                fullScreen: true,
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    AppFeedback.buttonPress();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 68,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        _isMuted || _volume <= 0.01
                            ? Icons.volume_off_rounded
                            : (_volume < 0.5
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded),
                        color: _isMuted || _volume <= 0.01
                            ? Colors.redAccent
                            : Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleMute,
                      tooltip: _isMuted ? 'Unmute Audio' : 'Mute Audio',
                    ),
                    SizedBox(
                      width: 86,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: Colors.blueAccent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _isMuted ? 0.0 : _volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: _onVolumeChanged,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '${_isMuted ? 0 : (_volume * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 68,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    _isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.headphones_rounded,
                    color: _isSpeakerOn ? Colors.white70 : Colors.tealAccent,
                    size: 20,
                  ),
                  onPressed: _toggleAudioOutput,
                  tooltip: _isSpeakerOn
                      ? 'Switch to Headphones / Headset'
                      : 'Switch to Speakerphone',
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  AppFeedback.buttonPress();
                  await LiveShareService.instance.detach(widget.requestId);
                  await LiveShareService.instance
                      .stopStreamRequest(widget.requestId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.stop_circle_rounded, size: 18),
                label: Text(
                  widget.requestType == 'camera_stream'
                      ? 'Stop Camera'
                      : 'Stop Share',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                        radius: 4, backgroundColor: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      widget.requestType == 'camera_stream'
                          ? 'LIVE CAMERA STREAM'
                          : 'LIVE SCREEN SHARE',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'live_stream_take_snapshot',
                elevation: 4,
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                onPressed: _isCapturing ? null : _captureSnapshot,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  _isCapturing ? 'Saving…' : 'Screenshot',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
