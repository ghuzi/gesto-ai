import 'package:flutter/material.dart';

/// The soft wave that closes the gradient hero, matching the web page.
class WavePainter extends StatelessWidget {
  const WavePainter({super.key, required this.color, this.height = 44});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WavePainter(color: color)),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.17,
        size.height,
        size.width * 0.33,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.85,
        size.width * 0.83,
        size.height * 0.2,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
