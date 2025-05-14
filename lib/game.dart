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

enum WarriorState { idle, walk, run, jump, attack1, attack2 }

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
  JoystickComponent? joystick;
  TiledComponent? mapComponent;
  Warrior? player;
  bool isRunButtonPressed = false;
  final double desiredZoom = 3.0; // Increased for better player focus
  RunButtonComponent? runBtn;
  HudButtonComponent? jumpBtn;
  HudButtonComponent? attackBtn;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the map
    try {
      mapComponent = await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
      add(mapComponent!);
    } catch (e) {
      print('Error loading map from assets: $e');
      mapComponent = null;
      camera.viewport.add(
        TextComponent(
          text: 'Failed to load map. Using fallback movement.',
          position: size / 2,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.red, fontSize: 24),
          ),
        ),
      );
    }

    // Find spawn point
    Vector2 spawn = Vector2.zero();
    try {
      if (mapComponent != null) {
        final baseLayer = mapComponent!.tileMap.getLayer<TileLayer>('Base');
        if (baseLayer != null && baseLayer.tileData != null) {
          for (var y = 0; y < baseLayer.height; y++) {
            if (y < baseLayer.tileData!.length) {
              for (var x = 0; x < baseLayer.width; x++) {
                if (x < baseLayer.tileData![y].length) {
                  final tile = baseLayer.tileData![y][x];
                  if (tile.tile != 0) {
                    spawn = Vector2(x.toDouble(), y.toDouble());
                    print('Spawn found at tile: ($x, $y)');
                    break;
                  }
                }
              }
              if (spawn != Vector2.zero()) break;
            }
          }
        } else {
          print('Warning: Base layer not found or has no tile data, using default spawn');
          camera.viewport.add(
            TextComponent(
              text: 'Base layer missing. Using fallback movement.',
              position: size / 2 + Vector2(0, 30),
              anchor: Anchor.center,
              textRenderer: TextPaint(
                style: const TextStyle(color: Colors.yellow, fontSize: 20),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error finding spawn point: $e');
    }

    // Add player
    try {
      player = Warrior(position: (spawn + Vector2(0.5, 0.5)) * 32);
      add(player!);
      camera.follow(player!, maxSpeed: 200);
    } catch (e) {
      print('Error initializing player: $e');
      camera.viewport.add(
        TextComponent(
          text: 'Failed to load player.',
          position: size / 2 + Vector2(0, 60),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.red, fontSize: 24),
          ),
        ),
      );
      return;
    }

    // Initialize UI components
    try {
      joystick = JoystickComponent(
        knob: CircleComponent(radius: 20, paint: Paint()..color = Colors.white),
        background: CircleComponent(radius: 50, paint: Paint()..color = Colors.black38),
        anchor: Anchor.bottomLeft,
        // deadZone: 0.05, // Uncomment if using Flame >= 1.10.0
      );
      runBtn = RunButtonComponent(
        onPressed: (pressed) => isRunButtonPressed = pressed,
        anchor: Anchor.bottomRight,
      );
      jumpBtn = HudButtonComponent(
        button: CircleComponent(radius: 24, paint: Paint()..color = Colors.blue),
        buttonDown: CircleComponent(radius: 24, paint: Paint()..color = Colors.blueAccent),
        anchor: Anchor.bottomRight,
        onPressed: () => player?.jump(),
      );
      attackBtn = HudButtonComponent(
        button: CircleComponent(radius: 24, paint: Paint()..color = Colors.grey),
        buttonDown: CircleComponent(radius: 24, paint: Paint()..color = Colors.grey.shade100),
        anchor: Anchor.bottomRight,
        onPressed: () => player?.attack(),
      );

      camera.viewport.addAll([joystick!, runBtn!, jumpBtn!, attackBtn!]);
    } catch (e) {
      print('Error initializing UI components: $e');
      camera.viewport.add(
        TextComponent(
          text: 'Failed to load UI.',
          position: size / 2 + Vector2(0, 90),
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.red, fontSize: 24),
          ),
        ),
      );
      return;
    }

    setCameraBounds();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = desiredZoom;
    if (joystick != null) {
      joystick!.position = Vector2(40, size.y - joystick!.size.y / 2);
    }
    if (runBtn != null) {
      runBtn!.position = Vector2(size.x - runBtn!.size.x * 2.5, size.y - runBtn!.size.y / 2);
    }
    if (jumpBtn != null) {
      jumpBtn!.position = Vector2(size.x - jumpBtn!.size.x * 1.5, size.y - jumpBtn!.size.y / 2);
    }
    if (attackBtn != null) {
      attackBtn!.position = Vector2(size.x - attackBtn!.size.x / 2, size.y - attackBtn!.size.y / 2);
    }
    setCameraBounds();
  }

  void setCameraBounds() {
    if (mapComponent == null) {
      camera.setBounds(Rectangle.fromLTRB(0, 0, size.x, size.y));
      return;
    }
    final mapWidth = mapComponent!.tileMap.map.width.toDouble();
    final mapHeight = mapComponent!.tileMap.map.height.toDouble();
    final worldSize = Vector2(mapWidth * 32, mapHeight * 32);
    final vpSize = camera.viewport.size / camera.viewfinder.zoom;

    final minX = vpSize.x / 2;
    final maxX = worldSize.x - vpSize.x / 2;
    final minY = vpSize.y / 2;
    final maxY = worldSize.y - vpSize.y / 2;

    camera.setBounds(Rectangle.fromLTRB(minX, minY, maxX, maxY));
  }
}

