import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ludo_enums.dart';
import '../theme/app_themes.dart';
import '../logic/ludo_path_provider.dart';

class LudoBoardPainter extends CustomPainter {
  final LudoThemeColors themeColors;

  LudoBoardPainter({required this.themeColors});

  @override
  void paint(Canvas canvas, Size size) {
    final double tileSize = size.width / 15.0;

    final Paint borderPaint = Paint()
      ..color = themeColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    // 1. Draw Board Background
    fillPaint.color = themeColors.boardBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

    // 2. Draw Quadrant Home Bases (Red, Green, Yellow, Blue)
    _drawHomeBase(canvas, 0, 0, tileSize, themeColors.red, PlayerColor.red);
    _drawHomeBase(canvas, 9, 0, tileSize, themeColors.green, PlayerColor.green);
    _drawHomeBase(canvas, 9, 9, tileSize, themeColors.yellow, PlayerColor.yellow);
    _drawHomeBase(canvas, 0, 9, tileSize, themeColors.blue, PlayerColor.blue);

    // 3. Draw Outer Track Grid & Paths
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        // Skip home bases and center
        if ((r < 6 && c < 6) ||
            (r < 6 && c > 8) ||
            (r > 8 && c > 8) ||
            (r > 8 && c < 6) ||
            (r >= 6 && r <= 8 && c >= 6 && c <= 8)) {
          continue;
        }

        final rect = Rect.fromLTWH(c * tileSize, r * tileSize, tileSize, tileSize);

        // Home Paths (colored)
        if (r == 7 && c >= 1 && c <= 5) {
          fillPaint.color = themeColors.red.withOpacity(0.85);
          canvas.drawRect(rect, fillPaint);
        } else if (c == 7 && r >= 1 && r <= 5) {
          fillPaint.color = themeColors.green.withOpacity(0.85);
          canvas.drawRect(rect, fillPaint);
        } else if (r == 7 && c >= 9 && c <= 13) {
          fillPaint.color = themeColors.yellow.withOpacity(0.85);
          canvas.drawRect(rect, fillPaint);
        } else if (c == 7 && r >= 9 && r <= 13) {
          fillPaint.color = themeColors.blue.withOpacity(0.85);
          canvas.drawRect(rect, fillPaint);
        }
        // Start Tiles (Solid Colored Tile for starting)
        else if (r == 6 && c == 1) {
          fillPaint.color = themeColors.red.withOpacity(0.9);
          canvas.drawRect(rect, fillPaint);
        } else if (r == 1 && c == 8) {
          fillPaint.color = themeColors.green.withOpacity(0.9);
          canvas.drawRect(rect, fillPaint);
        } else if (r == 8 && c == 13) {
          fillPaint.color = themeColors.yellow.withOpacity(0.9);
          canvas.drawRect(rect, fillPaint);
        } else if (r == 13 && c == 6) {
          fillPaint.color = themeColors.blue.withOpacity(0.9);
          canvas.drawRect(rect, fillPaint);
        }

        // Draw tile border grid line
        canvas.drawRect(rect, borderPaint);
      }
    }

    // 4. Draw Start Arrows inside Start Tiles
    _drawStartArrow(canvas, 1, 6, tileSize, '➔'); // Red Start (Right)
    _drawStartArrow(canvas, 8, 1, tileSize, '⬇'); // Green Start (Down)
    _drawStartArrow(canvas, 13, 8, tileSize, '⬅'); // Yellow Start (Left)
    _drawStartArrow(canvas, 6, 13, tileSize, '⬆'); // Blue Start (Up)

    // 5. Draw Safe Stars (The 4 Non-Start Safe Star Tiles)
    final safeStars = [
      const Point(8, 2),   // Red Star (Bottom row of left arm)
      const Point(2, 6),   // Green Star (Left col of top arm)
      const Point(6, 12),  // Yellow Star (Top row of right arm)
      const Point(12, 8),  // Blue Star (Right col of bottom arm)
    ];

    for (var star in safeStars) {
      _drawStarIcon(
          canvas, star.y * tileSize + tileSize / 2, star.x * tileSize + tileSize / 2, tileSize * 0.38);
    }

    // 6. Draw Center Finish Triangles (6..8, 6..8)
    _drawCenterHome(canvas, tileSize);

    // 7. Draw Outer Board Border
    final Paint outerBorder = Paint()
      ..color = themeColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), outerBorder);
  }

  void _drawHomeBase(Canvas canvas, int startCol, int startRow, double tileSize, Color baseColor, PlayerColor color) {
    final double left = startCol * tileSize;
    final double top = startRow * tileSize;
    final double baseWidth = tileSize * 6;

    final Paint fillPaint = Paint()
      ..color = baseColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = themeColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer color block
    canvas.drawRect(Rect.fromLTWH(left, top, baseWidth, baseWidth), fillPaint);
    canvas.drawRect(Rect.fromLTWH(left, top, baseWidth, baseWidth), borderPaint);

    // Inner white/card box for tokens
    final double innerPadding = tileSize * 1.0;
    final double innerWidth = tileSize * 4.0;
    final Rect innerRect = Rect.fromLTWH(left + innerPadding, top + innerPadding, innerWidth, innerWidth);

    final RRect innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(16));

    fillPaint.color = themeColors.boardBg;
    canvas.drawRRect(innerRRect, fillPaint);
    canvas.drawRRect(innerRRect, borderPaint);

    // 4 Base Pawn slots (circles) matching exact LudoPathProvider offsets
    for (int i = 0; i < 4; i++) {
      final point = LudoPathProvider.getBasePawnOffset(color, i);
      final double cx = point.y * tileSize;
      final double cy = point.x * tileSize;

      fillPaint.color = baseColor.withOpacity(0.18);
      canvas.drawCircle(Offset(cx, cy), tileSize * 0.65, fillPaint);

      final Paint ringPaint = Paint()
        ..color = baseColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(cx, cy), tileSize * 0.65, ringPaint);
    }
  }

  void _drawStartArrow(Canvas canvas, int col, int row, double tileSize, String arrowSymbol) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: arrowSymbol,
        style: TextStyle(
          fontSize: tileSize * 0.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double cx = (col + 0.5) * tileSize - (textPainter.width / 2);
    final double cy = (row + 0.5) * tileSize - (textPainter.height / 2);
    textPainter.paint(canvas, Offset(cx, cy));
  }

  void _drawCenterHome(Canvas canvas, double tileSize) {
    final double left = 6 * tileSize;
    final double top = 6 * tileSize;
    final double right = 9 * tileSize;
    final double bottom = 9 * tileSize;
    final double cx = 7.5 * tileSize;
    final double cy = 7.5 * tileSize;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Red Triangle (Left)
    paint.color = themeColors.red;
    Path redPath = Path()
      ..moveTo(left, top)
      ..lineTo(left, bottom)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(redPath, paint);

    // Green Triangle (Top)
    paint.color = themeColors.green;
    Path greenPath = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(greenPath, paint);

    // Yellow Triangle (Right)
    paint.color = themeColors.yellow;
    Path yellowPath = Path()
      ..moveTo(right, top)
      ..lineTo(right, bottom)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Blue Triangle (Bottom)
    paint.color = themeColors.blue;
    Path bluePath = Path()
      ..moveTo(left, bottom)
      ..lineTo(right, bottom)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Center border box
    final Paint borderPaint = Paint()
      ..color = themeColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTWH(left, top, 3 * tileSize, 3 * tileSize), borderPaint);
  }

  void _drawStarIcon(Canvas canvas, double cx, double cy, double radius) {
    final Paint starPaint = Paint()
      ..color = themeColors.safeStar
      ..style = PaintingStyle.fill;

    Path path = Path();
    double angle = -pi / 2;
    double step = pi / 5;

    for (int i = 0; i < 5; i++) {
      double x1 = cx + cos(angle) * radius;
      double y1 = cy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      angle += step;

      double x2 = cx + cos(angle) * (radius * 0.45);
      double y2 = cy + sin(angle) * (radius * 0.45);
      path.lineTo(x2, y2);
      angle += step;
    }
    path.close();

    canvas.drawPath(path, starPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) {
    return oldDelegate.themeColors != themeColors;
  }
}
