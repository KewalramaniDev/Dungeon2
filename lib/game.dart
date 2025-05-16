import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/experimental.dart';
import 'package:flame/sprite.dart';
import 'package:flame/image_composition.dart';
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
  TileLayer? baseLayer;
  TileLayer? wallLayer;
  Warrior? player;
  bool isRunButtonPressed = false;
  final double desiredZoom = 2.0;
  final double tileSize = 32;
  RoundImageButtonComponent? runBtn;
  RoundImageButtonComponent? jumpBtn;
  RoundImageButtonComponent? attackBtn;
  int spawnTileX = 3;
  int spawnTileY = 8;
  late Vector2 worldSize;
  late MiniMap miniMap;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the map
    try {
      mapComponent = await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
      final mapWidth = mapComponent!.tileMap.map.width.toDouble();
      final mapHeight = mapComponent!.tileMap.map.height.toDouble();
      worldSize = Vector2(mapWidth * tileSize, mapHeight * tileSize);

      add(RectangleComponent(
        size: worldSize,
        paint: Paint()..color = const Color(0xFF808080),
      ));
      add(mapComponent!);

      baseLayer = mapComponent!.tileMap.getLayer<TileLayer>('Base');
      wallLayer = mapComponent!.tileMap.getLayer<TileLayer>('Wall');
      if (baseLayer == null || wallLayer == null) {
        print('Warning: Base or Wall layer not found');
        camera.viewport.add(
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
      print('Map loaded: ${mapWidth}x${mapHeight} tiles, worldSize: $worldSize');
    } catch (e) {
      print('Error loading map: $e');
      mapComponent = null;
      worldSize = Vector2(10000, 10000);
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

    // Set spawn point
    try {
      Vector2 spawnPosition = Vector2(spawnTileX.toDouble() + 0.5, spawnTileY.toDouble() + 0.5) * tileSize;
      player = Warrior(position: spawnPosition);
      add(player!);
      camera.follow(player!, maxSpeed: 400);
      print('Player spawned at: $spawnPosition');
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

    // Initialize UI
    try {
      joystick = JoystickComponent(
        knob: CircleComponent(radius: 20, paint: Paint()..color = Colors.white),
        background: CircleComponent(radius: 50, paint: Paint()..color = Colors.black38),
        anchor: Anchor.bottomLeft,
      );

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

      camera.viewport.addAll([joystick!, runBtn!, jumpBtn!, attackBtn!]);
    } catch (e) {
      print('Error initializing UI: $e');
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

    // Create full map image for mini-map
    if (mapComponent != null) {
      final fullMapImage = await createFullMapImage();
      const miniMapSize = 100.0; // Smaller size for compact circular minimap
      final scale = miniMapSize / worldSize.x;
      final miniMapHeight = worldSize.y * scale;
      miniMap = MiniMap(fullMapImage, Vector2(miniMapSize, miniMapHeight));
      miniMap.position = Vector2(10, 10);
      camera.viewport.add(miniMap);
    }

    setCameraBounds();
  }

  Future<ui.Image> createFullMapImage() async {
    final composition = ImageComposition();

    Tileset? findTilesetByGid(int gid) {
      for (var tileset in mapComponent!.tileMap.map.tilesets) {
        final tileCount = tileset.tileCount ?? 0;
        if (gid >= tileset.firstGid! && gid < tileset.firstGid! + tileCount) {
          return tileset;
        }
      }
      return null;
    }

    for (var layer in mapComponent!.tileMap.map.layers) {
      if (layer is TileLayer) {
        for (var row = 0; row < layer.height; row++) {
          for (var col = 0; col < layer.width; col++) {
            final tile = layer.tileData?[row][col];
            if (tile != null && tile.tile != 0) {
              final tileset = findTilesetByGid(tile.tile);
              if (tileset != null) {
                final localGid = tile.tile - tileset.firstGid!;
                final tilesetColumns = tileset.columns ?? 0;
                if (tilesetColumns > 0) {
                  final localRow = localGid ~/ tilesetColumns;
                  final localCol = localGid % tilesetColumns;
                  final srcX = localCol * (tileset.tileWidth ?? 0);
                  final srcY = localRow * (tileset.tileHeight ?? 0);
                  final srcRect = Rect.fromLTWH(
                    srcX.toDouble(),
                    srcY.toDouble(),
                    (tileset.tileWidth ?? 0).toDouble(),
                    (tileset.tileHeight ?? 0).toDouble(),
                  );
                  final destX = col * tileSize;
                  final destY = row * tileSize;
                  if (tileset.image != null && tileset.image!.source != null) {
                    final uiImage = await images.load(tileset.image!.source!);
                    composition.add(uiImage, Vector2(destX, destY), source: srcRect);
                  }
                }
              }
            }
          }
        }
      }
    }

    return composition.compose();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = desiredZoom;
    print('Visible world area: ${camera.viewport.size / desiredZoom} pixels');

    if (joystick != null) {
      joystick!.position = Vector2(40, size.y - joystick!.size.y / 2);
    }

    const double buttonRadius = 24;
    const double buttonDiameter = buttonRadius * 2;
    const double buttonMarginX = 12;
    const double buttonMarginY = 12;
    const double buttonSpaceX = 12;
    const double buttonSpaceY = 12;

    if (attackBtn != null) {
      attackBtn!.position = Vector2(size.x - buttonMarginX - buttonRadius, size.y - buttonMarginY - buttonRadius);
    }
    if (jumpBtn != null && attackBtn != null) {
      jumpBtn!.position = Vector2(
        attackBtn!.position.x - buttonDiameter - buttonSpaceX,
        size.y - buttonMarginY - buttonRadius,
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

    setCameraBounds();
  }

  void setCameraBounds() {
    if (mapComponent == null) {
      camera.setBounds(Rectangle.fromLTRB(0, 0, size.x, size.y));
      print('No map loaded, using screen bounds');
      return;
    }
    final vpSize = camera.viewport.size / camera.viewfinder.zoom;
    final minX = vpSize.x / 2;
    final minY = vpSize.y / 2;
    final maxX = worldSize.x - vpSize.x / 2;
    final maxY = worldSize.y - vpSize.y / 2;
    camera.setBounds(Rectangle.fromLTRB(minX, minY, maxX, maxY));
    print('Camera bounds set: minX=$minX, minY=$minY, maxX=$maxX, maxY=$maxY');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (player != null) {
      print('Player position: ${player!.position}, Camera position: ${camera.viewfinder.position}, Visible area: ${camera.viewfinder.visibleWorldRect}');
    }
  }

  bool isWalkable(int x, int y) {
    if (baseLayer == null || wallLayer == null) return false;
    if (x < 0 || x >= baseLayer!.width || y < 0 || y >= baseLayer!.height) return false;
    final baseTile = baseLayer!.tileData?[y][x];
    final wallTile = wallLayer!.tileData?[y][x];
    return (baseTile?.tile ?? 0) != 0 && (wallTile?.tile ?? 0) == 0;
  }

  List<Vector2> findPath(Vector2 start, Vector2 end) {
    final startTileX = (start.x / tileSize).floor();
    final startTileY = (start.y / tileSize).floor();
    final endTileX = (end.x / tileSize).floor();
    final endTileY = (end.y / tileSize).floor();

    final pathTiles = _aStar(startTileX, startTileY, endTileX, endTileY);

    if (pathTiles != null) {
      return pathTiles.map((tile) => Vector2((tile.x + 0.5) * tileSize, (tile.y + 0.5) * tileSize)).toList();
    }
    return [];
  }

  List<Vector2>? _aStar(int startX, int startY, int goalX, int goalY) {
    final openSet = <TileNode>[];
    final closedSet = <TileNode>[];
    final startNode = TileNode(startX, startY, null, 0, heuristic(startX, startY, goalX, goalY) as double);
    openSet.add(startNode);

    while (openSet.isNotEmpty) {
      openSet.sort((a, b) => a.f.compareTo(b.f));
      final current = openSet.removeAt(0);

      if (current.x == goalX && current.y == goalY) {
        final path = <TileNode>[];
        TileNode? node = current;
        while (node != null) {
          path.add(node);
          node = node.parent;
        }
        return path.reversed.map((n) => Vector2(n.x.toDouble(), n.y.toDouble())).toList();
      }

      closedSet.add(current);

      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          if (dx == 0 && dy == 0) continue;
          if (dx != 0 && dy != 0) continue; // Restrict to cardinal directions
          final nx = current.x + dx;
          final ny = current.y + dy;

          if (nx < 0 || nx >= mapComponent!.tileMap.map.width || ny < 0 || ny >= mapComponent!.tileMap.map.height) continue;
          if (!isWalkable(nx, ny)) continue;
          if (closedSet.any((n) => n.x == nx && n.y == ny)) continue;

          final gNew = current.g + 1;
          var neighbor = openSet.firstWhere(
                (n) => n.x == nx && n.y == ny,
            orElse: () => TileNode(nx, ny, null, double.infinity, 0),
          );

          if (gNew < neighbor.g) {
            neighbor = TileNode(nx, ny, current, gNew, heuristic(nx, ny, goalX, goalY) as double);
            if (!openSet.contains(neighbor)) {
              openSet.add(neighbor);
            }
          }
        }
      }
    }
    return null;
  }

  int heuristic(int x1, int y1, int x2, int y2) {
    return (x2 - x1).abs() + (y2 - y1).abs(); // Manhattan distance
  }
}

class TileNode {
  final int x, y;
  final TileNode? parent;
  final double g, h;
  TileNode(this.x, this.y, this.parent, this.g, this.h);
  double get f => g + h;
}

class MiniMap extends PositionComponent with HasGameRef<MyGame>, TapCallbacks {
  late SpriteComponent mapSprite;
  late CircleComponent dot;
  late Vector2 miniMapSize;
  List<Vector2> pathPoints = [];
  final Paint backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);

  MiniMap(ui.Image fullMapImage, Vector2 miniMapSize) : super(size: miniMapSize) {
    this.miniMapSize = miniMapSize;
    mapSprite = SpriteComponent.fromImage(fullMapImage, size: miniMapSize);
    add(mapSprite);

    dot = CircleComponent(radius: 3, paint: Paint()..color = Colors.red);
    add(dot);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.player != null) {
      final scaleX = miniMapSize.x / gameRef.worldSize.x;
      final scaleY = miniMapSize.y / gameRef.worldSize.y;
      dot.position.setValues(
        gameRef.player!.position.x * scaleX,
        gameRef.player!.position.y * scaleY,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw semi-transparent circular background
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      backgroundPaint,
    );

    // Clip to circular shape
    final path = Path()..addOval(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.clipPath(path);

    // Render map and components
    super.render(canvas);

    // Draw path if available
    if (pathPoints.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.purple
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < pathPoints.length - 1; i++) {
        canvas.drawLine(
          Offset(pathPoints[i].x, pathPoints[i].y),
          Offset(pathPoints[i + 1].x, pathPoints[i + 1].y),
          paint,
        );
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final localPos = event.localPosition;
    final mapScale = miniMapSize.x / gameRef.worldSize.x;
    final worldPos = Vector2(localPos.x / mapScale, localPos.y / mapScale);
    final path = gameRef.findPath(gameRef.player!.position, worldPos);
    if (path.isNotEmpty) {
      pathPoints = path.map((wp) => Vector2(wp.x * mapScale, wp.y * mapScale)).toList();
    } else {
      pathPoints = [];
    }
  }
}

class RoundImageButtonComponent extends CircleComponent with TapCallbacks {
  final void Function(bool) onPressed;
  final bool isHold;

  RoundImageButtonComponent({
    required this.onPressed,
    required this.isHold,
    required ui.Image image,
    required Anchor anchor,
  }) : super(
    radius: 24,
    paint: Paint()..color = Colors.black54,
    anchor: anchor,
  ) {
    final imageSprite = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2(40, 40),
      anchor: Anchor.center,
      position: Vector2(24, 24),
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
  final double tileSize = 32;
  Vector2? _preAttackPosition;
  bool isFacingLeft = false;
  bool _isFlipped = false;
  bool isJumping = false;
  double? originalY;
  double jumpProgress = 0;
  double jumpTotalTime = 0.6;
  double jumpHeight = 50;

  Warrior({Vector2? position})
      : super(
    position: position ?? Vector2.zero(),
    size: Vector2(150, 70),
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

      print('Idle image size: ${idleImg.width}x${idleImg.height}');
      print('Run image size: ${runImg.width}x${runImg.height}');
      print('Jump image size: ${jumpImg.width}x${jumpImg.height}');
      print('Attack-1 image size: ${atk1Img.width}x${atk1Img.height}');
      print('Attack-2 image size: ${atk2Img.width}x${atk2Img.height}');

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
      WarriorState.idle: idleAnimation!,
      WarriorState.walk: runAnimation!,
      WarriorState.run: runAnimation!,
      WarriorState.jump: jumpAnimation!,
      WarriorState.attack1: attack1Animation!,
      WarriorState.attack2: attack2Animation!,
    };
    current = WarriorState.idle;

    add(RectangleHitbox());
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
      _preAttackPosition = position.clone();
      _attackPhase = 1;
      current = WarriorState.attack1;
      print('Switching to attack1 state at position: $position');
      Future.delayed(const Duration(milliseconds: 560), () {
        if (_attackPhase == 1) {
          _attackPhase = 2;
          current = WarriorState.attack2;
          position = _preAttackPosition!;
          print('Switching to attack2 state at position: $position');
          Future.delayed(const Duration(milliseconds: 560), () {
            _attackPhase = 0;
            current = WarriorState.idle;
            position = _preAttackPosition!;
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

    if (isJumping && originalY != null) {
      jumpProgress += dt;
      if (jumpProgress < jumpTotalTime) {
        double u = pi * jumpProgress / jumpTotalTime;
        double fraction = sin(u);
        position.y = originalY! - jumpHeight * (fraction * fraction);
      } else {
        position.y = originalY!;
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
        if (dir.x.abs() > dir.y.abs()) {
          dir = Vector2(dir.x.sign, 0);
        } else {
          dir = Vector2(0, dir.y.sign);
        }

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
            print('Tile ($nextX, $nextY) isWalkable: $isWalkable, Base gid: ${baseTile.tile}, Wall gid: ${wallTile.tile}');
          } else {
            print('Tile ($nextX, $nextY) out of bounds');
          }
        } else {
          print('Base or Wall layer not available, using fallback movement');
          isWalkable = true;
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

    if (current != WarriorState.attack1 && current != WarriorState.attack2 && !isJumping) {
      if (_moveTarget != null) {
        current = gameRef.isRunButtonPressed ? WarriorState.run : WarriorState.walk;
      } else {
        current = WarriorState.idle;
      }
    }

    if (isFacingLeft && !_isFlipped) {
      flipHorizontally();
      _isFlipped = true;
    } else if (!isFacingLeft && _isFlipped) {
      flipHorizontally();
      _isFlipped = false;
    }
  }
}