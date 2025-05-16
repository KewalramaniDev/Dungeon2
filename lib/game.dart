import 'dart:math';
import 'dart:ui' as ui; // Explicitly import dart:ui with alias
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

class MyGame extends FlameGame with HasCollisionDetection, HasWorld {
  // Create a CameraComponent to properly follow the warrior
  late final CameraComponent cameraComponent;
  late final World gameWorld;

  JoystickComponent? joystick;
  TiledComponent? mapComponent;
  TileLayer? baseLayer; // Store Base layer
  TileLayer? wallLayer; // Store Wall layer
  Warrior? player;
  bool isRunButtonPressed = false;
  final double tileSize = 32; // Tile size for grid calculations
  RoundImageButtonComponent? runBtn;
  RoundImageButtonComponent? jumpBtn;
  RoundImageButtonComponent? attackBtn;
  int spawnTileX = 3; // Manual spawn point X-coordinate
  int spawnTileY = 8; // Manual spawn point Y-coordinate
  double focusRadius = 10.0; // Default radius for focus effect

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set focus radius based on platform
    if (kIsWeb) {
      focusRadius = 10.0; // Larger radius for web/desktop
    } else {
      focusRadius = 5.0; // Smaller radius for mobile devices
    }

    // Create the world first
    gameWorld = World();

    // Initialize the camera with appropriate viewfinder settings
    final viewportResolution = Vector2(size.x, size.y);
    cameraComponent = CameraComponent(
      world: gameWorld,
      viewport: FixedSizeViewport(viewportResolution.x, viewportResolution.y),
    );

    // Add camera to the game
    add(cameraComponent);

    // Add the world to the game
    add(gameWorld);

    // Configure camera zoom based on device
    double zoomLevel =
        kIsWeb ? 4.0 : 3.0; // Less zoom on mobile for better visibility
    cameraComponent.viewfinder.zoom = zoomLevel;

