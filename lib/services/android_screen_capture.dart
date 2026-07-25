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

  static void setOnCaptureComplete(void Function(String? path) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCaptureComplete') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        handler(args == null ? null : args['path'] as String?);
      }
    });
  }
}
