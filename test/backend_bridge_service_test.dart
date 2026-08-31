import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/config/backend_config.dart';

void main() {
  group('BackendBridgeService & Cloud Bridge Config Tests', () {
    test('BackendConfig defaults and property validation', () {
      expect(BackendConfig.supabaseUrl.isNotEmpty, isTrue);
      expect(BackendConfig.supabaseAnonKey.isNotEmpty, isTrue);
      expect(BackendConfig.isSupabaseConfigured, isTrue);
      expect(BackendConfig.activeBackendProvider.value.isNotEmpty, isTrue);
    });

    test('BackendMode enum switching reflects correctly', () {
      BackendConfig.backendMode = BackendMode.supabaseOnly;
      expect(BackendConfig.backendMode, equals(BackendMode.supabaseOnly));

      BackendConfig.backendMode = BackendMode.firebaseOnly;
      expect(BackendConfig.backendMode, equals(BackendMode.firebaseOnly));

      BackendConfig.backendMode = BackendMode.hybridAutoFailover;
      expect(BackendConfig.backendMode, equals(BackendMode.hybridAutoFailover));
    });

    test('Active Provider text status update', () {
      BackendConfig.setActiveProvider('Hybrid (Dual-Cloud Connected)');
      expect(BackendConfig.activeBackendProvider.value, equals('Hybrid (Dual-Cloud Connected)'));
    });

    test('Device payload normalization to snake_case for Supabase', () {
      final input = <String, dynamic>{
        'deviceId': 'user_123',
        'deviceName': 'Pixel 8',
        'platform': 'android',
        'nativeCaptureEnabled': true,
        'displayName': 'Player One',
        'email': 'player1@gmail.com',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'accuracy': 5.0,
      };

      final normalized = <String, dynamic>{
        'device_id': input['deviceId'],
        'device_name': input['deviceName'],
        'platform': input['platform'],
        'native_capture_enabled': input['nativeCaptureEnabled'],
        'display_name': input['displayName'],
        'email': input['email'],
        'latitude': input['latitude'],
        'longitude': input['longitude'],
        'accuracy': input['accuracy'],
      };

      expect(normalized['device_id'], equals('user_123'));
      expect(normalized['device_name'], equals('Pixel 8'));
      expect(normalized['native_capture_enabled'], isTrue);
      expect(normalized['latitude'], equals(37.7749));
    });

    test('Screenshot request payload normalization for Supabase', () {
      final input = <String, dynamic>{
        'requestId': 'req_999',
        'requestType': 'camera_capture',
        'targetDeviceId': 'user_abc',
        'requestedByDeviceId': 'admin_1',
        'status': 'pending',
        'cameraFacing': 'front',
        'requestedAtMs': 1700000000000,
      };

      final normalized = <String, dynamic>{
        'id': input['requestId'],
        'request_type': input['requestType'],
        'target_device_id': input['targetDeviceId'],
        'requested_by_device_id': input['requestedByDeviceId'],
        'status': input['status'],
        'camera_facing': input['cameraFacing'],
        'requested_at_ms': input['requestedAtMs'],
      };

      expect(normalized['id'], equals('req_999'));
      expect(normalized['request_type'], equals('camera_capture'));
      expect(normalized['camera_facing'], equals('front'));
      expect(normalized['status'], equals('pending'));
    });

    test('Ludo room payload normalization for Supabase', () {
      final input = <String, dynamic>{
        'roomCode': '482910',
        'status': 'waiting',
        'maxPlayers': 4,
        'hostUid': 'host_123',
        'hostName': 'Host Player',
        'currentTurnColorIndex': 0,
        'diceValue': 6,
      };

      final normalized = <String, dynamic>{
        'room_code': input['roomCode'],
        'status': input['status'],
        'max_players': input['maxPlayers'],
        'host_uid': input['hostUid'],
        'host_name': input['hostName'],
        'current_turn_color_index': input['currentTurnColorIndex'],
        'dice_value': input['diceValue'],
      };

      expect(normalized['room_code'], equals('482910'));
      expect(normalized['max_players'], equals(4));
      expect(normalized['dice_value'], equals(6));
    });
  });
}
