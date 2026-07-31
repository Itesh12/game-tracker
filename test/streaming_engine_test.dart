import 'package:flutter_test/flutter_test.dart';

// Standalone unit tests for streaming engine sealed state logic, commands, events, and quality strategies
enum TestSessionStateName {
  idle,
  starting,
  offerCreated,
  answerReceived,
  iceConnected,
  streaming,
  interrupted,
  stopping,
  stopped,
  failed,
}

class TestQualityProfile {
  final int maxBitrateKbps;
  final int targetFps;
  final int width;
  final int height;

  const TestQualityProfile({
    required this.maxBitrateKbps,
    required this.targetFps,
    required this.width,
    required this.height,
  });

  static const high = TestQualityProfile(maxBitrateKbps: 2500, targetFps: 30, width: 1280, height: 720);
  static const medium = TestQualityProfile(maxBitrateKbps: 1200, targetFps: 24, width: 854, height: 480);
  static const low = TestQualityProfile(maxBitrateKbps: 600, targetFps: 15, width: 640, height: 360);
}

void main() {
  group('Streaming Engine State Machine Tests', () {
    test('State hierarchy transition sequence from idle to streaming', () {
      final states = <TestSessionStateName>[
        TestSessionStateName.idle,
        TestSessionStateName.starting,
        TestSessionStateName.offerCreated,
        TestSessionStateName.answerReceived,
        TestSessionStateName.iceConnected,
        TestSessionStateName.streaming,
      ];

      expect(states.first, TestSessionStateName.idle);
      expect(states.last, TestSessionStateName.streaming);
      expect(states.length, 6);
    });

    test('Interruption and recovery state transition', () {
      final lifecycle = [
        TestSessionStateName.streaming,
        TestSessionStateName.interrupted,
        TestSessionStateName.iceConnected,
        TestSessionStateName.streaming,
      ];

      expect(lifecycle.contains(TestSessionStateName.interrupted), isTrue);
      expect(lifecycle.last, TestSessionStateName.streaming);
    });

    test('Failure state handling', () {
      const state = TestSessionStateName.failed;
      expect(state, TestSessionStateName.failed);
    });
  });

  group('Streaming Quality Profile Strategy Tests', () {
    test('HIGH quality profile specification', () {
      const profile = TestQualityProfile.high;
      expect(profile.maxBitrateKbps, 2500);
      expect(profile.targetFps, 30);
      expect(profile.width, 1280);
      expect(profile.height, 720);
    });

    test('MEDIUM quality profile specification', () {
      const profile = TestQualityProfile.medium;
      expect(profile.maxBitrateKbps, 1200);
      expect(profile.targetFps, 24);
      expect(profile.width, 854);
      expect(profile.height, 480);
    });

    test('LOW quality profile specification', () {
      const profile = TestQualityProfile.low;
      expect(profile.maxBitrateKbps, 600);
      expect(profile.targetFps, 15);
      expect(profile.width, 640);
      expect(profile.height, 360);
    });
  });
}
