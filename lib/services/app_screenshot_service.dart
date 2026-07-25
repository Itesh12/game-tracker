import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class AppScreenshotService {
  AppScreenshotService._();

  static final GlobalKey screenshotKey = GlobalKey(debugLabel: 'app_screenshot');

  static Future<Uint8List?> captureScreenshot() async {
    try {
      final renderObject = screenshotKey.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary) {
        final pixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;
        final image = await renderObject.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      }
    } catch (error) {
      debugPrint('Screenshot capture failed: $error');
    }
    return null;
  }
}
