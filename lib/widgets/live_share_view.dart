import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/live_share_service.dart';

class LiveShareView extends StatefulWidget {
  const LiveShareView({
    super.key,
    required this.requestId,
    this.fullScreen = false,
  });

  final String requestId;
  final bool fullScreen;

  @override
  State<LiveShareView> createState() => _LiveShareViewState();
}

class _LiveShareViewState extends State<LiveShareView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;

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
      if (mounted) setState(() {});
    };
    await LiveShareService.instance.attachToRequest(widget.requestId, _renderer);
    if (mounted) {
      setState(() => _ready = true);
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
        child: _ready
            ? RTCVideoView(
                _renderer,
                mirror: false,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blueAccent),
                    SizedBox(height: 12),
                    Text(
                      'Connecting live stream…',
                      style: TextStyle(color: Colors.white, fontSize: 13),
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

class FullScreenLiveStreamPage extends StatelessWidget {
  const FullScreenLiveStreamPage({
    super.key,
    required this.requestId,
    required this.requestType,
  });

  final String requestId;
  final String requestType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LiveShareView(
                requestId: requestId,
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
                  onPressed: () => Navigator.of(context).pop(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  await LiveShareService.instance.detach(requestId);
                  await LiveShareService.instance.stopStreamRequest(requestId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.stop_circle_rounded, size: 18),
                label: Text(
                  requestType == 'camera_stream' ? 'Stop Camera' : 'Stop Share',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      requestType == 'camera_stream' ? 'LIVE CAMERA STREAM' : 'LIVE SCREEN SHARE',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
