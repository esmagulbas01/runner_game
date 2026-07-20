import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/parallax.dart';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';

void main() {
  runApp(
    GameWidget<RunnerGame>.controlled(
      gameFactory: RunnerGame.new,
      overlayBuilderMap: {
        'gameOver': (context, game) => GameOverEkrani(game: game),
        'baslat': (context, game) => BaslatEkrani(game: game),
      },
      initialActiveOverlays: const ['baslat'],
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
  double coinSayaci = 0;
  double sonrakiCoinSuresi = 3;

  @override
  Future<void> onLoad() async {
    final kayit = await SharedPreferences.getInstance();
    rekor = kayit.getInt('rekor') ?? 0;
    await FlameAudio.audioCache.loadAll(['jump.wav', 'hit.wav', 'coin.wav']);
    add(ArkaPlan());
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
    pauseEngine(); // başlat ekranı gelene kadar oyun donuk beklesin
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
    // coin spawn zamanlayıcısı
    coinSayaci += dt;
    if (coinSayaci >= sonrakiCoinSuresi) {
      add(Coin());
      coinSayaci = 0;
      sonrakiCoinSuresi = 2.5 + rastgele.nextDouble() * 2.5; // 2.5-5 sn arası
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
  final double yercekimi = 1400; // piksel/saniye²
  @override
  Future<void> onLoad() async {
    final kareler = await Future.wait([
      game.loadSprite('character_femaleAdventurer_run0.png'),
      game.loadSprite('character_femaleAdventurer_run1.png'),
      game.loadSprite('character_femaleAdventurer_run2.png'),
    ]);
    animation = SpriteAnimation.spriteList(kareler, stepTime: 0.1);
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.5, size.y * 0.7),
        position: Vector2(size.x * 0.25, size.y * 0.2),
      ),
    );
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
      dikeyHiz = -650;
      FlameAudio.play('jump.wav');
    }
  }

  @override
  void onCollisionStart(Set<Vector2> noktalar, PositionComponent diger) {
    super.onCollisionStart(noktalar, diger);

    if (diger is Mantar) {
      FlameAudio.play('hit.wav');
      game.rekorKaydet();
      game.pauseEngine();
      game.overlays.add('gameOver');
    }

    if (diger is Coin) {
      FlameAudio.play('coin.wav'); // çıngır sesi
      game.skor += 50; // bonus puan
      diger.removeFromParent(); // coin'i sahneden sil
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
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.6, size.y * 0.6),
        position: Vector2(size.x * 0.2, size.y * 0.4),
      ),
    ); // ← YENİ: çarpışma alanı
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

class Coin extends SpriteComponent with HasGameReference<RunnerGame> {
  Coin() : super(size: Vector2(40, 40), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('coin.png');
    position = Vector2(
      game.size.x + 60, // sağ dışında doğ
      game.size.y - 260, // havada (zıplayınca ulaşılır yükseklik)
    );
    add(RectangleHitbox()); // toplanabilmesi için hitbox
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= game.oyunHizi * dt; // dünya hızıyla sola ak
    if (position.x < -60) {
      removeFromParent(); // ekrandan çıkınca sil
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

class BaslatEkrani extends StatelessWidget {
  final RunnerGame game;
  const BaslatEkrani({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // tam ekran poster
        Image.asset('assets/images/baslat_arkaplan.png', fit: BoxFit.cover),
        // altta rekor + buton
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Rekor: ${game.rekor}',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 16,
                ),
              ),
              onPressed: () {
                game.overlays.remove('baslat');
                game.resumeEngine();
              },
              child: const Text(
                'BAŞLAT',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ],
    );
  }
}

class ArkaPlan extends Component with HasGameReference<RunnerGame> {
  late Sprite gorsel;
  double kaydirma = 0;
  bool hazir = false;

  @override
  Future<void> onLoad() async {
    gorsel = await game.loadSprite('arkaplan.png');
    hazir = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!hazir) return;
    kaydirma += game.oyunHizi * 0.4 * dt; // arka plan yavaş aksın
    kaydirma %= game.size.x;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!hazir) return;
    // ekranı iki kopyayla döşe (biri çıkarken diğeri girer)
    for (double x = -kaydirma; x < game.size.x; x += game.size.x) {
      gorsel.render(
        canvas,
        position: Vector2(x, 0),
        size: Vector2(game.size.x, game.size.y),
      );
    }
  }
}


