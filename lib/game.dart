import 'dart:math';
import 'dart:ui'; // For Rect
import 'package:flame/camera.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/experimental.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum WarriorState { idle, run, jump, attack1, attack2 }

class GamePage extends StatelessWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    return Scaffold(
      body: GameWidget(game: MyGame()),
    );
  }
}

class MyGame extends FlameGame with DragCallbacks, TapCallbacks, HasCollisionDetection {
  late final JoystickComponent joystick;
  late final TiledComponent mapComponent;
  late final Warrior player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the map
    try {
      mapComponent = await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
    } catch (e) {
      print('Error loading map from assets: $e');
      try {
        mapComponent = await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
      } catch (e) {
        print('Fallback map load failed: $e');
        return;
      }
    }
    add(mapComponent);

    // Find spawn point
    final baseLayer = mapComponent.tileMap.getLayer<TileLayer>('Base');
    Vector2 spawn = Vector2.zero();
    if (baseLayer != null && baseLayer.tileData != null) {
      for (var y = 0; y < baseLayer.height; y++) {
        if (y < baseLayer.tileData!.length) {
          for (var x = 0; x < baseLayer.width; x++) {
            if (x < baseLayer.tileData![y].length) {
              final tile = baseLayer.tileData![y][x];
              if (tile.tile != 0) { // Check if tile exists
                spawn = Vector2(x.toDouble(), y.toDouble());
                break;
              }
            }
          }
          if (spawn != Vector2.zero()) break;
        }
      }
    } else {
      print('Warning: Base layer not found or has no tile data, using default spawn');
    }

    // Add player with centered position on the spawn tile
    player = Warrior(position: (spawn + Vector2(0.5, 0.5)) * 32);
    add(player);

    // Set up camera with correct bounds using dart:ui's Rect
    final mapWidth  = mapComponent.tileMap.map.width.toDouble();
    final mapHeight = mapComponent.tileMap.map.height.toDouble();

    // center the camera on your player:
    camera.follow(player, maxSpeed: 200);

    // calculate the full world size minus half the viewport, so the camera never shows beyond the edge:
    final halfViewport = camera.viewport.size / 2;
    final worldSize     = Vector2(mapWidth * 32, mapHeight * 32);

    camera.setBounds(
      Rectangle.fromCenter(
        center: Vector2.zero(),
        size: worldSize - halfViewport,               // shrink bounds by half the screen
      ),
    );

    // Add joystick to viewport (fixed bottom-left)
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: Paint()..color = Colors.grey),
      background: CircleComponent(radius: 50, paint: Paint()..color = Colors.black38),
      position: Vector2(40, size.y - 40),
      anchor: Anchor.bottomLeft,
    );
    camera.viewport.add(joystick);

    // Add jump button to viewport (fixed bottom-right)
    final jumpBtn = HudButtonComponent(
      button: CircleComponent(radius: 24, paint: Paint()..color = Colors.blue),
      buttonDown: CircleComponent(radius: 24, paint: Paint()..color = Colors.blueAccent),
      position: Vector2(size.x - 100, size.y - 40),
      anchor: Anchor.bottomRight,
      onPressed: player.jump,
    );
    camera.viewport.add(jumpBtn);

    // Add attack button to viewport (fixed bottom-right)
    final attackBtn = HudButtonComponent(
      button: CircleComponent(radius: 24, paint: Paint()..color = Colors.grey),
      buttonDown: CircleComponent(radius: 24, paint: Paint()..color = Colors.grey.shade100),
      position: Vector2(size.x - 40, size.y - 40),
      anchor: Anchor.bottomRight,
      onPressed: player.attack,
    );
    camera.viewport.add(attackBtn);
  }
}