class RunButtonComponent extends CircleComponent with TapCallbacks {
  final void Function(bool) onPressed;
  bool _isPressed = false;

  RunButtonComponent({
    required this.onPressed,
    required Anchor anchor,
  }) : super(
    radius: 24,
    paint: Paint()..color = Colors.red,
    anchor: anchor,
  );

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    _isPressed = true;
    paint.color = Colors.redAccent;
    onPressed(true);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _isPressed = false;
    paint.color = Colors.red;
    onPressed(false);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    _isPressed = false;
    paint.color = Colors.red;
    onPressed(false);
  }
}

class Warrior extends SpriteAnimationGroupComponent<WarriorState>
    with HasGameRef<MyGame>, CollisionCallbacks {
  Vector2? _moveTarget;
  final double walkSpeed = 100;
  final double runSpeed = 200;
  int _attackPhase = 0;
  final double tileSize = 32; // Tile size for grid snapping

  Warrior({Vector2? position})
      : super(
    position: position ?? Vector2.zero(),
    size: Vector2.all(128), // Increased for better visibility
    anchor: Anchor.bottomCenter,
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
      print('Error loading warrior assets: $e');
      return;
    }

    animations = {
      WarriorState.idle: idleAnimation,
      WarriorState.walk: runAnimation,
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
      Future.delayed(const Duration(milliseconds: 300), () {
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
      Future.delayed(const Duration(milliseconds: 560), () {
        if (_attackPhase == 1) {
          _attackPhase = 2;
          current = WarriorState.attack2;
          Future.delayed(const Duration(milliseconds: 560), () {
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

    final speed = gameRef.isRunButtonPressed ? runSpeed : walkSpeed;

    if (_moveTarget == null && current != WarriorState.attack1 && current != WarriorState.attack2 && current != WarriorState.jump) {
      final delta = gameRef.joystick?.relativeDelta ?? Vector2.zero();
      if (delta != Vector2.zero()) {
        Vector2 dir = delta.normalized();
        // Snap to primary direction (horizontal or vertical)
        if (dir.x.abs() > dir.y.abs()) dir = Vector2(dir.x.sign, 0);
        else dir = Vector2(0, dir.y.sign);

        final currentTile = Vector2(
          (position.x / tileSize).floor().toDouble(),
          (position.y / tileSize).floor().toDouble(),
        );
        final nextTile = currentTile + Vector2(dir.x, dir.y);

        bool isWalkable = true;
        if (gameRef.mapComponent != null) {
          final base = gameRef.mapComponent!.tileMap.getLayer<TileLayer>('Base');
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
              isWalkable = tile.tile != 0;
              print('Tile ($nextX, $nextY) isWalkable: $isWalkable');
            } else {
              isWalkable = false;
              print('Tile ($nextX, $nextY) out of bounds');
            }
          } else {
            print('Base layer not available, using fallback movement');
          }
        }

        if (isWalkable) {
          _moveTarget = (nextTile + Vector2(0.5, 0.5)) * tileSize;
          print('Moving to target: $_moveTarget');
        }
      }
    }

    if (_moveTarget != null) {
      final toTarget = _moveTarget! - position;
      if (toTarget.length <= speed * dt) {
        position = _moveTarget!;
        _moveTarget = null;
        print('Reached target: $position');
      } else {
        position += toTarget.normalized() * speed * dt;
      }
    }

    if (current != WarriorState.attack1 && current != WarriorState.attack2 && current != WarriorState.jump) {
      if (_moveTarget != null) {
        current = gameRef.isRunButtonPressed ? WarriorState.run : WarriorState.walk;
      } else {
        current = WarriorState.idle;
      }
    }
  }
}