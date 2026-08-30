import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class LiveShareSession {
  final String requestId;
  final RTCPeerConnection peerConnection;
  final RTCVideoRenderer renderer;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _requestSub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _iceSub;
  bool _isDisposed = false;
  MediaStream? _localStream;

  LiveShareSession({
    required this.requestId,
    required this.peerConnection,
    required this.renderer,
  });

  Future<void> initialize() async {
    await renderer.initialize();

    peerConnection.onTrack = (event) {
      if (event.track.kind == 'video') {
        if (event.streams.isNotEmpty) {
          renderer.srcObject = event.streams[0];
        }
      }
    };

    peerConnection.onAddStream = (stream) {
      renderer.srcObject = stream;
    };

    peerConnection.onIceCandidate = (candidate) async {
      if (_isDisposed) return;
      await FirebaseFirestore.instance
          .collection('screenshot_requests')
          .doc(requestId)
          .collection('iceCandidates')
          .add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'from': 'admin',
          });
    };

    final requestDoc = FirebaseFirestore.instance
        .collection('screenshot_requests')
        .doc(requestId);

    bool hasSetOffer = false;

    _requestSub = requestDoc.snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      final data = snapshot.data();
      if (data == null) return;
      final offer = data['offer'];
      if (!hasSetOffer && offer is Map && offer['sdp'] != null) {
        hasSetOffer = true;
        try {
          final remoteDescription = RTCSessionDescription(
            offer['sdp'] as String,
            offer['type'] as String? ?? 'offer',
          );
          await peerConnection.setRemoteDescription(remoteDescription);
          final answer = await peerConnection.createAnswer({});
          await peerConnection.setLocalDescription(answer);
          await requestDoc.set({
            'answer': {
              'sdp': answer.sdp,
              'type': answer.type,
            },
            'status': 'live',
          }, SetOptions(merge: true));
        } catch (e) {
          // ignore duplicate state transition
        }
      }
    });

    _iceSub = requestDoc.collection('iceCandidates').snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      for (final candidateDoc in snapshot.docs) {
        final data = candidateDoc.data();
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
    await _requestSub.cancel();
    await _iceSub.cancel();
    await peerConnection.close();
    await renderer.dispose();
    await _localStream?.dispose();
  }
}

class LiveSharePublisherSession {
  final String requestId;
  final RTCPeerConnection peerConnection;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _requestSub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _iceSub;
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
      await FirebaseFirestore.instance
          .collection('screenshot_requests')
          .doc(requestId)
          .collection('iceCandidates')
          .add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'from': 'publisher',
          });
    };

    final requestDoc = FirebaseFirestore.instance
        .collection('screenshot_requests')
        .doc(requestId);
    final offer = await peerConnection.createOffer({});
    await peerConnection.setLocalDescription(offer);
    await requestDoc.set({
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
      'status': 'offer_created',
    }, SetOptions(merge: true));

    _requestSub = requestDoc.snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      final data = snapshot.data();
      if (data == null) return;
      final answer = data['answer'];
      if (answer is Map<String, dynamic> && answer['sdp'] != null) {
        final remoteDescription = RTCSessionDescription(
          answer['sdp'] as String,
          answer['type'] as String? ?? 'answer',
        );
        await peerConnection.setRemoteDescription(remoteDescription);
      }
    });

    _iceSub = requestDoc.collection('iceCandidates').snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      for (final candidateDoc in snapshot.docs) {
        final data = candidateDoc.data();
        if (data['from'] == 'publisher') continue;
        final candidate = RTCIceCandidate(
          data['candidate'] as String? ?? '',
          data['sdpMid'] as String? ?? '0',
          (data['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        );
        await peerConnection.addCandidate(candidate);
      }
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _requestSub.cancel();
    await _iceSub.cancel();
    await peerConnection.close();
    await _localStream?.dispose();
  }
}

class LiveShareService {
  LiveShareService._();

  static final LiveShareService instance = LiveShareService._();

  final Map<String, LiveShareSession> _sessions = {};
  final Map<String, LiveSharePublisherSession> _publishers = {};

  Future<void> attachToRequest(String requestId, RTCVideoRenderer renderer) async {
    if (_sessions.containsKey(requestId)) {
      return;
    }
    final configuration = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
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
      await FirebaseFirestore.instance
          .collection('screenshot_requests')
          .doc(requestId)
          .set({
        'status': 'stopped',
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
