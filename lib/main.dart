import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/parallax.dart';

void main() {
  runApp(GameWidget(game: RunnerGame()));
}

class RunnerGame extends FlameGame with TapCallbacks {
  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  late Player player;
  double oyunHizi = 200;

  @override
  Future<void> onLoad() async {
    final arkaplan = await loadParallaxComponent(
      [ParallaxImageData('bg_grasslands.png')],
      baseVelocity: Vector2(60, 0), // saniyede 60 piksel sola akış
      velocityMultiplierDelta: Vector2(1.6, 0),
      fill: LayerFill.height,
    );
    add(arkaplan);

    add(Ground(size));
    player = Player();
    add(player);
  }
  
  @override
  void update(double dt) {      // ← 2. YENİ: onLoad'un altına bu blok
    super.update(dt);
    oyunHizi += 5 * dt;
  }

  @override
  void onTapDown(TapDownEvent event) {
    player.zipla();
  }
}

class Player extends SpriteAnimationComponent
    with HasGameReference<RunnerGame> {
  Player() : super(position: Vector2(100, 300), size: Vector2(70, 90));

  double dikeyHiz = 0; // piksel/saniye
  final double yercekimi = 1200; // piksel/saniye²
  @override
  Future<void> onLoad() async {
    final kareler = await Future.wait([
      game.loadSprite('character_femaleAdventurer_run0.png'),
      game.loadSprite('character_femaleAdventurer_run1.png'),
      game.loadSprite('character_femaleAdventurer_run2.png'),
    ]);
    animation = SpriteAnimation.spriteList(kareler, stepTime: 0.1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    dikeyHiz += yercekimi * dt;
    position.y += dikeyHiz * dt;

    final zeminSeviyesi = game.size.y - 80 - size.y;
    if (position.y >= zeminSeviyesi) {
      position.y = zeminSeviyesi;
      dikeyHiz = 0;
    }
  }

  void zipla() {
    final zeminSeviyesi = game.size.y - 80 - size.y;
    if (position.y >= zeminSeviyesi) {
      dikeyHiz = -600;
    }
  }
}


class Ground extends PositionComponent with HasGameReference<RunnerGame> {
  Ground(Vector2 gameSize)
      : super(
          position: Vector2(0, gameSize.y - 80),
          size: Vector2(gameSize.x, 80),
        );

  late Sprite karo;
  double kaydirma = 0;
  final double karoGenisligi = 80;

  @override
  Future<void> onLoad() async {
    karo = await game.loadSprite('shroomBrownAltSpotsMid.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    kaydirma += game.oyunHizi * dt;      // dünya hızıyla kay
    kaydirma %= karoGenisligi;            // bir karo boyunu geçince sıfırla
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // ekranı karolarla döşe, kaydirma kadar sola kaymış şekilde
    for (double x = -kaydirma; x < size.x; x += karoGenisligi) {
      karo.render(
        canvas,
        position: Vector2(x, 0),
        size: Vector2(karoGenisligi, size.y),
      );
    }
  }
}