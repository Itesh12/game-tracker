import 'dart:async';
import 'package:flutter/services.dart';

class CommandPlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.game_tracker/command_platform',
  );

  static Future<Map<String, dynamic>> executeCommand({
    required String type,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final result = await _channel.invokeMethod('executeCommand', {
        'type': type,
        'payload': payload,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      return {
        'status': 'PIPELINE_ERROR',
        'reason': e.message ?? 'Platform exception occurred',
      };
    } catch (e) {
      return {
        'status': 'PIPELINE_ERROR',
        'reason': e.toString(),
      };
    }
  }
}
