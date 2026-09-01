import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'backend_bridge_service.dart';

class LiveShareSession {
  final String requestId;
  final RTCPeerConnection peerConnection;
  final RTCVideoRenderer renderer;
  late final StreamSubscription<Map<String, dynamic>?> _requestSub;
  late final StreamSubscription<List<Map<String, dynamic>>> _iceSub;
  bool _isDisposed = false;
  MediaStream? _localStream;

  LiveShareSession({
    required this.requestId,
    required this.peerConnection,
    required this.renderer,
  });

  Future<void> initialize() async {
    await renderer.initialize();

    try {
      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    } catch (_) {}

    peerConnection.onTrack = (event) async {
      if (event.track.kind == 'video') {
        try {
          event.track.enabled = true;
        } catch (_) {}
        if (event.streams.isNotEmpty) {
          renderer.srcObject = event.streams[0];
        } else {
          try {
            final stream = await createLocalMediaStream('remote_stream_${DateTime.now().millisecondsSinceEpoch}');
            await stream.addTrack(event.track);
            renderer.srcObject = stream;
          } catch (_) {}
        }
      }
    };

    peerConnection.onAddStream = (stream) {
      try {
        for (final track in stream.getVideoTracks()) {
          track.enabled = true;
        }
      } catch (_) {}
      renderer.srcObject = stream;
    };

    peerConnection.onIceCandidate = (candidate) async {
      if (_isDisposed) return;
      await BackendBridgeService.addIceCandidate(requestId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'from': 'admin',
      });
    };

    bool hasSetOffer = false;

    Future<void> handleOfferPayload(dynamic offer) async {
      if (!hasSetOffer && offer is Map && offer['sdp'] != null) {
        hasSetOffer = true;
        try {
          final remoteDescription = RTCSessionDescription(
            offer['sdp'] as String,
            offer['type'] as String? ?? 'offer',
          );
          await peerConnection.setRemoteDescription(remoteDescription);
          final answerConstraints = <String, dynamic>{
            'mandatory': {
              'OfferToReceiveVideo': true,
              'OfferToReceiveAudio': false,
            },
            'optional': [],
          };
          final answer = await peerConnection.createAnswer(answerConstraints);
          await peerConnection.setLocalDescription(answer);
          await BackendBridgeService.updateScreenshotRequest(requestId, {
            'answer': {
              'sdp': answer.sdp,
              'type': answer.type,
            },
            'status': 'live',
          });
        } catch (e) {
          // ignore duplicate state transition
        }
      }
    }

