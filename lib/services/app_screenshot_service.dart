import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class AppScreenshotService {
  AppScreenshotService._();

  static final GlobalKey screenshotKey = GlobalKey(
    debugLabel: 'app_screenshot',
  );
  static Uint8List? _lastCapturedScreenshotBytes;
  static bool _isCapturing = false;

  static Future<Uint8List?> captureScreenshot() async {
    final freshBytes = await captureAndCacheCurrentFrame();
    if (freshBytes != null) {
      return freshBytes;
    }
    return _lastCapturedScreenshotBytes;
  }

  static Future<Uint8List?> captureAndCacheCurrentFrame() async {
    if (_isCapturing) {
      return _lastCapturedScreenshotBytes;
    }

    _isCapturing = true;
    try {
      final screenshotBytes = await _captureFromCurrentView();
      if (screenshotBytes != null) {
        _lastCapturedScreenshotBytes = screenshotBytes;
      }
      return screenshotBytes;
    } catch (error) {
      debugPrint('Screenshot capture failed: $error');
      return _lastCapturedScreenshotBytes;
    } finally {
      _isCapturing = false;
    }
  }

  static Future<Uint8List?> _captureFromCurrentView() async {
    try {
      final renderObject = screenshotKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        return null;
      }

      final pixelRatio =
          PlatformDispatcher.instance.views.first.devicePixelRatio;
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (error) {
      debugPrint('Screenshot capture failed: $error');
      return null;
    }
  }
}
