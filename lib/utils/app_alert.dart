import 'package:alert_info/alert_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppAlert {
  AppAlert._();

  static String? _lastMessage;
  static DateTime? _lastAlertTime;
  static const Duration _duplicateThrottle = Duration(milliseconds: 1500);

  /// Centralized alert presenter using `alert_info` with built-in spam and duplicate suppression
  static void show(
    String message, {
    String? title,
    TypeInfo typeInfo = TypeInfo.info,
    BuildContext? context,
    int duration = 2,
    MessagePosition position = MessagePosition.top,
  }) {
    final now = DateTime.now();
    final displayText = (title != null && title.isNotEmpty) ? '$title: $message' : message;

    // Suppress rapid identical spam alerts
    if (_lastMessage == displayText &&
        _lastAlertTime != null &&
        now.difference(_lastAlertTime!) < _duplicateThrottle) {
      return;
    }

    _lastMessage = displayText;
    _lastAlertTime = now;

    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) {
      debugPrint('[AppAlert] No context available for alert: $displayText');
      return;
    }

    try {
      AlertInfo.show(
        context: targetContext,
        text: displayText,
        typeInfo: typeInfo,
        position: position,
        duration: duration,
        padding: 24.0,
      );
    } catch (e) {
      debugPrint('[AppAlert] Error presenting alert_info: $e');
    }
  }

  static void showSuccess(
    String message, {
    String? title,
    BuildContext? context,
    int duration = 2,
  }) {
    show(
      message,
      title: title,
      typeInfo: TypeInfo.success,
      context: context,
      duration: duration,
    );
  }

  static void showError(
    String message, {
    String? title,
    BuildContext? context,
    int duration = 3,
  }) {
    show(
      message,
      title: title,
      typeInfo: TypeInfo.error,
      context: context,
      duration: duration,
    );
  }

  static void showWarning(
    String message, {
    String? title,
    BuildContext? context,
    int duration = 2,
  }) {
    show(
      message,
      title: title,
      typeInfo: TypeInfo.warning,
      context: context,
      duration: duration,
    );
  }

  static void showInfo(
    String message, {
    String? title,
    BuildContext? context,
    int duration = 2,
  }) {
    show(
      message,
      title: title,
      typeInfo: TypeInfo.info,
      context: context,
      duration: duration,
    );
  }
}
