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
    await LiveShareService.instance.attachToRequest(widget.requestId, _renderer);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    LiveShareService.instance.detach(widget.requestId);
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoContent = Container(
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 12),
        child: _ready
            ? RTCVideoView(_renderer, mirror: false)
            : const Center(
                child: Text(
                  'Connecting live stream…',
                  style: TextStyle(color: Colors.white),
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
      body: Stack(
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
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                requestType == 'camera_stream' ? 'Camera Live Stream' : 'Screen Share',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
