import 'package:flutter_test/flutter_test.dart';

class MockAdminDevice {
  final String deviceId;
  final String username;
  final DateTime? lastSeenAt;

  MockAdminDevice({
    required this.deviceId,
    required this.username,
    this.lastSeenAt,
  });
}

List<MockAdminDevice> deduplicateDevices(List<MockAdminDevice> rawList) {
  final Map<String, MockAdminDevice> uniqueMap = {};
  for (final dev in rawList) {
    final key = dev.username.trim().toLowerCase();
    if (!uniqueMap.containsKey(key)) {
      uniqueMap[key] = dev;
    } else {
      final existing = uniqueMap[key]!;
      if (dev.lastSeenAt != null &&
          (existing.lastSeenAt == null || dev.lastSeenAt!.isAfter(existing.lastSeenAt!))) {
        uniqueMap[key] = dev;
      }
    }
  }
  return uniqueMap.values.toList();
}

void main() {
  group('Admin Device Deduplication Unit Tests', () {
    test('Deduplicates multiple logins from the same user keeping the latest lastSeenAt record', () {
      final now = DateTime.now();
      final olderTime = now.subtract(const Duration(hours: 2));
      final newerTime = now.subtract(const Duration(minutes: 5));

      final rawList = [
        MockAdminDevice(
          deviceId: 'device_17220000_111',
          username: 'itesh@gmail.com',
          lastSeenAt: olderTime,
        ),
        MockAdminDevice(
          deviceId: 'user_abc123xyz',
          username: 'itesh@gmail.com',
          lastSeenAt: newerTime,
        ),
      ];

      final result = deduplicateDevices(rawList);
      expect(result.length, 1);
      expect(result.first.deviceId, 'user_abc123xyz');
      expect(result.first.lastSeenAt, newerTime);
    });

    test('Case-insensitive username deduplication', () {
      final now = DateTime.now();
      final rawList = [
        MockAdminDevice(
          deviceId: 'device-1',
          username: 'John.Doe@example.com',
          lastSeenAt: now,
        ),
        MockAdminDevice(
          deviceId: 'device-2',
          username: 'john.doe@example.com',
          lastSeenAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      final result = deduplicateDevices(rawList);
      expect(result.length, 1);
      expect(result.first.username, 'John.Doe@example.com');
    });

    test('Preserves distinct unique users', () {
      final now = DateTime.now();
      final rawList = [
        MockAdminDevice(deviceId: 'user_1', username: 'Alice', lastSeenAt: now),
        MockAdminDevice(deviceId: 'user_2', username: 'Bob', lastSeenAt: now),
        MockAdminDevice(deviceId: 'user_3', username: 'Charlie', lastSeenAt: now),
      ];

      final result = deduplicateDevices(rawList);
      expect(result.length, 3);
    });
  });
}
