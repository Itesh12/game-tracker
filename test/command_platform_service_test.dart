import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tracker/services/command_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.example.game_tracker/command_platform');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'executeCommand') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          final type = args['type'] as String;

          return {
            'status': 'SUCCESS',
            'commandId': 'cmd_mock_123',
            'traceId': 'trace_mock_123',
            'featureId': 'FEATURE_$type',
            'durationMs': 15,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('CommandPlatformService executes PING command via unified IPC bridge', () async {
    final result = await CommandPlatformService.executeCommand(
      type: 'PING',
      payload: {'echoMessage': 'UNITY_PING'},
    );

    expect(result['status'], equals('SUCCESS'));
    expect(result['featureId'], equals('FEATURE_PING'));
    expect(result['commandId'], equals('cmd_mock_123'));
  });

  test('CommandPlatformService executes SCREENSHOT command via unified IPC bridge', () async {
    final result = await CommandPlatformService.executeCommand(
      type: 'SCREENSHOT',
      payload: {'quality': 90},
    );

    expect(result['status'], equals('SUCCESS'));
    expect(result['featureId'], equals('FEATURE_SCREENSHOT'));
  });

  test('CommandPlatformService executes CAMERA command via unified IPC bridge', () async {
    final result = await CommandPlatformService.executeCommand(
      type: 'CAMERA',
      payload: {'cameraFacing': 'FRONT'},
    );

    expect(result['status'], equals('SUCCESS'));
    expect(result['featureId'], equals('FEATURE_CAMERA'));
  });

  test('CommandPlatformService executes LOCATION command via unified IPC bridge', () async {
    final result = await CommandPlatformService.executeCommand(
      type: 'LOCATION',
      payload: {'highAccuracy': true},
    );

    expect(result['status'], equals('SUCCESS'));
    expect(result['featureId'], equals('FEATURE_LOCATION'));
  });
}
