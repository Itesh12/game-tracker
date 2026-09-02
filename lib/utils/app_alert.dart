import 'package:alert_info/alert_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_feedback.dart';

class AppAlert {
  AppAlert._();

  static String? _lastMessage;
  static DateTime? _lastAlertTime;
  static const Duration _duplicateThrottle = Duration(milliseconds: 1500);

  /// Centralized alert presenter with bottom positioning, horizontal margin, dismissability, and spam suppression
  static void show(
    String message, {
    String? title,
    TypeInfo typeInfo = TypeInfo.info,
    BuildContext? context,
    int duration = 2,
    MessagePosition position = MessagePosition.bottom,
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

    // Tactile vibration feedback: ONLY for error or success, NEVER vibrate on info
    if (typeInfo == TypeInfo.error) {
      AppFeedback.error();
    } else if (typeInfo == TypeInfo.success) {
      AppFeedback.success();
    }

    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) {
      debugPrint('[AppAlert] No context available for alert: $displayText');
      return;
    }

    try {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }

      Color bgColor;
      Color accentColor;
      IconData iconData;

      switch (typeInfo) {
        case TypeInfo.error:
          bgColor = const Color(0xFF7F1D1D);
          accentColor = const Color(0xFFEF4444);
          iconData = Icons.error_outline_rounded;
          break;
        case TypeInfo.success:
          bgColor = const Color(0xFF14532D);
          accentColor = const Color(0xFF22C55E);
          iconData = Icons.check_circle_outline_rounded;
          break;
        case TypeInfo.warning:
          bgColor = const Color(0xFF7C2D12);
          accentColor = const Color(0xFFF97316);
          iconData = Icons.warning_amber_rounded;
          break;
        case TypeInfo.info:
          bgColor = const Color(0xFF0F172A);
          accentColor = const Color(0xFF38BDF8);
          iconData = Icons.info_outline_rounded;
          break;
      }

      Get.rawSnackbar(
        snackPosition: position == MessagePosition.top ? SnackPosition.TOP : SnackPosition.BOTTOM,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 12,
        backgroundColor: bgColor,
        borderColor: accentColor.withOpacity(0.4),
        borderWidth: 1,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
        duration: Duration(seconds: duration),
        messageText: Row(
          children: [
            Icon(iconData, color: accentColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
              },
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white60,
                size: 18,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[AppAlert] Error presenting alert: $e');
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