    // Load the map
    try {
      mapComponent =
          await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
      gameWorld
          .add(mapComponent!); // Add map to the world, not directly to the game

      // Store Base and Wall layers
      baseLayer = mapComponent!.tileMap.getLayer<TileLayer>('Base');
      wallLayer = mapComponent!.tileMap.getLayer<TileLayer>('Wall');
      if (baseLayer == null || wallLayer == null) {
        print('Warning: Base or Wall layer not found');
        cameraComponent.viewport.add(
          TextComponent(
            text: 'Base or Wall layer missing. Using fallback movement.',
            position: size / 2 + Vector2(0, 30),
            anchor: Anchor.center,
            textRenderer: TextPaint(
              style: const TextStyle(color: Colors.yellow, fontSize: 20),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error loading map from assets: $e');
      mapComponent = null;
      cameraComponent.viewport.add(
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

    // Set spawn point manually
    try {
      Vector2 spawnPosition =
          Vector2(spawnTileX.toDouble() + 0.5, spawnTileY.toDouble() + 0.5) *
              tileSize;
      player = Warrior(position: spawnPosition);

      // Add player to the world, not directly to the game
      gameWorld.add(player!);

      // Configure camera to follow the player and set bounds separately
      cameraComponent.follow(player!);
      final bounds = getWorldBounds();
      cameraComponent.setBounds(bounds);
    } catch (e) {
      print('Error initializing player: $e');
      cameraComponent.viewport.add(
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
        background:
            CircleComponent(radius: 50, paint: Paint()..color = Colors.black38),
        anchor: Anchor.bottomLeft,
      );

      // Load button images
      final runImage = await images.load('run.png');
      final jumpImage = await images.load('jump.png');
      final attackImage = await images.load('attack.png');

      runBtn = RoundImageButtonComponent(
        onPressed: (pressed) => isRunButtonPressed = pressed,
        isHold: true,
        image: runImage,
        anchor: Anchor.bottomRight,
      );

      jumpBtn = RoundImageButtonComponent(
        onPressed: (pressed) {
          if (!pressed) player?.jump();
        },
        isHold: false,
        image: jumpImage,
        anchor: Anchor.bottomRight,
      );

      attackBtn = RoundImageButtonComponent(
        onPressed: (pressed) {
          if (!pressed) player?.attack();
        },
        isHold: false,
        image: attackImage,
        anchor: Anchor.bottomRight,
      );

      // Add UI elements to the viewport, not the world
      cameraComponent.viewport
          .addAll([joystick!, runBtn!, jumpBtn!, attackBtn!]);
    } catch (e) {
      print('Error initializing UI components: $e');
      cameraComponent.viewport.add(
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
  }

  // Get the world bounds based on the map size
  Rectangle getWorldBounds() {
    if (mapComponent == null) {
      return Rectangle.fromLTRB(0, 0, size.x, size.y);
    }
    final mapWidth = mapComponent!.tileMap.map.width.toDouble();
    final mapHeight = mapComponent!.tileMap.map.height.toDouble();
    final worldSize = Vector2(mapWidth * tileSize, mapHeight * tileSize);

    // Calculate the visible area in world coordinates
    final vpSize =
        cameraComponent.viewport.size / cameraComponent.viewfinder.zoom;

    // Set camera boundaries to keep character centered
    final minX = vpSize.x / 2;
    final maxX = worldSize.x - vpSize.x / 2;
    final minY = vpSize.y / 2;
    final maxY = worldSize.y - vpSize.y / 2;

    return Rectangle.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Ensure camera is always following the player
    if (player != null && cameraComponent != null) {
      cameraComponent.follow(player!);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (joystick != null) {
      joystick!.position = Vector2(40, size.y - 40);
    }

    // Pyramid layout for buttons
    const double buttonRadius = 24; // Radius of round buttons
    const double buttonDiameter = buttonRadius * 2; // 48 pixels
    const double buttonMarginX = 12; // Increased for better edge spacing
    const double buttonMarginY = 12;
    const double buttonSpaceX = 12; // Space between jump and attack buttons
    const double buttonSpaceY = 12; // Space between run and lower buttons

    if (attackBtn != null) {
      attackBtn!.position = Vector2(size.x - buttonMarginX - buttonRadius,
          size.y - buttonMarginY - buttonRadius);
    }
    if (jumpBtn != null && attackBtn != null) {
      jumpBtn!.position = Vector2(
        attackBtn!.position.x - buttonDiameter - buttonSpaceX,
        attackBtn!.position.y,
      );
    }
    if (runBtn != null && jumpBtn != null && attackBtn != null) {
      double centerXJump = jumpBtn!.position.x;
      double centerXAttack = attackBtn!.position.x;
      double averageCenterX = (centerXJump + centerXAttack) / 2;
      runBtn!.position = Vector2(
        averageCenterX,
        jumpBtn!.position.y - buttonDiameter - buttonSpaceY,
      );
    }

    // Update camera bounds when screen is resized
    if (player != null && cameraComponent != null) {
      cameraComponent.setBounds(getWorldBounds());
    }
  }
}

class RoundImageButtonComponent extends CircleComponent with TapCallbacks {
  final void Function(bool) onPressed;
  final bool
      isHold; // True for hold actions (run), false for tap actions (jump, attack)

  RoundImageButtonComponent({
    required this.onPressed,
    required this.isHold,
    required ui.Image image,
    required Anchor anchor,
  }) : super(
          radius: 24, // Fixed radius for small round buttons
          paint: Paint()..color = Colors.black54, // Black with opacity 54/255
          anchor: anchor,
        ) {
    // Add image as child SpriteComponent
    final imageSprite = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2(40, 40), // Fixed size for images to fit within circle
      anchor: Anchor.center,
      position: Vector2(24, 24), // Center within the 48x48 circle
    );
    add(imageSprite);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isHold) {
      onPressed(true);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    onPressed(false);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    if (isHold) {
      onPressed(false);
    }
  }
}

class Warrior extends SpriteAnimationGroupComponent<WarriorState>
    with HasGameRef<MyGame>, CollisionCallbacks {
  Vector2? _moveTarget;
  final double walkSpeed = 100;
  final double runSpeed = 200;
  int _attackPhase = 0;
  final double tileSize = 32; // Tile size for grid snapping
  Vector2? _preAttackPosition; // Store position before attack
  bool isFacingLeft = false; // Track facing direction
  bool _isFlipped = false; // Track current flip state
  bool isJumping = false; // Jump state
  double? originalY; // Original Y position before jump
  double jumpProgress = 0; // Progress through jump duration
  double jumpTotalTime = 0.6; // Total jump duration in seconds
  double jumpHeight = 50; // Jump height in pixels

  Warrior({Vector2? position})
      : super(
          position: position ?? Vector2.zero(),
          size: Vector2(150, 70), // Increased for better visibility
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

      // Debug: Print image sizes
      print('Idle image size: ${idleImg.width}x${idleImg.height}');
      print('Run image size: ${runImg.width}x${runImg.height}');
      print('Jump image size: ${jumpImg.width}x${jumpImg.height}');
      print('Attack-1 image size: ${atk1Img.width}x${atk1Img.height}');
      print('Attack-2 image size: ${atk2Img.width}x${atk2Img.height}');

      idleAnimation =
          SpriteSheet.fromColumnsAndRows(image: idleImg, columns: 12, rows: 1)
              .createAnimation(row: 0, stepTime: 0.1, to: 12);
      runAnimation =
          SpriteSheet.fromColumnsAndRows(image: runImg, columns: 8, rows: 1)
              .createAnimation(row: 0, stepTime: 0.1, to: 8);
      jumpAnimation =
          SpriteSheet.fromColumnsAndRows(image: jumpImg, columns: 2, rows: 1)
              .createAnimation(row: 0, stepTime: 0.15, to: 2);
      attack1Animation =
          SpriteSheet.fromColumnsAndRows(image: atk1Img, columns: 7, rows: 1)
              .createAnimation(row: 0, stepTime: 0.08, to: 7);
      attack2Animation =
          SpriteSheet.fromColumnsAndRows(image: atk2Img, columns: 7, rows: 1)
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

    // Add a visual indicator based on the platform
    final highlightRadius = gameRef.focusRadius;
    add(WarriorHighlight(radius: highlightRadius));
  }

  void jump() {
    if (!isJumping) {
      isJumping = true;
      originalY = position.y;
      jumpProgress = 0;
      current = WarriorState.jump;
    }
  }

  void attack() {
    if (_attackPhase == 0) {
      _preAttackPosition = position.clone(); // Store position before attack
      _attackPhase = 1;
      current = WarriorState.attack1;
      print('Switching to attack1 state at position: $position');
      Future.delayed(const Duration(milliseconds: 560), () {
        if (_attackPhase == 1) {
          _attackPhase = 2;
          current = WarriorState.attack2;
          position = _preAttackPosition!; // Restore position
          print('Switching to attack2 state at position: $position');
          Future.delayed(const Duration(milliseconds: 560), () {
            _attackPhase = 0;
            current = WarriorState.idle;
            position = _preAttackPosition!; // Restore position
            _preAttackPosition = null;
            print('Returning to idle state at position: $position');
          });
        }
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle jump effect
    if (isJumping && originalY != null) {
      jumpProgress += dt;
      if (jumpProgress < jumpTotalTime) {
        double u = pi * jumpProgress / jumpTotalTime;
        double fraction = sin(u);
        position.y = originalY! -
            jumpHeight * (fraction * fraction); // Parabolic trajectory
      } else {
        position.y = originalY!; // Reset to original y position
        isJumping = false;
        current = WarriorState.idle;
        originalY = null;
      }
    }

    final speed = gameRef.isRunButtonPressed ? runSpeed : walkSpeed;

    if (_moveTarget == null &&
        current != WarriorState.attack1 &&
        current != WarriorState.attack2 &&
        !isJumping) {
      final delta = gameRef.joystick?.relativeDelta ?? Vector2.zero();
      if (delta != Vector2.zero()) {
        Vector2 dir = delta.normalized();
        // Snap to primary direction (horizontal or vertical)
        if (dir.x.abs() > dir.y.abs())
          dir = Vector2(dir.x.sign, 0);
        else
          dir = Vector2(0, dir.y.sign);

        // Update facing direction
        if (dir.x == -1) {
          isFacingLeft = true;
        } else if (dir.x == 1) {
          isFacingLeft = false;
        }

        final currentTile = Vector2(
          (position.x / tileSize).floor().toDouble(),
          (position.y / tileSize).floor().toDouble(),
        );
        final nextTile = currentTile + Vector2(dir.x, dir.y);

        bool isWalkable = false;
        if (gameRef.baseLayer != null && gameRef.wallLayer != null) {
          final baseTileData = gameRef.baseLayer!.tileData;
          final wallTileData = gameRef.wallLayer!.tileData;
          final nextY = nextTile.y.toInt();
          final nextX = nextTile.x.toInt();
          if (nextY >= 0 &&
              nextY < gameRef.baseLayer!.height &&
              nextX >= 0 &&
              nextX < gameRef.baseLayer!.width &&
              baseTileData != null &&
              wallTileData != null &&
              nextY < baseTileData.length &&
              nextX < baseTileData[nextY].length &&
              nextY < wallTileData.length &&
              nextX < wallTileData[nextY].length) {
            final baseTile = baseTileData[nextY][nextX];
            final wallTile = wallTileData[nextY][nextX];
            isWalkable = (baseTile.tile != 0) && (wallTile.tile == 0);
            print(
                'Tile ($nextX, $nextY) isWalkable: $isWalkable, Base gid: ${baseTile.tile}, Wall gid: ${wallTile.tile}');
          } else {
            print('Tile ($nextX, $nextY) out of bounds');
          }
        } else {
          print('Base or Wall layer not available, using fallback movement');
          isWalkable = true; // Fallback: allow movement if layers are missing
        }

        if (isWalkable) {
          _moveTarget = (nextTile + Vector2(0.8, 0.8)) * tileSize;
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

    if (current != WarriorState.attack1 &&
        current != WarriorState.attack2 &&
        !isJumping) {
      if (_moveTarget != null) {
        current =
            gameRef.isRunButtonPressed ? WarriorState.run : WarriorState.walk;
      } else {
        current = WarriorState.idle;
      }
    }

    // Apply horizontal flip based on facing direction
    if (isFacingLeft && !_isFlipped) {
      flipHorizontally();
      _isFlipped = true;
    } else if (!isFacingLeft && _isFlipped) {
      flipHorizontally();
      _isFlipped = false;
    }
  }
}

// Platform-specific visual highlight component for the warrior
class WarriorHighlight extends CircleComponent {
  WarriorHighlight({required double radius})
      : super(
          radius: radius,
          paint: Paint()
            ..color = Colors.white.withOpacity(0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
          anchor: Anchor.center,
          position: Vector2(0,
              -15), // Position slightly above the anchor point of the warrior
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Add a subtle inner highlight
    final innerPaint = Paint()
      ..color = Colors.blue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, radius * 0.7, innerPaint);
  }
}
