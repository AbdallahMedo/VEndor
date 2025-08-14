import 'package:flutter/material.dart';

class WatermarkPainter extends CustomPainter {
  final String text;
  final double angle;
  final double opacity;

  WatermarkPainter({
    required this.text,
    this.angle = -0.5,
    this.opacity = 0.05,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.black.withOpacity(opacity),
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    painter.layout();

    final double stepX = painter.width * 3;
    final double stepY = painter.height * 3;

    for (double y = 0; y < size.height + stepY; y += stepY) {
      for (double x = -size.width; x < size.width * 2; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
