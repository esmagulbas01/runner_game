import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/parallax.dart';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    GameWidget<RunnerGame>.controlled(
      gameFactory: RunnerGame.new,
      overlayBuilderMap: {
        'gameOver': (context, game) => GameOverEkrani(game: game),
      },
    ),
  );
}

class RunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  late Player player;
  double oyunHizi = 200;
  double skor = 0;
  final Random rastgele = Random();
  double mantarSayaci = 0;
  double sonrakiMantarSuresi = 2;
  late TextComponent skorYazisi;
  int rekor = 0; // ilk mantar 2 saniye sonra

  @override
  Future<void> onLoad() async {
    final kayit = await SharedPreferences.getInstance();
    rekor = kayit.getInt('rekor') ?? 0;
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
    skorYazisi = TextComponent(
      text: 'Skor: 0',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(skorYazisi);
  }

  @override
  void update(double dt) {
    super.update(dt);
    oyunHizi += 5 * dt;
    skor += 10 * dt;
    skorYazisi.text = 'Skor: ${skor.toInt()}'; // saniyede 10 puan

    // mantar spawn zamanlayıcısı
    mantarSayaci += dt;
    if (mantarSayaci >= sonrakiMantarSuresi) {
      add(Mantar());
      mantarSayaci = 0;
      sonrakiMantarSuresi = 1.2 + rastgele.nextDouble() * 1.8;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    player.zipla();
  }

  Future<void> rekorKaydet() async {
    if (skor.toInt() > rekor) {
      rekor = skor.toInt();
      final kayit = await SharedPreferences.getInstance();
      await kayit.setInt('rekor', rekor);
    }
  }

  void yenidenBaslat() {
    skor = 0;
    oyunHizi = 200;
    mantarSayaci = 0;
    children.whereType<Mantar>().forEach((m) => m.removeFromParent());
    resumeEngine();
  }
}

class Player extends SpriteAnimationComponent
    with HasGameReference<RunnerGame>, CollisionCallbacks {
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
    add(RectangleHitbox());
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

  @override
  void onCollisionStart(Set<Vector2> noktalar, PositionComponent diger) {
    super.onCollisionStart(noktalar, diger);
    if (diger is Mantar) {
      game.rekorKaydet();
      game.pauseEngine();
      game.overlays.add('gameOver');
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
    kaydirma += game.oyunHizi * dt; // dünya hızıyla kay
    kaydirma %= karoGenisligi; // bir karo boyunu geçince sıfırla
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

class Mantar extends SpriteComponent with HasGameReference<RunnerGame> {
  Mantar() : super(size: Vector2(50, 50), anchor: Anchor.bottomLeft);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('tinyShroom_red.png');
    position = Vector2(game.size.x + 60, game.size.y - 80);
    add(RectangleHitbox()); // ← YENİ: çarpışma alanı
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= game.oyunHizi * dt; // dünya hızıyla sola ak

    if (position.x < -60) {
      // ekranın solundan tamamen çıktıysa
      removeFromParent(); // kendini oyundan sil
    }
  }
}

class GameOverEkrani extends StatelessWidget {
  final RunnerGame game;
  const GameOverEkrani({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'OYUN BİTTİ',
              style: TextStyle(
                fontSize: 36,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Skor: ${game.skor.toInt()}',
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
            Text(
              'Rekor: ${game.rekor}',
              style: const TextStyle(fontSize: 24, color: Colors.amber),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('gameOver');
                game.yenidenBaslat();
              },
              child: const Text('Tekrar Oyna', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
