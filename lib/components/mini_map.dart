import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../game.dart';

class MiniMap extends PositionComponent with HasGameRef<MyGame>, TapCallbacks {
  late SpriteComponent mapSprite;
  late CircleComponent playerDot;
  late Vector2 miniMapSize;
  List<Vector2> pathPoints = [];

  // Enhanced styling properties
  final Paint backgroundPaint = Paint()..color = Colors.black.withOpacity(0.7);
  final Paint borderPaint = Paint()
    ..color = Colors.white.withOpacity(0.8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint pathPaint = Paint()
    ..color = Colors.purple.withOpacity(0.7)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  // Configuration
  final double playerDotRadius;
  final bool showBorder;
  final Color playerDotColor;
  final bool pulsePlayerDot;
  final double cornerRadius;
  final double borderPadding;

  // Map world bounds tracking for accurate positioning
  late final Vector2 _worldSize;
  late final Vector2 _mapScale;

  MiniMap(
      ui.Image fullMapImage,
      Vector2 miniMapSize, {
        this.playerDotRadius = 4,
        this.showBorder = true,
        this.playerDotColor = Colors.red,
        this.pulsePlayerDot = false,
        this.cornerRadius = 8.0,
        this.borderPadding = 4.0,
      }) : super(size: miniMapSize) {
    this.miniMapSize = miniMapSize;

    // Calculate the content area size (accounting for borders)
    final contentSize = Vector2(miniMapSize.x - (borderPadding * 2),
        miniMapSize.y - (borderPadding * 2));

    // Create map sprite with appropriate size to fit within borders
    mapSprite = SpriteComponent.fromImage(
      fullMapImage,
      size: contentSize,
      position: Vector2(borderPadding, borderPadding),
    );
    add(mapSprite);

    // Create player dot
    playerDot = CircleComponent(
      radius: playerDotRadius,
      paint: Paint()..color = playerDotColor,
    );
    add(playerDot);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Store world size and calculate scaling factors for accurate positioning
    _worldSize = gameRef.worldSize.clone();
    _mapScale = Vector2(
      (miniMapSize.x - (borderPadding * 2)) / _worldSize.x,
      (miniMapSize.y - (borderPadding * 2)) / _worldSize.y,
    );
  }

  Vector2 _worldToMiniMap(Vector2 worldPos) {
    return Vector2(
      worldPos.x * _mapScale.x + borderPadding,
      worldPos.y * _mapScale.y + borderPadding,
    );
  }

  Vector2 _miniMapToWorld(Vector2 miniMapPos) {
    return Vector2(
      (miniMapPos.x - borderPadding) / _mapScale.x,
      (miniMapPos.y - borderPadding) / _mapScale.y,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update player position on mini-map
    if (gameRef.player != null) {
      playerDot.position = _worldToMiniMap(gameRef.player!.position);
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Draw semi-transparent rounded rectangle background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
      backgroundPaint,
    );

    // Clip to rounded rectangle shape
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    canvas.clipPath(path);

    // Render map and components
    super.render(canvas);

    // Draw path if available
    if (pathPoints.isNotEmpty) {
      final pathPainter = Path();

      // Start at first point
      pathPainter.moveTo(pathPoints[0].x, pathPoints[0].y);

      // Add line segments
      for (int i = 1; i < pathPoints.length; i++) {
        pathPainter.lineTo(pathPoints[i].x, pathPoints[i].y);
      }

      canvas.drawPath(pathPainter, pathPaint);

      // Draw dots at waypoints
      final waypointPaint = Paint()..color = Colors.yellow;
      for (int i = 1; i < pathPoints.length - 1; i++) {
        canvas.drawCircle(
          Offset(pathPoints[i].x, pathPoints[i].y),
          1.5,
          waypointPaint,
        );
      }
    }

    // Draw border if enabled
    if (showBorder) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            borderPaint.strokeWidth / 2,
            borderPaint.strokeWidth / 2,
            size.x - borderPaint.strokeWidth,
            size.y - borderPaint.strokeWidth,
          ),
          Radius.circular(cornerRadius - borderPaint.strokeWidth / 2),
        ),
        borderPaint,
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final localPos = event.localPosition;

    // Calculate accurate world position from mini-map position
    final worldPos = _miniMapToWorld(Vector2(localPos.x, localPos.y));

    // Validate that the tap is within playable world bounds
    final isValidTap = worldPos.x >= 0 &&
        worldPos.x <= _worldSize.x &&
        worldPos.y >= 0 &&
        worldPos.y <= _worldSize.y;

    if (!isValidTap) return;

    // Highlight tap location with a visual effect
    final tapIndicator = CircleComponent(
      radius: 5,
      paint: Paint()..color = Colors.blue.withOpacity(0.7),
      position: Vector2(localPos.x, localPos.y),
    );
    add(tapIndicator);

    // Fade out and remove the tap indicator
    tapIndicator.add(
      ScaleEffect.by(
        Vector2.all(2.0),
        EffectController(duration: 0.5, curve: Curves.easeOut),
        onComplete: () {
          tapIndicator.removeFromParent();
        },
      ),
    );
    tapIndicator.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.5),
      ),
    );

    // Find path
    final path = gameRef.findPath(gameRef.player!.position, worldPos);
    if (path.isNotEmpty) {
      pathPoints = path.map((wp) => _worldToMiniMap(wp)).toList();
    } else {
      pathPoints = [];
    }
  }

  // Method to clear the current path
  void clearPath() {
    pathPoints = [];
  }
}
