import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/admin_service.dart';

void main() {
  group('AdminService request payloads', () {
    test('builds camera capture request payload with camera facing', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'camera_capture',
        targetDeviceId: 'device-1',
        requestedByDeviceId: 'admin-device',
        cameraFacing: 'back',
      );

      expect(payload['requestType'], 'camera_capture');
      expect(payload['targetDeviceId'], 'device-1');
      expect(payload['requestedByDeviceId'], 'admin-device');
      expect(payload['cameraFacing'], 'back');
      expect(payload['status'], 'pending');
    });

    test('builds camera stream request payload with camera facing', () {
      final payload = AdminService.buildRequestPayload(
        requestType: 'camera_stream',
        targetDeviceId: 'device-2',
        requestedByDeviceId: 'admin-device',
        cameraFacing: 'front',
      );

      expect(payload['requestType'], 'camera_stream');
      expect(payload['targetDeviceId'], 'device-2');
      expect(payload['cameraFacing'], 'front');
    });
  });
}
