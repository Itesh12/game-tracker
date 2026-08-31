import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/controllers/admin_controller.dart';

void main() {
  group('AdminController Model & Filter Logic Tests', () {
    test('AdminDevice online state logic', () {
      final now = DateTime.now();
      final recentDevice = AdminDevice(
        deviceId: 'user_1',
        username: 'Pixel 7',
        platform: 'android',
        lastSeenAt: now.subtract(const Duration(seconds: 10)),
      );
      expect(recentDevice.isOnline, isTrue);

      final staleDevice = AdminDevice(
        deviceId: 'user_2',
        username: 'iPhone 13',
        platform: 'ios',
        lastSeenAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(staleDevice.isOnline, isFalse);

      final noTimestampDevice = AdminDevice(
        deviceId: 'user_3',
        username: 'Windows Desktop',
        platform: 'windows',
      );
      expect(noTimestampDevice.isOnline, isFalse);
    });

    test('AdminDevice username resolution fallback', () {
      final deviceWithName = AdminDevice(
        deviceId: 'user_123',
        username: 'Alice',
        platform: 'android',
      );
      expect(deviceWithName.username, equals('Alice'));

      final deviceFromMap = AdminDevice.fromMap({
        'deviceId': 'user_456',
        'platform': 'ios',
      });
      expect(deviceFromMap.username, equals('user_456'));
    });

    test('ScreenshotRequestItem parsing of all request types', () {
      final screenshotReq = ScreenshotRequestItem.fromMap({
        'id': 'req_1',
        'requestType': 'screenshot',
        'targetDeviceId': 'dev_1',
        'requestedByDeviceId': 'admin_1',
        'status': 'completed',
        'screenshotUrl': 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
      });
      expect(screenshotReq.requestType, equals('screenshot'));
      expect(screenshotReq.status, equals('completed'));
      expect(screenshotReq.screenshotUrl, equals('https://res.cloudinary.com/demo/image/upload/sample.jpg'));

      final cameraReq = ScreenshotRequestItem.fromMap({
        'id': 'req_2',
        'requestType': 'camera_capture',
        'targetDeviceId': 'dev_1',
        'requestedByDeviceId': 'admin_1',
        'status': 'pending',
      });
      expect(cameraReq.requestType, equals('camera_capture'));
      expect(cameraReq.status, equals('pending'));

      final streamReq = ScreenshotRequestItem.fromMap({
        'id': 'req_3',
        'requestType': 'screen_share',
        'targetDeviceId': 'dev_2',
        'requestedByDeviceId': 'admin_1',
        'status': 'live',
      });
      expect(streamReq.requestType, equals('screen_share'));
      expect(streamReq.status, equals('live'));

      final locReq = ScreenshotRequestItem.fromMap({
        'id': 'req_4',
        'requestType': 'location_ping',
        'targetDeviceId': 'dev_3',
        'requestedByDeviceId': 'admin_1',
        'status': 'expired',
        'failureReason': 'Timed out',
      });
      expect(locReq.requestType, equals('location_ping'));
      expect(locReq.status, equals('expired'));
      expect(locReq.failureReason, equals('Timed out'));
    });
  });
}