class Warrior extends SpriteAnimationGroupComponent<WarriorState>
    with HasGameRef<MyGame>, CollisionCallbacks {
  Vector2? _moveTarget;
  final double _speed = 100;
  int _attackPhase = 0;

  Warrior({Vector2? position})
      : super(
    position: position ?? Vector2.zero(),
    size: Vector2.all(32),
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    SpriteAnimation? idleAnimation;
    SpriteAnimation? runAnimation;
    SpriteAnimation? jumpAnimation;
    SpriteAnimation? attack1Animation;
    SpriteAnimation? attack2Animation;

    try {
      final idleImg = await gameRef.images.load('Warrior/Idle.png');
      final runImg = await gameRef.images.load('Warrior/Run.png');
      final jumpImg = await gameRef.images.load('Warrior/Jump.png');
      final atk1Img = await gameRef.images.load('Warrior/Attack-1.png');
      final atk2Img = await gameRef.images.load('Warrior/Attack-2.png');

      idleAnimation = SpriteSheet.fromColumnsAndRows(image: idleImg, columns: 12, rows: 1)
          .createAnimation(row: 0, stepTime: 0.1, to: 12);
      runAnimation = SpriteSheet.fromColumnsAndRows(image: runImg, columns: 8, rows: 1)
          .createAnimation(row: 0, stepTime: 0.1, to: 8);
      jumpAnimation = SpriteSheet.fromColumnsAndRows(image: jumpImg, columns: 2, rows: 1)
          .createAnimation(row: 0, stepTime: 0.15, to: 2);
      attack1Animation = SpriteSheet.fromColumnsAndRows(image: atk1Img, columns: 7, rows: 1)
          .createAnimation(row: 0, stepTime: 0.08, to: 7);
      attack2Animation = SpriteSheet.fromColumnsAndRows(image: atk2Img, columns: 7, rows: 1)
          .createAnimation(row: 0, stepTime: 0.08, to: 7);
    } catch (e) {
      print('Error loading warrior assets from assets: $e');
      try {
        final idleImg = await gameRef.images.load('Warrior/Idle.png');
        final runImg = await gameRef.images.load('Warrior/Run.png');
        final jumpImg = await gameRef.images.load('Warrior/Jump.png');
        final atk1Img = await gameRef.images.load('Warrior/Attack-1.png');
        final atk2Img = await gameRef.images.load('Warrior/Attack-2.png');

        idleAnimation = SpriteSheet.fromColumnsAndRows(image: idleImg, columns: 12, rows: 1)
            .createAnimation(row: 0, stepTime: 0.1, to: 12);
        runAnimation = SpriteSheet.fromColumnsAndRows(image: runImg, columns: 8, rows: 1)
            .createAnimation(row: 0, stepTime: 0.1, to: 8);
        jumpAnimation = SpriteSheet.fromColumnsAndRows(image: jumpImg, columns: 2, rows: 1)
            .createAnimation(row: 0, stepTime: 0.15, to: 2);
        attack1Animation = SpriteSheet.fromColumnsAndRows(image: atk1Img, columns: 7, rows: 1)
            .createAnimation(row: 0, stepTime: 0.08, to: 7);
        attack2Animation = SpriteSheet.fromColumnsAndRows(image: atk2Img, columns: 7, rows: 1)
            .createAnimation(row: 0, stepTime: 0.08, to: 7);
      } catch (e) {
        print('Error loading warrior assets from fallback: $e');
        return;
      }
    }

    animations = {
      WarriorState.idle: idleAnimation,
      WarriorState.run: runAnimation,
      WarriorState.jump: jumpAnimation,
      WarriorState.attack1: attack1Animation,
      WarriorState.attack2: attack2Animation,
    };
    current = WarriorState.idle;

    add(RectangleHitbox());
  }

  void jump() {
    if (current != WarriorState.jump) {
      current = WarriorState.jump;
      Future.delayed(Duration(milliseconds: 300), () {
        if (current == WarriorState.jump) {
          current = WarriorState.idle;
        }
      });
    }
  }

  void attack() {
    if (_attackPhase == 0) {
      _attackPhase = 1;
      current = WarriorState.attack1;
      Future.delayed(Duration(milliseconds: 560), () {
        if (_attackPhase == 1) {
          _attackPhase = 2;
          current = WarriorState.attack2;
          Future.delayed(Duration(milliseconds: 560), () {
            _attackPhase = 0;
            current = WarriorState.idle;
          });
        }
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_moveTarget == null) {
      final delta = gameRef.joystick.relativeDelta;
      if (delta != Vector2.zero()) {
        Vector2 dir = delta.normalized();
        if (dir.x.abs() > dir.y.abs()) dir = Vector2(dir.x.sign, 0);
        else dir = Vector2(0, dir.y.sign);

        final currentTile = Vector2(
          (position.x / 32).floor().toDouble(),
          (position.y / 32).floor().toDouble(),
        );
        final nextTile = currentTile + Vector2(dir.x.toInt().toDouble(), dir.y.toInt().toDouble());

        final base = gameRef.mapComponent.tileMap.getLayer<TileLayer>('Base');
        if (base != null &&
            nextTile.x >= 0 &&
            nextTile.x < base.width &&
            nextTile.y >= 0 &&
            nextTile.y < base.height &&
            base.tileData != null) {
          final tileData = base.tileData!;
          final nextY = nextTile.y.toInt();
          final nextX = nextTile.x.toInt();
          if (nextY < tileData.length && nextX < tileData[nextY].length) {
            final tile = tileData[nextY][nextX];
            if (tile.tile != 0) { // Check if the tile is walkable
              _moveTarget = (nextTile + Vector2(0.5, 0.5)) * 32; // Center of next tile
              current = WarriorState.run;
            }
          }
        }
      }
    }

    if (_moveTarget != null) {
      final toTarget = _moveTarget! - position;
      if (toTarget.length <= _speed * dt) {
        position = _moveTarget!;
        _moveTarget = null;
        if (current == WarriorState.run) current = WarriorState.idle;
      } else {
        position += toTarget.normalized() * _speed * dt;
      }
    }
  }
}