    _requestSub = BackendBridgeService.streamScreenshotRequest(requestId).listen((data) async {
      if (_isDisposed || data == null) return;
      if (data['offer'] != null) {
        await handleOfferPayload(data['offer']);
      }
      final lastIce = data['last_ice_candidate'];
      if (lastIce is Map && lastIce['candidate'] != null && lastIce['from'] != 'admin') {
        final candidate = RTCIceCandidate(
          lastIce['candidate'] as String? ?? '',
          lastIce['sdpMid'] as String? ?? '0',
          (lastIce['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
        try {
          await peerConnection.addCandidate(candidate);
        } catch (_) {}
      }
    });

    _iceSub = BackendBridgeService.streamIceCandidates(requestId).listen((candidateList) async {
      if (_isDisposed) return;
      for (final data in candidateList) {
        if (data['from'] == 'admin') continue;
        final candidate = RTCIceCandidate(
          data['candidate'] as String? ?? '',
          data['sdpMid'] as String? ?? '0',
          (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
        try {
          await peerConnection.addCandidate(candidate);
        } catch (_) {}
      }
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;
    try {
      await _requestSub.cancel();
    } catch (_) {}
    try {
      await _iceSub.cancel();
    } catch (_) {}
    try {
      renderer.srcObject = null;
    } catch (_) {}
    try {
      await peerConnection.close();
    } catch (_) {}
    try {
      await peerConnection.dispose();
    } catch (_) {}
    try {
      await _localStream?.dispose();
    } catch (_) {}
  }
}

class LiveSharePublisherSession {
  final String requestId;
  final RTCPeerConnection peerConnection;
  late final StreamSubscription<Map<String, dynamic>?> _requestSub;
  late final StreamSubscription<List<Map<String, dynamic>>> _iceSub;
  MediaStream? _localStream;
  bool _isDisposed = false;

  LiveSharePublisherSession({
    required this.requestId,
    required this.peerConnection,
  });

  Future<void> initialize({required String cameraFacing}) async {
    final mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'facingMode': cameraFacing == 'back' ? 'environment' : 'user',
      },
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    final videoTrack = _localStream!.getVideoTracks().first;
    await peerConnection.addTrack(videoTrack, _localStream!);

    peerConnection.onIceCandidate = (candidate) async {
      if (_isDisposed) return;
      await BackendBridgeService.addIceCandidate(requestId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'from': 'publisher',
      });
    };

    final offer = await peerConnection.createOffer({});
    await peerConnection.setLocalDescription(offer);
    await BackendBridgeService.updateScreenshotRequest(requestId, {
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
      'status': 'offer_created',
    });

    bool hasSetAnswer = false;

    Future<void> handleAnswerPayload(dynamic answer) async {
      if (!hasSetAnswer && answer is Map && answer['sdp'] != null) {
        hasSetAnswer = true;
        try {
          final remoteDescription = RTCSessionDescription(
            answer['sdp'] as String,
            answer['type'] as String? ?? 'answer',
          );
          await peerConnection.setRemoteDescription(remoteDescription);
        } catch (_) {}
      }
    }

    _requestSub = BackendBridgeService.streamScreenshotRequest(requestId).listen((data) async {
      if (_isDisposed || data == null) return;
      await handleAnswerPayload(data['answer']);
    });

    _iceSub = BackendBridgeService.streamIceCandidates(requestId).listen((candidateList) async {
      if (_isDisposed) return;
      for (final data in candidateList) {
        if (data['from'] == 'publisher') continue;
        final candidate = RTCIceCandidate(
          data['candidate'] as String? ?? '',
          data['sdpMid'] as String? ?? '0',
          (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
        try {
          await peerConnection.addCandidate(candidate);
        } catch (_) {}
      }
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;
    try {
      await _requestSub.cancel();
    } catch (_) {}
    try {
      await _iceSub.cancel();
    } catch (_) {}
    try {
      await peerConnection.close();
    } catch (_) {}
    try {
      await peerConnection.dispose();
    } catch (_) {}
    try {
      await _localStream?.dispose();
    } catch (_) {}
  }
}

class LiveShareService {
  LiveShareService._();

  static final LiveShareService instance = LiveShareService._();

  final Map<String, LiveShareSession> _sessions = {};
  final Map<String, LiveSharePublisherSession> _publishers = {};

  Future<void> attachToRequest(String requestId, RTCVideoRenderer renderer) async {
    await detach(requestId);
    final configuration = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun.cloudflare.com:3478'},
        {'urls': 'stun:openrelay.metered.ca:80'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelay',
          'credential': 'openrelay',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelay',
          'credential': 'openrelay',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelay',
          'credential': 'openrelay',
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    final peerConnection = await createPeerConnection(configuration);
    final session = LiveShareSession(
      requestId: requestId,
      peerConnection: peerConnection,
      renderer: renderer,
    );
    _sessions[requestId] = session;
    await session.initialize();
  }

  Future<void> startPublisher(String requestId, {required String cameraFacing}) async {
    if (_publishers.containsKey(requestId)) {
      return;
    }
    final configuration = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final peerConnection = await createPeerConnection(configuration);
    final publisher = LiveSharePublisherSession(
      requestId: requestId,
      peerConnection: peerConnection,
    );
    _publishers[requestId] = publisher;
    await publisher.initialize(cameraFacing: cameraFacing);
  }

  Future<void> detach(String requestId) async {
    final session = _sessions.remove(requestId);
    if (session != null) {
      await session.dispose();
    }
    final publisher = _publishers.remove(requestId);
    if (publisher != null) {
      await publisher.dispose();
    }
  }

  Future<void> stopStreamRequest(String requestId) async {
    await detach(requestId);
    try {
      await BackendBridgeService.updateScreenshotRequest(requestId, {
        'status': 'stopped',
        'completedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
