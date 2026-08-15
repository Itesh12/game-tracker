import 'dart:async';
import 'package:flutter/services.dart';

class AndroidScreenCapture {
  static const MethodChannel _channel = MethodChannel(
    'com.example.game_tracker/screen_capture',
  );

  static Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod('requestCapturePermission');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod('hasCapturePermission');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startCaptureNow() async {
    try {
      final res = await _channel.invokeMethod('startCaptureNow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startLiveShareNow(String requestId) async {
    try {
      final res = await _channel.invokeMethod('startLivePublishNow', {'requestId': requestId});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopLiveShareNow() async {
    try {
      final res = await _channel.invokeMethod('stopLivePublishNow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startCameraCaptureNow({required String cameraFacing}) async {
    try {
      final res = await _channel.invokeMethod('startCameraCaptureNow', {'cameraFacing': cameraFacing});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startLivePublishNow({required String requestId, required String cameraFacing}) async {
    try {
      final res = await _channel.invokeMethod('startLivePublishNow', {'requestId': requestId, 'cameraFacing': cameraFacing});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopLivePublishNow() async {
    try {
      final res = await _channel.invokeMethod('stopLivePublishNow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startForegroundService() async {
    try {
      final res = await _channel.invokeMethod('startForegroundService');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopForegroundService() async {
    try {
      final res = await _channel.invokeMethod('stopForegroundService');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static void Function(String? path)? _onCaptureCompleteHandler;
  static void Function(String? path)? _onCameraCaptureCompleteHandler;
  static bool _methodHandlerInstalled = false;

  static void setOnCaptureComplete(void Function(String? path) handler) {
    _onCaptureCompleteHandler = handler;
    _ensureMethodHandlerInstalled();
  }

  static void setOnCameraCaptureComplete(void Function(String? path) handler) {
    _onCameraCaptureCompleteHandler = handler;
    _ensureMethodHandlerInstalled();
  }

  static void _ensureMethodHandlerInstalled() {
    if (_methodHandlerInstalled) return;
    _methodHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCaptureComplete') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        _onCaptureCompleteHandler?.call(args == null ? null : args['path'] as String?);
      } else if (call.method == 'onCameraCaptureComplete') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        _onCameraCaptureCompleteHandler?.call(args == null ? null : args['path'] as String?);
      }
    });
  }
}
