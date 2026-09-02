import 'package:flutter/services.dart';

class AppFeedback {
  AppFeedback._();

  /// Strong tactile haptic feedback for admin actions and button presses
  static void buttonPress() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Event fired feedback (commands dispatched, stream connected, alerts triggered, etc.)
  static void eventFired() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Light selection / change feedback (e.g. dropdown item selected)
  static void selectionChanged() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Success / completed feedback
  static void success() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Error / alert feedback
  static void error() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
