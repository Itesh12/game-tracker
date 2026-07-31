import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/admin_service.dart';

void main() {
  group('AdminService & Device Metadata Tests', () {
    test('platformName returns a valid target platform identifier', () {
      final name = AdminService.platformName;
      expect(['android', 'ios', 'macos', 'windows', 'linux', 'unknown'].contains(name), isTrue);
    });

    test('adminSecret security string check', () {
      expect(AdminService.adminSecret, 'LudoKingdomAdmin2026!');
    });

    test('buildRequestPayload formats all standard fields for screenshot request', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'screenshot',
        targetDeviceId: 'target-device-001',
        requestedByDeviceId: 'admin-device-999',
      );

      expect(payload['requestType'], 'screenshot');
      expect(payload['targetDeviceId'], 'target-device-001');
      expect(payload['requestedByDeviceId'], 'admin-device-999');
      expect(payload['status'], 'pending');
      expect(payload['requestedAt'], isNotNull);
    });

    test('buildRequestPayload formats optional cameraFacing for stream requests', () {
      final payloadFront = AdminService.buildRequestPayload(
        requestType: 'camera_stream',
        targetDeviceId: 'target-device-002',
        requestedByDeviceId: 'admin-device-999',
        cameraFacing: 'front',
      );
      expect(payloadFront['cameraFacing'], 'front');

      final payloadBack = AdminService.buildRequestPayload(
        requestType: 'camera_stream',
        targetDeviceId: 'target-device-002',
        requestedByDeviceId: 'admin-device-999',
        cameraFacing: 'back',
      );
      expect(payloadBack['cameraFacing'], 'back');
    });

    test('extractCloudinaryPublicId handles root images and subfolder paths', () {
      const urlRoot = 'https://res.cloudinary.com/dsuaryuxj/image/upload/v1700000/my_root_photo.jpg';
      expect(AdminService.extractCloudinaryPublicId(urlRoot), 'my_root_photo');

      const urlSubfolder = 'https://res.cloudinary.com/dsuaryuxj/image/upload/v1700000/users/123/avatar.png';
      expect(AdminService.extractCloudinaryPublicId(urlSubfolder), 'users/123/avatar');
    });
  });
}
