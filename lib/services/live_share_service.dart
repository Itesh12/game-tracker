import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  MediaStreamTrack? _remoteAudioTrack;
  double _volume = 1.0;
  bool _isMuted = false;

  MediaStreamTrack? get remoteAudioTrack => _remoteAudioTrack;
  double get volume => _volume;
  bool get isMuted => _isMuted;

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    _isMuted = _volume == 0.0;
    _remoteAudioTrack?.enabled = !_isMuted;
    if (_remoteAudioTrack != null) {
      try {
        await Helper.setVolume(_volume, _remoteAudioTrack!);
      } catch (_) {}
    }
  }

  Future<void> toggleMute() async {
    if (_isMuted) {
      _isMuted = false;
      if (_volume <= 0.05) _volume = 0.8;
      _remoteAudioTrack?.enabled = true;
      if (_remoteAudioTrack != null) {
        try {
          await Helper.setVolume(_volume, _remoteAudioTrack!);
        } catch (_) {}
      }
    } else {
      _isMuted = true;
      _remoteAudioTrack?.enabled = false;
      if (_remoteAudioTrack != null) {
        try {
          await Helper.setVolume(0.0, _remoteAudioTrack!);
        } catch (_) {}
      }
    }
  }

  Future<void> setSpeakerphoneOn(bool enable) async {
    try {
      await Helper.setSpeakerphoneOn(enable);
    } catch (_) {}
  }

  LiveShareSession({
    required this.requestId,
    required this.peerConnection,
    required this.renderer,
  });

  Future<void> initialize() async {
    if (renderer.textureId == null) {
      try {
        await renderer.initialize();
      } catch (_) {}
    }

    try {
      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    } catch (_) {}

    // Configure audio output asynchronously without blocking signaling or connection initialization
    Future.microtask(() async {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
    });

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
      } else if (event.track.kind == 'audio') {
        _remoteAudioTrack = event.track;
        try {
          event.track.enabled = !_isMuted;
        } catch (_) {}
      }
    };

    peerConnection.onAddStream = (stream) {
      try {
        for (final track in stream.getVideoTracks()) {
          track.enabled = true;
        }
        for (final track in stream.getAudioTracks()) {
          _remoteAudioTrack = track;
          track.enabled = !_isMuted;
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

    String? lastHandledOfferSdp;

    Future<void> handleOfferPayload(dynamic offerRaw, String? status) async {
      if (status == 'reconnecting') return;
      if (offerRaw == null) return;
      Map<dynamic, dynamic>? offer;
      if (offerRaw is Map) {
        offer = offerRaw;
      } else if (offerRaw is String && offerRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(offerRaw);
          if (decoded is Map) offer = decoded;
        } catch (_) {}
      }

      if (offer != null && offer['sdp'] != null) {
        final sdp = offer['sdp'] as String;
        if (sdp == lastHandledOfferSdp) return;
        lastHandledOfferSdp = sdp;
        try {
          final remoteDescription = RTCSessionDescription(
            sdp,
            offer['type'] as String? ?? 'offer',
          );
          await peerConnection.setRemoteDescription(remoteDescription);
          final answerConstraints = <String, dynamic>{
            'mandatory': {
              'OfferToReceiveVideo': true,
              'OfferToReceiveAudio': true,
            },
            'optional': [],
          };
          final answer = await peerConnection.createAnswer(answerConstraints);
          await peerConnection.setLocalDescription(answer);

          // Wait up to 1000ms for ICE candidates to gather into localDescription
          int waited = 0;
          while (waited < 1000 && peerConnection.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
            await Future.delayed(const Duration(milliseconds: 100));
            waited += 100;
          }
          final finalAnswer = await peerConnection.getLocalDescription();
          final sdpToSend = finalAnswer?.sdp ?? answer.sdp;

          await BackendBridgeService.updateScreenshotRequest(requestId, {
            'answer': {
              'sdp': sdpToSend,
              'type': answer.type ?? 'answer',
            },
            'status': 'live',
          });
        } catch (e) {
          debugPrint('Error handling offer payload: $e');
        }
      }
    }

    _requestSub = BackendBridgeService.streamScreenshotRequest(requestId).listen((data) async {
      if (_isDisposed || data == null) return;
      final status = data['status'] as String?;
      dynamic offerPayload = data['offer'];
      if (offerPayload == null) {
        final screenUrl = data['screenshot_url'] as String? ?? data['screenshotUrl'] as String?;
        if (screenUrl != null && screenUrl.startsWith('OFFER:')) {
          offerPayload = screenUrl.substring(6);
        }
      }
      if (offerPayload != null) {
        await handleOfferPayload(offerPayload, status);
      }

      dynamic lastIcePayload = data['last_ice_candidate'];
      if (lastIcePayload == null) {
        final errStr = data['error'] as String?;
        if (errStr != null && errStr.startsWith('ICE:')) {
          lastIcePayload = errStr.substring(4);
        }
      }
      if (lastIcePayload != null) {
        Map<dynamic, dynamic>? lastIce;
        if (lastIcePayload is Map) {
          lastIce = lastIcePayload;
        } else if (lastIcePayload is String && lastIcePayload.isNotEmpty) {
          try {
            final decoded = jsonDecode(lastIcePayload);
            if (decoded is Map) lastIce = decoded;
          } catch (_) {}
        }

        if (lastIce != null && lastIce['candidate'] != null && lastIce['from'] != 'admin') {
          final candidate = RTCIceCandidate(
            lastIce['candidate'] as String? ?? '',
            lastIce['sdpMid'] as String? ?? '0',
            (lastIce['sdpMLineIndex'] as num?)?.toInt() ?? 0,
          );
          try {
            await peerConnection.addCandidate(candidate);
          } catch (_) {}
        }
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

  LiveShareSession? getSession(String requestId) => _sessions[requestId];

  Future<void> attachToRequest(String requestId, RTCVideoRenderer renderer) async {
    await detach(requestId);

    try {
      final initialData = await BackendBridgeService.streamScreenshotRequest(requestId).first.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );
      final currentStatus = initialData?['status'] as String? ?? '';
      final isAlreadyRunning = currentStatus == 'live' ||
          currentStatus == 'active' ||
          currentStatus == 'offer_created';

      if (isAlreadyRunning) {
        debugPrint('[LiveShareService] Stream $requestId is already active ($currentStatus). Signaling reconnection to publisher...');
        await BackendBridgeService.updateScreenshotRequest(requestId, {
          'status': 'reconnecting',
          'reconnect_epoch': DateTime.now().millisecondsSinceEpoch,
          'answer': null,
        });
      }
    } catch (e) {
      debugPrint('[LiveShareService] Error checking initial status for $requestId: $e');
    }

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
