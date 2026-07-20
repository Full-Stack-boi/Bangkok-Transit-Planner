import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class StationMarkerPainter extends CustomPainter {
  final Color lineColor;
  final bool isInterchange;
  final Brightness brightness;
  final bool isCurrentStation;
  final double scale;

  StationMarkerPainter({
    required this.lineColor,
    required this.isInterchange,
    required this.brightness,
    this.isCurrentStation = false,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw Drop Shadow
    final shadowPaint = Paint()
      ..color = isCurrentStation
          ? Colors.green.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.26)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        (isCurrentStation ? 4.0 : 2.0) * scale,
      );

    canvas.drawCircle(
      center + Offset(0, 1.5 * scale),
      radius - (1.5 * scale),
      shadowPaint,
    );

    // 2. Draw Outer Circle (Background)
    final bgPaint = Paint()
      ..color = isCurrentStation
          ? Colors.green
          : (brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - (1.5 * scale), bgPaint);

    // 3. Draw Border
    final borderPaint = Paint()
      ..color = isCurrentStation ? Colors.white : lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentStation
          ? 4.0 * scale
          : (isInterchange ? 4.0 * scale : 3.0 * scale);
    canvas.drawCircle(
      center,
      radius - (1.5 * scale) - (borderPaint.strokeWidth / 2),
      borderPaint,
    );

    // 4. Draw Center Content
    if (isCurrentStation) {
      // Draw navigation triangle pointing up
      final path = ui.Path()
        ..moveTo(center.dx, center.dy - 6 * scale)
        ..lineTo(center.dx - 5 * scale, center.dy + 5 * scale)
        ..lineTo(center.dx, center.dy + 2 * scale)
        ..lineTo(center.dx + 5 * scale, center.dy + 5 * scale)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white);
    } else if (isInterchange) {
      // Render the exact Material icon glyph directly on the canvas
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(Icons.swap_horiz_rounded.codePoint),
        style: TextStyle(
          fontSize: 14.0 * scale,
          fontFamily: Icons.swap_horiz_rounded.fontFamily,
          package: Icons.swap_horiz_rounded.fontPackage,
          color: brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    } else {
      // Draw Inner Dot
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 3.0 * scale, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StationMarkerPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.isInterchange != isInterchange ||
        oldDelegate.brightness != brightness ||
        oldDelegate.isCurrentStation != isCurrentStation ||
        oldDelegate.scale != scale;
  }
}
