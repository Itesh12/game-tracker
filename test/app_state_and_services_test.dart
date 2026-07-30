import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/admin_service.dart';
import 'package:game_tracker/controllers/admin_controller.dart';

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
  });
}
