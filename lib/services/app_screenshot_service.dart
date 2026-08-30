import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class AppScreenshotService {
  AppScreenshotService._();

  static final GlobalKey screenshotKey = GlobalKey(
    debugLabel: 'app_screenshot',
  );

  static Future<Uint8List?> captureScreenshot() async {
    return _captureFromCurrentView();
  }

  static Future<Uint8List?> captureAndCacheCurrentFrame() async {
    return _captureFromCurrentView();
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
      debugPrint('In-app frame capture skipped: $error');
      return null;
    }
  }
}
