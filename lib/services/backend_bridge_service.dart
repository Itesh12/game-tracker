import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/backend_config.dart';
import '../firebase_options.dart';

class BackendBridgeService {
  static bool _isFirebaseReady = false;
  static bool _isSupabaseReady = false;

  static bool get isFirebaseReady => _isFirebaseReady;
  static bool get isSupabaseReady => _isSupabaseReady;

  static SupabaseClient? get supabase =>
      _isSupabaseReady ? Supabase.instance.client : null;

  static FirebaseFirestore? get firestore =>
      _isFirebaseReady ? FirebaseFirestore.instance : null;

  /// Initialize both Firebase and Supabase cloud connectors
  static Future<void> initialize() async {
    // 1. Initialize Firebase Core with options and timeout
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 4));
      }
      _isFirebaseReady = true;
      debugPrint('[BackendBridge] Firebase initialized successfully.');
    } catch (e) {
      _isFirebaseReady = false;
      debugPrint('[BackendBridge] Firebase initialization warning: $e');
    }

    // 2. Initialize Supabase if configured with timeout
    if (BackendConfig.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: BackendConfig.supabaseUrl,
          anonKey: BackendConfig.supabaseAnonKey,
          realtimeClientOptions: const RealtimeClientOptions(
            eventsPerSecond: 10,
          ),
        ).timeout(const Duration(seconds: 4));
        _isSupabaseReady = true;
        debugPrint('[BackendBridge] Supabase initialized successfully.');
      } catch (e) {
        _isSupabaseReady = false;
        debugPrint('[BackendBridge] Supabase initialization warning: $e');
      }
    } else {
      debugPrint(
          '[BackendBridge] Supabase using default placeholder (Configure in backend_config.dart if desired).');
    }

    _updateActiveProviderState();
  }

  static void _updateActiveProviderState() {
    if (BackendConfig.backendMode == BackendMode.supabaseOnly &&
        _isSupabaseReady) {
      BackendConfig.setActiveProvider('Supabase (Enforced)');
    } else if (BackendConfig.backendMode == BackendMode.firebaseOnly &&
        _isFirebaseReady) {
      BackendConfig.setActiveProvider('Firebase (Enforced)');
    } else if (_isFirebaseReady && _isSupabaseReady) {
      BackendConfig.setActiveProvider(
          'Hybrid (Firebase + Supabase Dual Active)');
    } else if (_isFirebaseReady) {
      BackendConfig.setActiveProvider('Firebase (Primary)');
    } else if (_isSupabaseReady) {
      BackendConfig.setActiveProvider('Supabase (Failover Active)');
    } else {
      BackendConfig.setActiveProvider('Offline / Local Only');
    }
  }

  // ===========================================================================
  // DUAL-CLOUD DEVICE REGISTRATION & LOCATION
  // ===========================================================================

  static Future<void> syncDeviceRegistration(Map<String, dynamic> data) async {
    final deviceId = data['deviceId'] as String?;
    if (deviceId == null || deviceId.isEmpty) return;

    // 1. Primary Write to Firestore
    if (_isFirebaseReady &&
        BackendConfig.backendMode != BackendMode.supabaseOnly) {
      try {
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Firestore device register failed: $e');
      }
    }

    // 2. Dual-Mirror Write to Supabase
    if (_isSupabaseReady &&
        BackendConfig.backendMode != BackendMode.firebaseOnly) {
      try {
        final supabaseData = {
          'device_id': deviceId,
          'platform': data['platform'] ?? 'android',
          'display_name': data['displayName'] ?? '',
          'email': data['email'] ?? '',
          'native_capture_enabled': data['nativeCaptureEnabled'] ?? false,
          'last_seen_at': DateTime.now().toIso8601String(),
        };
        await supabase!
            .from('devices')
            .upsert(supabaseData)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint(
            '[BackendBridge] Supabase device register mirror failed: $e');
      }
    }
  }

  static Future<void> updateDeviceLocation({
    required String deviceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required int timestamp,
  }) async {
    // 1. Firestore Write
    if (_isFirebaseReady &&
        BackendConfig.backendMode != BackendMode.supabaseOnly) {
      try {
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .update({
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'lastLocationTime': timestamp,
          'lastSeenAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Firestore location update failed: $e');
      }
    }

    // 2. Supabase Mirror Write
    if (_isSupabaseReady &&
        BackendConfig.backendMode != BackendMode.firebaseOnly) {
      try {
        await supabase!
            .from('devices')
            .update({
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'last_location_time': timestamp,
              'last_seen_at': DateTime.now().toIso8601String(),
            })
            .eq('device_id', deviceId)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Supabase location update failed: $e');
      }
    }
  }

  // ===========================================================================
  // DUAL-CLOUD COMMANDS & SCREENSHOT REQUESTS
  // ===========================================================================

  static Future<String> createScreenshotRequest(
      Map<String, dynamic> requestPayload) async {
    final String rawId = requestPayload['requestId'] as String? ?? '';
    final String requestId = rawId.isNotEmpty
        ? rawId
        : DateTime.now().millisecondsSinceEpoch.toString();
    requestPayload['requestId'] = requestId;

    bool firestoreSuccess = false;

    // 1. Write to Firestore
    if (_isFirebaseReady &&
        BackendConfig.backendMode != BackendMode.supabaseOnly) {
      try {
        await FirebaseFirestore.instance
            .collection('screenshot_requests')
            .doc(requestId)
            .set(requestPayload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
        firestoreSuccess = true;
      } catch (e) {
        debugPrint('[BackendBridge] Firestore create request failed: $e');
      }
    }

    // 2. Dual-Mirror / Fallback Write to Supabase
    if (_isSupabaseReady &&
        (BackendConfig.backendMode != BackendMode.firebaseOnly ||
            !firestoreSuccess)) {
      try {
        final supabaseRow = {
          'id': requestId,
          'target_device_id': requestPayload['targetDeviceId'] ?? '',
          'requested_by_device_id': requestPayload['requestedByDeviceId'] ?? '',
          'request_type': requestPayload['requestType'] ?? 'screenshot',
          'camera_facing': requestPayload['cameraFacing'] ?? 'front',
          'status': requestPayload['status'] ?? 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        };
        await supabase!
            .from('screenshot_requests')
            .upsert(supabaseRow)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Supabase create request failed: $e');
      }
    }

    return requestId;
  }

  static Future<void> updateScreenshotRequest(
    String requestId,
    Map<String, dynamic> updates,
  ) async {
    // 1. Firestore Update
    if (_isFirebaseReady &&
        BackendConfig.backendMode != BackendMode.supabaseOnly) {
      try {
        await FirebaseFirestore.instance
            .collection('screenshot_requests')
            .doc(requestId)
            .update(updates)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Firestore request update failed: $e');
      }
    }

    // 2. Supabase Mirror Update
    if (_isSupabaseReady &&
        BackendConfig.backendMode != BackendMode.firebaseOnly) {
      try {
        final Map<String, dynamic> supabaseUpdates = {};
        if (updates.containsKey('status'))
          supabaseUpdates['status'] = updates['status'];
        if (updates.containsKey('screenshotUrl')) {
          supabaseUpdates['screenshot_url'] = updates['screenshotUrl'];
        }
        if (updates.containsKey('error'))
          supabaseUpdates['error'] = updates['error'];
        if (updates.containsKey('failureReason')) {
          supabaseUpdates['failure_reason'] = updates['failureReason'];
        }
        if (updates.containsKey('completedAt')) {
          supabaseUpdates['completed_at'] = DateTime.now().toIso8601String();
        }
        if (updates.containsKey('startedAt')) {
          supabaseUpdates['started_at'] = DateTime.now().toIso8601String();
        }
        if (updates.containsKey('stoppedAt')) {
          supabaseUpdates['stopped_at'] = DateTime.now().toIso8601String();
        }

        if (supabaseUpdates.isNotEmpty) {
          await supabase!
              .from('screenshot_requests')
              .update(supabaseUpdates)
              .eq('id', requestId)
              .timeout(const Duration(seconds: 3));
        }
      } catch (e) {
        debugPrint('[BackendBridge] Supabase request update failed: $e');
      }
    }
  }

  // ===========================================================================
  // DUAL-CLOUD LUDO ONLINE MULTIPLAYER
  // ===========================================================================

  static Future<void> saveLudoRoomData(
      String roomCode, Map<String, dynamic> roomData) async {
    // 1. Firestore Write
    if (_isFirebaseReady &&
        BackendConfig.backendMode != BackendMode.supabaseOnly) {
      try {
        await FirebaseFirestore.instance
            .collection('ludo_rooms')
            .doc(roomCode)
            .set(roomData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Firestore saveLudoRoom failed: $e');
      }
    }

    // 2. Supabase Mirror Write
    if (_isSupabaseReady &&
        BackendConfig.backendMode != BackendMode.firebaseOnly) {
      try {
        final supabaseData = {
          'id': roomCode,
          'room_code': roomCode,
          'host_uid': roomData['hostUid'] ?? '',
          'status': roomData['status'] ?? 'waiting',
          'current_turn_index': roomData['currentTurnIndex'] ?? 0,
          'dice_value': roomData['diceValue'] ?? 1,
          'is_dice_rolled': roomData['isDiceRolled'] ?? false,
          'is_moving': roomData['isMoving'] ?? false,
          'consecutive_sixes': roomData['consecutiveSixes'] ?? 0,
          'players_json': roomData['players'] ?? [],
          'game_state_json': roomData['gameStateData'] ?? {},
          'updated_at': DateTime.now().toIso8601String(),
        };
        await supabase!
            .from('ludo_rooms')
            .upsert(supabaseData)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BackendBridge] Supabase saveLudoRoom mirror failed: $e');
      }
    }
  }
}
