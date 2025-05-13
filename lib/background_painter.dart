import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'constants.dart';

class DungeonBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background fill
    final bgPaint =
    Paint()
      ..color = DungeonColors.background
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Draw grid
    final gridPaint =
    Paint()
      ..color = DungeonColors.dungeonWall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const gridSize = 40.0;

    for (double x = 0; x < width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    for (double y = 0; y < height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Draw some "torches" as light sources
    _drawTorch(canvas, Offset(width * 0.25, height * 0.25));
    _drawTorch(canvas, Offset(width * 0.75, height * 0.25));
    _drawTorch(canvas, Offset(width * 0.25, height * 0.75));
    _drawTorch(canvas, Offset(width * 0.75, height * 0.75));

    // Draw some random stones/rocks
    final random = math.Random(42); // Fixed seed for consistent drawing

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final size = 4.0 + random.nextDouble() * 8.0;

      final stonePaint =
      Paint()
        ..color = Color.fromARGB(
          255,
          100 + random.nextInt(40),
          100 + random.nextInt(40),
          120 + random.nextInt(40),
        );

      canvas.drawCircle(Offset(x, y), size, stonePaint);
    }
  }

  void _drawTorch(Canvas canvas, Offset position) {
    // Draw light glow
    final gradient = RadialGradient(
      colors: [
        DungeonColors.torchGlow.withOpacity(0.3),
        DungeonColors.torch.withOpacity(0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final rect = Rect.fromCircle(center: position, radius: 100.0);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawCircle(position, 100.0, paint);

    // Draw torch base
    final torchPaint = Paint()..color = const Color(0xFF994400);
    canvas.drawRect(
      Rect.fromCenter(center: position, width: 6.0, height: 20.0),
      torchPaint,
    );

    // Draw flame
    final flamePaint = Paint()..color = DungeonColors.torch;
    final path =
    Path()
      ..moveTo(position.dx - 5, position.dy - 20)
      ..lineTo(position.dx + 5, position.dy - 20)
      ..lineTo(position.dx, position.dy - 35)
      ..close();

    canvas.drawPath(path, flamePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}