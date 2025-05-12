
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flame/components.dart';

class DungeonGame extends FlameGame {
  late final TiledComponent map;

  @override
  Future onLoad() async {
    await super.onLoad();
// Load the TMX map from assets/Map
    map = await TiledComponent.load('Map/1st base.tmx', Vector2.all(32));
    add(map);
  }
}

class GamePage extends StatelessWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
// Keep landscape orientation for this page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return Scaffold(
      body: GameWidget(
        game: DungeonGame(),
      ),
    );
  }
}