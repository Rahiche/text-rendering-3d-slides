import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'models.dart';
import 'shapes.dart' show roundedSlab;
import 'shot.dart';
import 'vignette.dart';

/// 豆腐屋 · Font fallback, in the park past the alley (on the left of the
/// long path): four fonts' kiosks in a row — Space Grotesk, Noto Kufi
/// Arabic, Noto Sans JP, Noto Color Emoji — each with its cmap on the shelf
/// behind the counter, and at the end of the row the tofu shop.
///
/// Dash brings the code points, a tile each on the placard it holds up,
/// along the row, and asks each font in turn about all it still has: a
/// yes for one (✓, green: its glyph lit on the shelf, its tile handed over
/// onto the counter), no for the rest (✕, red). A is found at the first
/// kiosk, ب at the second (its second try), 字 at the third, 😀 at the
/// fourth. U+0378 is left, a no from every one: at the tofu shop the press
/// stamps out a tofu, □, the code point's hex on its face (.notdef, the box
/// a font draws for a character it hasn't got), and it goes up on Dash's
/// placard in the code point's place. Then, a joke, the shop serves Dash
/// tofu, the dish: cold tofu up out of the tank, over onto the counter. A
/// press a step (talk_sections.dart's beats, each with its line of the
/// narration, 01 fallback…): Dash waiting in front of the row; then on to
/// a kiosk a press; then U+0378 to the tofu shop.
class TofuShop extends Vignette {
  TofuShop(super.kit);

  @override
  String get name => 'tofu';
  @override
  String get kick => 'FONT FALLBACK';
  @override
  String get line => 'U+0378: no font has it';
  @override
  String get note => 'each font is asked in turn; then .notdef, the tofu □';

  @override
  double get loop => 50;
  @override
  double get visit => 34;

  @override
  final frame = trs(vm.Vector3(-6.6, 0, 48.5), rotY: -math.pi / 2);

  // ── The row ───────────────────────────────────────────────────────────────

  /// The kiosks' middles (x), the tofu shop's; the counters' fronts (z),
  /// the shelves.
  static const _kx = [-4.2, -2.1, 0.0, 2.1], _shopX = 4.6;
  static const _counterZ = -0.35, _shelfZ = 0.9;

  static const _fonts = [
    ('Space Grotesk', 'Aa', 0xF2B13A),
    ('Noto Kufi Arabic', 'خط', 0x3FA37A),
    ('Noto Sans JP', 'あ字', 0xE8505F),
    ('Noto Color Emoji', '😀', 0x6C8EE0),
  ];

  /// What each cmap shelf shows (its glyphs, in a grid of 6 × 4).
  static const _shelves = [
    'ABCDEFGHIJKLMNOPQRSTUVWX',
    'ابتثجحخدذرزسشصضطظعغفقكلم',
    'あいうえおかきくけこさし文字日本語漢東京花山川',
    '😀😃😄😁😆😅🙂😉😊😇🥰😍🤩😘😋😛😜🤪😎🤓🧐🤔🤗🤭',
  ];

  // ── Dash ──────────────────────────────────────────────────────────────────

  /// What Dash brings, a tile each on its placard: the code point, the font
  /// that has it (4: none, the tofu shop) and its glyph's place on that
  /// shelf. In the narration's order: "A Latin A is found … on the very
  /// first try. An Arabic letter takes two lookups. A Chinese character
  /// takes three, and an emoji, four. But this code point, U+0378 … No
  /// font has it."
  static const _tray = [('A', 0, 0), ('ب', 1, 1), ('字', 2, 13), ('😀', 3, 0), ('U+0378', 4, 0)];

  /// The presses: Dash on to the first kiosk; to the second, the third,
  /// the fourth; U+0378 held up and off to the tofu shop. (Before the
  /// first, it waits, while the narration says what fallback is.)
  static const _steps = [20.4, 25.6, 29.4, 33.2, 37.0];

  /// When each kiosk answers.
  static const _answers = [24.15, 27.95, 31.75, 35.55];

  /// "Fonts are asked in order": the kiosks' lamps in turn; "first the
  /// app's own fonts, then the platform's".
  static const _inOrder = 0.6, _appsOwn = 4.3, _platform = 6.3, _listEnd = 8.6;

  /// Dash's size (1: 0.75 m to its tuft); where it walks the row, and
  /// stands to ask (the counters' side of the lane); where it waits, out
  /// in front of the row's middle (in the picture, right of the card).
  static const _size = 1.5, _walkZ = -1.55, _waitX = -0.9, _waitZ = -3.1;

  /// Its way along the row, a stretch at a time: from when to when, from x
  /// to x, and what it's doing (0 walking on, 1 asking at a counter, 2
  /// holding up what's left, to the camera). Waiting out in front; over to
  /// the first kiosk; a stop at each (in a little before its answer, and
  /// there till the next press); U+0378 held up; on to the tofu shop's
  /// counter.
  static final _way = <(double, double, double, double, int)>[
    (0, _steps[0] + 0.1, _waitX, _waitX, 2),
    (_steps[0] + 0.1, _answers[0] - 0.45, _waitX, _kx[0], 0),
    for (var k = 0; k < 4; k++) ...[
      (_answers[k] - 0.45, _steps[k + 1] + 0.1, _kx[k], _kx[k], 1),
      if (k < 3) (_steps[k + 1] + 0.1, _answers[k + 1] - 0.45, _kx[k], _kx[k + 1], 0),
    ],
    (_steps[4] + 0.1, _toShop, _kx[3], _kx[3], 2),
    (_toShop, _toShop + 1.8, _kx[3], _shopX - 0.3, 0),
    (_toShop + 1.8, 1e9, _shopX - 0.3, _shopX - 0.3, 1),
  ];

  /// When Dash sets off for the tofu shop (U+0378 held up till then).
  static const _toShop = 40.6;

  /// Where Dash is at [u] (x, z), which way it faces (yaw: 0 the camera,
  /// −π/2 along the row, −π the counter; over to the first kiosk, towards
  /// it), and how much it's walking (0..1).
  static (double, double, double, double) _dashAt(double u) {
    const along = -math.pi / 2, counter = -math.pi, camera = 0.0;
    // (Over from where it waited to the first kiosk: facing that way.)
    final over = math.atan2(-(_kx[0] - _waitX), -(_walkZ - _waitZ));
    double faceOf(int i) {
      final what = _way[i].$5;
      if (i == 1) return over;
      return what == 0 ? along : (what == 1 ? counter : camera);
    }

    var i = 0;
    while (i + 1 < _way.length && u >= _way[i + 1].$1) {
      i++;
    }
    final (a, e, x0, x1, what) = _way[i];
    final f = seg(u, a, e);
    final x = what == 0 ? lerp(x0, x1, f * f * (3 - 2 * f)) : x0;
    final w = seg(u, _way[1].$1, _way[1].$2);
    final z = lerp(_waitZ, _walkZ, w * w * (3 - 2 * w));
    // (Turned from the way it faced the shorter way round.)
    final before = i == 0 ? faceOf(0) : faceOf(i - 1), to = faceOf(i);
    final yaw = before + _wrap(to - before) * eio(seg(u, a, a + 0.35));
    final walking = what == 0 ? smooth(0, 0.15, f) * (1 - smooth(0.85, 1, f)) : 0.0;
    return (x, z, yaw, walking);
  }

  static double _wrap(double a) => a - 2 * math.pi * ((a + math.pi) / (2 * math.pi)).floorToDouble();

  /// When the tofu's stamped out, goes over onto the placard, is up there.
  static const _stamp = 43.6, _over = _stamp + 0.5, _onCard = _over + 0.6;

  // ── Building ──────────────────────────────────────────────────────────────

  late final _Dash _dash;
  late final Node _placard;
  final _tiles = <Node>[];
  late final Node _tofuFace, _ram, _dish, _block;
  bool _ready = false;

  @override
  List<(String, TextStyle)> get fontRuns => [
    for (final (n, s, _) in _fonts) ('$n $s', const TextStyle(fontFamily: BP.display)),
    for (final s in _shelves) (s, const TextStyle(fontFamily: BP.display)),
    ('TOFU SHOP .notdef U+0041 U+0628 U+5B57 U+1F600 U+0378 A ب 字', const TextStyle(fontFamily: BP.display, fontFamilyFallback: [BP.arabic])),
    ('😀', const TextStyle()),
  ];

  @override
  Future<void> init() async {
    makePool(boxes: 40, glows: 40);
    final b = Batch();
    final timber = pbr(rgb(1, 1, 1), roughness: 0.8);
    final steel = pbr(rgb(1, 1, 1), roughness: 0.4, metallic: 0.7);
    final dark = Vignette.c(0x26282E), wood = Vignette.c(0xB98A5A), post = Vignette.c(0x4A3426), white = Vignette.c(0xF2EFE8);
    for (var k = 0; k < 4; k++) {
      final x = _kx[k], col = Vignette.c(_fonts[k].$3);
      // The counter (its top, a band of the font's colour), the posts, the
      // shelf's frame, the awning sloping down to the front.
      box(b, timber, 1.7, 0.95, 0.6, x, 0.475, _counterZ + 0.3, dark);
      box(b, timber, 1.82, 0.05, 0.74, x, 0.975, _counterZ + 0.3, wood);
      box(b, timber, 1.72, 0.2, 0.02, x, 0.74, _counterZ - 0.01, col);
      for (final dx in [-0.86, 0.86]) {
        box(b, timber, 0.08, 2.55, 0.08, x + dx, 1.275, _counterZ + 0.05, post);
        box(b, timber, 0.08, 2.55, 0.08, x + dx, 1.275, _shelfZ + 0.12, post);
      }
      box(b, timber, 1.66, 1.5, 0.05, x, 1.55, _shelfZ + 0.12, dark);
      for (var r = 0; r < 4; r++) {
        box(b, timber, 1.6, 0.03, 0.2, x, 0.88 + 0.36 * r, _shelfZ, wood);
      }
      for (var s = 0; s < 4; s++) {
        box(b, timber, 0.46, 0.06, 1.6, x - 0.69 + 0.46 * s, 2.62, 0.4, s.isEven ? col : white, rotX: -0.16);
      }
    }
    // The tofu shop: wider, a noren over its front, a tank of water on the
    // counter with tofu in it, and the press that stamps them out.
    box(b, timber, 2.3, 0.95, 0.7, _shopX, 0.475, _counterZ + 0.35, Vignette.c(0x3A3F48));
    box(b, timber, 2.42, 0.05, 0.84, _shopX, 0.975, _counterZ + 0.35, wood);
    for (final dx in [-1.15, 1.15]) {
      box(b, timber, 0.1, 2.9, 0.1, _shopX + dx, 1.45, _counterZ + 0.02, post);
      box(b, timber, 0.1, 2.9, 0.1, _shopX + dx, 1.45, _shelfZ + 0.3, post);
    }
    box(b, timber, 2.3, 1.9, 0.05, _shopX, 1.85, _shelfZ + 0.32, Vignette.c(0xE9E2D2));
    box(b, timber, 2.5, 0.1, 1.5, _shopX, 2.92, 0.45, Vignette.c(0x2B2F3A));
    box(b, timber, 0.96, 0.16, 0.4, _shopX + 0.5, 1.08, _tankZ, Vignette.c(0x6E7F8C));
    box(b, timber, 0.88, 0.02, 0.32, _shopX + 0.5, 1.155, _tankZ, Vignette.c(0x3F6F8A));
    for (var i = 0; i < 6; i++) {
      box(b, timber, 0.17, 0.05, 0.12, _shopX + 0.5 + 0.27 * (i % 3 - 1), 1.145, _tankZ + (i < 3 ? -0.075 : 0.075), Vignette.c(0xF1ECDF));
    }
    for (final dx in [-0.2, 0.2]) {
      box(b, steel, 0.05, 0.62, 0.05, _shopX - 0.3 + dx, 1.31, _counterZ + 0.2, Vignette.c(0x5A6470));
    }
    box(b, steel, 0.5, 0.07, 0.12, _shopX - 0.3, 1.64, _counterZ + 0.2, Vignette.c(0x5A6470));
    b.buildInto(detail, 'tofu row', castsShadows: false, lightChannelMask: 0x01);
    // The press's ram (its middle at its origin).
    _ram = Node(name: 'tofu press', mesh: Mesh(CuboidGeometry(vm.Vector3(0.26, 0.12, 0.26)), pbr(Vignette.c(0x8A939E), metallic: 0.8, roughness: 0.35)))
      ..castsShadows = false;
    detail.add(_ram);
    _buildDish();

    await _signs();
    // Dash, its placard (navy, held up on a pole), and a tile on it for
    // each code point.
    _dash = await _Dash.build(this);
    _placard = Node(name: 'tofu placard', mesh: Mesh(boardGeometry(_cardW, _cardH, thick: 0.02), pbr(Vignette.c(0x1E2A4A), roughness: 0.6)))..castsShadows = false;
    detail.add(_placard);
    for (final (s, f, _) in _tray) {
      _tiles.add(await _tile(s, emoji: f == 3, code: f == 4));
    }
    _ready = true;
  }

  /// The placard: its size, how high over the ground its middle is; a
  /// tile's size and the gap between two.
  static const _cardW = 1.05, _cardH = 0.3, _cardY = 1.62, _tileS = 0.17, _tileGap = 0.2;

  /// Tile [i]'s place on the placard (across its middle).
  static double _tileX(int i) => (i - 2) * _tileGap;

  /// The tank's middle (z): back on the counter, the dish's room in front.
  static const _tankZ = _counterZ + 0.56;

  /// The dish the shop serves once the tofu's up on the placard (tofu, the
  /// food the box is named after): cold tofu on an indigo plate in a little
  /// soy sauce, spring onion, ginger and bonito flakes on top, chopsticks
  /// on their rest beside it. Twice life size, to be seen. Its middle on
  /// the counter at its origin; the block's foot at [_block]'s (it wobbles
  /// as it lands).
  void _buildDish() {
    final glaze = pbr(rgb(1, 1, 1), roughness: 0.14), soft = pbr(rgb(1, 1, 1), roughness: 0.5);
    final plate = Batch(), food = Batch();
    plate
      ..add(glaze, part(CylinderGeometry(bottomRadius: 0.15, topRadius: 0.18, height: 0.022, radialSegments: 48), trs(vm.Vector3(0, 0.011, 0)), Vignette.c(0x27406C)))
      ..add(glaze, part(CylinderGeometry(bottomRadius: 0.13, topRadius: 0.13, height: 0.003, radialSegments: 40), trs(vm.Vector3(0, 0.0235, 0)), Vignette.c(0x2A1408)))
      // (The chopsticks' tips up on the rest, their ends towards Dash.)
      ..add(glaze, part(CuboidGeometry(vm.Vector3(0.05, 0.016, 0.022)), trs(vm.Vector3(0.27, 0.008, 0.12)), Vignette.c(0xE8E3D8)));
    for (final dx in [-0.012, 0.012]) {
      plate.add(glaze, part(CylinderGeometry(bottomRadius: 0.0065, topRadius: 0.0035, height: 0.34, radialSegments: 8), trs(vm.Vector3(0.27 + dx, 0.012, -0.02), rotX: math.pi / 2 - 0.03), Vignette.c(0x5C1E18)));
    }
    food.add(soft, painted(roundedSlab(0.2, 0.12, 0.2, corner: 0.014, edge: 0.012).transformed(trs(vm.Vector3(0, 0.06, 0))), Vignette.c(0xF3EEE1)));
    food.add(soft, part(SphereGeometry(radius: 0.032, segments: 16, rings: 8), trs(vm.Vector3(0.015, 0.128, 0.01), s: vm.Vector3(1, 0.42, 1)), Vignette.c(0xE5B65C)));
    final r = math.Random(7);
    for (var i = 0; i < 11; i++) {
      final a = r.nextDouble() * 2 * math.pi, d = 0.035 + 0.04 * r.nextDouble();
      food.add(
        soft,
        part(
          CylinderGeometry(bottomRadius: 0.011, topRadius: 0.011, height: 0.006, radialSegments: 10),
          trs(vm.Vector3(math.cos(a) * d, 0.123 + 0.006 * r.nextDouble(), math.sin(a) * d), rotX: 0.3 * (r.nextDouble() - 0.5), rotZ: 0.3 * (r.nextDouble() - 0.5)),
          Vignette.c(i.isEven ? 0x5E9E35 : 0x8CC152),
        ),
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = r.nextDouble() * 2 * math.pi, d = 0.02 * r.nextDouble();
      food.add(
        soft,
        part(
          CuboidGeometry(vm.Vector3(0.042, 0.003, 0.024)),
          trs(vm.Vector3(0.015 + math.cos(a) * d, 0.14 + 0.012 * r.nextDouble(), 0.01 + math.sin(a) * d), rotY: r.nextDouble() * math.pi, rotX: 0.6 * (r.nextDouble() - 0.5), rotZ: 0.6 * (r.nextDouble() - 0.5)),
          Vignette.c(i.isEven ? 0xC98E63 : 0xB27450),
        ),
      );
    }
    _dish = Node(name: 'tofu dish')..visible = false;
    _block = Node(name: 'tofu dish block');
    plate.buildInto(_dish, 'tofu dish plate', lightChannelMask: 0x01);
    food.buildInto(_block, 'tofu dish food', lightChannelMask: 0x01);
    detail.add(_dish..add(_block));
  }

  /// A tile with [s] on it (an emoji in its colours; a code point small).
  Future<Node> _tile(String s, {bool emoji = false, bool code = false}) async {
    final tex = await paintedTexture(256, 256, (c, sz) {
      c.drawRRect(RRect.fromRectAndRadius(Offset.zero & sz, const Radius.circular(36)), Paint()..color = const Color(0xFFF6F3EC));
      if (code) {
        Vignette.text(c, s, (Offset.zero & sz).deflate(18), sz.height * 0.22, const Color(0xFF14203A), family: BP.mono, weight: FontWeight.w700);
        return;
      }
      final tp = TextPainter(
        text: TextSpan(text: s, style: emoji ? const TextStyle(fontSize: 170) : TextStyle(fontFamily: BP.display, fontFamilyFallback: const [BP.arabic], fontSize: 170, fontWeight: FontWeight.w700, color: const Color(0xFF14203A), locale: s == '字' ? const Locale('ja') : null)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((sz.width - tp.width) / 2, (sz.height - tp.height) / 2));
      tp.dispose();
    });
    final n = Node(
      name: 'tofu tile',
      mesh: Mesh(
        boardGeometry(_tileS, _tileS, thick: 0.02),
        PhysicallyBasedMaterial()
          ..baseColorTexture = tex
          ..roughnessFactor = 0.5
          ..emissiveTexture = tex
          ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
          ..emissiveStrength = 0.35,
      ),
    )
      ..castsShadows = false
      ..visible = false;
    detail.add(n);
    return n;
  }

  Future<void> _signs() async {
    final ink = const Color(0xFF14203A);
    await Future.wait([
      for (var k = 0; k < 4; k++) ...[
        // The font's name over its kiosk, and its cmap on the shelf.
        sign(1.74, 0.46, vm.Matrix4.translation(vm.Vector3(_kx[k], 2.98, _counterZ - 0.02)), (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = Color(0xFF000000 | _fonts[k].$3));
          Vignette.text(c, _fonts[k].$1, Rect.fromLTWH(0, s.height * 0.08, s.width * 0.7, s.height * 0.84), s.height * 0.34, ink);
          Vignette.text(c, _fonts[k].$2, Rect.fromLTWH(s.width * 0.7, 0, s.width * 0.28, s.height), s.height * 0.6, ink, lang: k == 2 ? 'ja' : null);
        }),
        sign(
          1.54,
          1.38,
          vm.Matrix4.translation(vm.Vector3(_kx[k], 1.55, _shelfZ + 0.08)),
          (c, s) {
            c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF20232B));
            final g = _shelves[k].characters.toList();
            const cols = 6, rows = 4;
            for (var i = 0; i < math.min(g.length, cols * rows); i++) {
              final r = Rect.fromLTWH(s.width * (i % cols) / cols, s.height * (i ~/ cols) / rows, s.width / cols, s.height / rows).deflate(6);
              c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = const Color(0xFFF4EFE4));
              Vignette.text(c, g[i], r, r.height * 0.62, ink, lang: k == 2 ? 'ja' : null, weight: FontWeight.w600);
            }
          },
          glow: 0.15,
          thick: 0.02,
        ),
      ],
      sign(2.3, 0.62, vm.Matrix4.translation(vm.Vector3(_shopX, 2.5, _counterZ - 0.06)), (c, s) {
        // The noren: three panels of navy, TOFU in white.
        final w = s.width / 3;
        for (var i = 0; i < 3; i++) {
          c.drawRect(Rect.fromLTWH(i * w + 3, 0, w - 6, s.height), Paint()..color = const Color(0xFF1E2A4A));
        }
        Vignette.text(c, 'TOFU', Rect.fromLTWH(0, 0, s.width * 0.7, s.height * 0.95), s.height * 0.5, const Color(0xFFF4F1EA));
        Vignette.text(c, '.notdef', Rect.fromLTWH(s.width * 0.67, s.height * 0.3, s.width * 0.32, s.height * 0.5), s.height * 0.22, const Color(0xFFF4F1EA));
      }, glow: 0.3),
      sign(1.9, 0.4, vm.Matrix4.translation(vm.Vector3(_shopX, 3.18, _counterZ - 0.1)), (c, s) {
        c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF4EBD8));
        Vignette.text(c, 'TOFU SHOP · □', Rect.fromLTWH(0, 0, s.width, s.height), s.height * 0.6, const Color(0xFF8E2A1E));
      }),
    ]);
    // The tofu's face: the .notdef box, the code point's hex in it.
    _tofuFace = await sign(
      0.2,
      0.2,
      vm.Matrix4.identity(),
      (c, s) {
        c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFFFFFF));
        c.drawRect(
          (Offset.zero & s).deflate(s.width * 0.12),
          Paint()
            ..color = const Color(0xFF1E2230)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width * 0.05,
        );
        Vignette.text(c, '03', Rect.fromLTWH(0, s.height * 0.2, s.width, s.height * 0.3), s.height * 0.26, const Color(0xFF1E2230), family: BP.mono);
        Vignette.text(c, '78', Rect.fromLTWH(0, s.height * 0.5, s.width, s.height * 0.3), s.height * 0.26, const Color(0xFF1E2230), family: BP.mono);
      },
      px: 256,
      glow: 0.2,
      thick: 0.004,
    );
    _tofuFace.visible = false;
  }

  // ── Posing ──────────────────────────────────────────────────────────────

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    pool.begin();
    // The kiosks' lamps: in turn as the fonts are asked in order, the
    // app's own first, then the platform's; amber again as Dash asks at
    // one, green as it gets its yes there (its glyph lit on the shelf).
    for (var k = 0; k < 4; k++) {
      final a = u - _answers[k];
      var amber = smooth(_inOrder + 0.7 * k, _inOrder + 0.7 * k + 0.15, u) * (1 - smooth(_inOrder + 0.7 * k + 0.6, _inOrder + 0.7 * k + 0.8, u));
      if (k == 0) amber = math.max(amber, smooth(_appsOwn, _appsOwn + 0.2, u) * (1 - smooth(_platform - 0.2, _platform, u)));
      if (k > 0) amber = math.max(amber, smooth(_platform, _platform + 0.2, u) * (1 - smooth(_listEnd - 0.2, _listEnd, u)));
      amber = math.max(amber, smooth(-0.45, -0.3, a) * (1 - smooth(-0.05, 0.1, a)));
      // (Green till Dash moves on.)
      final on = _steps[k + 1] + 0.5;
      final green = smooth(0, 0.15, a) * (1 - smooth(on, on + 0.4, u));
      final c = vm.Vector4(0.08 + 2.4 * amber + 0.3 * green, 0.08 + 1.5 * amber + 2.6 * green, 0.09 + 0.2 * amber + 0.9 * green, 1);
      pglow(_kx[k] + 0.7, 1.08, _counterZ + 0.1, 0.12, 0.12, 0.12, c);
      if (green > 0.02) {
        final cell = _tray[k].$3;
        final cx = _kx[k] - 0.64 + 0.256 * (cell % 6), cy = 2.07 - 0.345 * (cell ~/ 6);
        pglow(cx, cy, _shelfZ + 0.04, 0.24, 0.33, 0.01, vm.Vector4(0.3 * green, 2.2 * green, 0.8 * green, 1));
      }
    }
    // Dash along the row, its placard held up (turned to the camera).
    final (x, z, yaw, walking) = _dashAt(u);
    final pole = _dash.place(this, x, z, yaw, walking: walking, t: t, size: _size, poleTop: _cardY - _cardH / 2);
    final px = pole.x, py = _cardY, pz = pole.z;
    _faceCamera(_placard, px, py, pz);
    // A tile for each code point it still has: at each kiosk a no over
    // each (✕), a yes over the one it has (✓), that one then handed over
    // onto the counter and left there. U+0378's becomes the tofu.
    for (var i = 0; i < _tray.length; i++) {
      final f = _tray[i].$2, tile = _tiles[i];
      final tx = px + _tileX(i), ty = py, tz = pz - 0.02;
      tile.visible = true;
      if (f < 4 && u - _answers[f] > 0.6) {
        final k = eio(seg(u - _answers[f], 0.6, 1.3));
        final cx = _kx[f] - 0.3 - 0.05 * f, cy = 0.975 + _tileS / 2 + 0.01, cz = _counterZ + 0.1;
        _faceCamera(tile, lerp(tx, cx, k), lerp(ty, cy, k) + 0.3 * math.sin(math.pi * k), lerp(tz, cz, k));
        continue;
      }
      if (f == 4 && u >= _onCard) {
        tile.visible = false;
        continue;
      }
      _faceCamera(tile, tx, ty, tz);
      for (var k = 0; k < 4 && k <= f; k++) {
        final a = u - _answers[k];
        if (k == f) {
          final yes = smooth(0, 0.15, a) * (1 - smooth(0.5, 0.65, a));
          if (yes > 0.02) _mark(tx, ty + 0.17, tz - 0.03, true, yes, 0.42);
        } else {
          final no = _flash(a);
          if (no > 0.02) _mark(tx, ty + 0.17, tz - 0.03, false, no, 0.42);
        }
      }
    }
    _tofu(u, px, py, pz);
    _serve(u);
    pool.end();
  }

  /// A no's light: on as the answer comes, off soon after.
  static double _flash(double a) => smooth(-0.15, 0.05, a) * (1 - smooth(0.6, 0.85, a));

  /// The tofu shop: the press stamps one out, it goes over onto Dash's
  /// placard in U+0378's place, its hex to the camera.
  void _tofu(double u, double px, double py, double pz) {
    final s = u - _stamp;
    final down = s < -0.2 ? 0.0 : (s < 0 ? math.pow((s + 0.2) / 0.2, 2).toDouble() : (s < 0.12 ? 1.0 : 1 - eio(seg(s, 0.12, 0.6))));
    _ram.localTransform = place(trs(vm.Vector3(_shopX - 0.3, lerp(1.52, 1.14, down), _counterZ + 0.2)));
    if (s < 0) {
      _tofuFace.visible = false;
      return;
    }
    if (s < 0.6) {
      final k = s / 0.6;
      kit.fx.flashes.add((world(_shopX - 0.3, 1.1, _counterZ + 0.1), vm.Vector4(0.9, 0.95, 1, 1), (1 - k) * 0.6));
    }
    // On the counter under the press; over and up onto the placard.
    final over = eio(seg(u, _over, _onCard));
    final x = lerp(_shopX - 0.3, px + _tileX(4), over), z = lerp(_counterZ + 0.2, pz - 0.05, over);
    final y = lerp(1.1, py, over) + 0.3 * math.sin(math.pi * over);
    pbox(x, y, z, 0.2, 0.2, 0.2, Vignette.c(0xFFFFFF));
    _tofuFace.visible = true;
    _faceCamera(_tofuFace, x, y, z - 0.102);
  }

  /// The dish: up from behind the tank (the tofu out of its water first),
  /// over it and down onto the counter, as if handed across, from
  /// [_served] (once the tofu's up on the placard) to [_landed]; then the
  /// tofu wobbles. On the counter right of the placard as the camera sees
  /// it (beside the tofu on it, not behind), in front of the tank.
  static const _served = _onCard + 0.5, _landed = _served + 0.75;
  static const _dishX = _shopX + 0.72, _dishZ = _counterZ + 0.15;

  void _serve(double u) {
    _dish.visible = u >= _served;
    if (!_dish.visible) return;
    final k = eio(seg(u, _served, _landed));
    _dish.localTransform = place(trs(vm.Vector3(_dishX, lerp(0.9, 1.0, k) + 0.42 * math.sin(math.pi * k), lerp(0.5, _dishZ, k))));
    final w = u - _landed, wobble = w < 0 ? 0.0 : 0.12 * math.exp(-4.5 * w) * math.cos(2 * math.pi * 3.2 * w);
    _block.localTransform = trs(vm.Vector3(0, 0.025, 0), s: vm.Vector3(1 + 0.5 * wobble, 1 - wobble, 1 + 0.5 * wobble));
  }

  /// A big ✕ (red) or ✓ (green) in light at (x, y, z), [size] of a robot's.
  void _mark(double x, double y, double z, bool yes, double k, [double size = 1]) {
    final s = (0.85 + 0.15 * k) * size;
    if (yes) {
      final c = vm.Vector4(0.3 * k, 2.4 * k, 0.8 * k, 1);
      pglow(x - 0.07 * s, y - 0.04 * s, z, 0.05 * s, 0.2 * s, 0.03, c, roll: 0.75);
      pglow(x + 0.07 * s, y + 0.03 * s, z, 0.05 * s, 0.36 * s, 0.03, c, roll: -0.6);
    } else {
      final c = vm.Vector4(2.6 * k, 0.25 * k, 0.2 * k, 1);
      pglow(x, y, z, 0.05 * s, 0.4 * s, 0.03, c, roll: 0.785);
      pglow(x, y, z, 0.05 * s, 0.4 * s, 0.03, c, roll: -0.785);
    }
  }

  final _mm = vm.Matrix4.identity();

  /// Node [n] at (x, y, z) of the frame, facing the path (−z).
  void _faceCamera(Node n, double x, double y, double z) {
    _mm
      ..setIdentity()
      ..setTranslationRaw(x, y, z);
    n.localTransform = frame * _mm;
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    // Wide on the whole row as the fonts are asked in order (Dash waiting
    // in front, its placard up; all five kiosks right of the card); down
    // along it with Dash from the first press, and with it to the tofu
    // shop; in on the tofu; and a little in, and over, as the dish comes.
    final near = smooth(_steps[0], _steps[0] + 1.5, u), close = smooth(_toShop - 0.6, _toShop + 1.3, u);
    final dish = eio(seg(u, _served, _landed + 0.6));
    final dx = _dashAt(u).$1;
    final x = lerp(0.5, dx + 0.5, near);
    final eye = vm.Vector3(lerp(lerp(x, x + 0.2, near), _shopX - 0.9, close), lerp(lerp(6.3, 3.2, near), 2.9, close), lerp(lerp(-16.4, -6.4, near), -5.7, close));
    final target = vm.Vector3(lerp(x, _shopX - 0.1, close), lerp(lerp(1.4, 1.25, near), 1.1, close), lerp(0, -0.6, close));
    eye.add((vm.Vector3(_shopX - 0.55, 2.55, -4.9) - eye) * dish);
    target.add((vm.Vector3(_shopX + 0.3, 1.12, -0.55) - target) * dish);
    return Shot(eye, target, fov: 42, settle: 1.2, drift: 0.4);
  }
}

/// Dash (dashes.dart's model: one of its own here), waddling along with a
/// placard on a pole in its right wing. Faces −z at yaw 0.
class _Dash {
  _Dash(this.body, this.wingR, this.wingL, this.feet, this.pole);

  final Node body, wingR, wingL, pole;
  final List<Node> feet;

  static Future<_Dash> build(Vignette v) async {
    final parts = await modelParts('assets/models/dash.glb');
    final white = pbr(rgb(1, 1, 1), roughness: 0.42);
    Node part(List<String> names) {
      final n = Node(name: 'tofu dash', mesh: Mesh(MeshGeometry.fromMeshData(names.length == 1 ? parts[names.first]! : MeshData.merge([for (final x in names) parts[x]!])), white));
      v.detail.add(n);
      return n;
    }

    final pole = Node(name: 'tofu dash pole', mesh: Mesh(CylinderGeometry(bottomRadius: 1, topRadius: 1, height: 1, radialSegments: 8), pbr(Vignette.c(0x6A5442), roughness: 0.7)))
      ..castsShadows = false;
    v.detail.add(pole);
    return _Dash(part(['dash_body', 'dash_eyes', 'dash_pupils', 'dash_glints']), part(['dash_wing_r']), part(['dash_wing_l']), [part(['dash_foot']), part(['dash_foot'])], pole);
  }

  final _base = vm.Matrix4.identity(), _root = vm.Matrix4.identity();

  /// At (x, z) of [v]'s frame facing [yaw], [walking] (0..1), [size]; its
  /// pole up to [poleTop]. Where the pole is (the frame's), for the
  /// placard on top.
  vm.Vector3 place(Vignette v, double x, double z, double yaw, {required double walking, required double t, required double size, required double poleTop}) {
    final step = t * 9.0, s = math.sin(step);
    final bob = walking * 0.022 * s.abs() + 0.005 * math.sin(t * 2.1);
    _base
      ..setIdentity()
      ..translateByDouble(x, 0, z, 1)
      ..rotateY(yaw);
    _root
      ..setFrom(_base)
      ..translateByDouble(0, bob, 0, 1)
      ..rotateX(-walking * 0.07)
      ..rotateZ(walking * 0.085 * s)
      ..scaleByDouble(size, size, size, 1);
    body.localTransform = v.frame * _root;
    for (var k = 0; k < 2; k++) {
      final ph = step + k * math.pi, lift = walking * 0.035 * math.max(0.0, math.sin(ph));
      feet[k].localTransform = v.frame *
          (_base.clone()
            ..scaleByDouble(size, size, size, 1)
            ..translateByDouble(k == 0 ? -0.07 : 0.07, 0.11 + lift, -walking * 0.045 * math.cos(ph), 1));
    }
    // Its wings: the right forward round the pole; the left swinging.
    vm.Matrix4 wing(double side, double pitch) => _root.clone()
      ..translateByDouble(side * 0.215, 0.385, 0.02, 1)
      ..rotateZ(side * 0.14)
      ..rotateX(pitch);
    final right = wing(1, 1.15);
    wingR.localTransform = v.frame * right;
    wingL.localTransform = v.frame * wing(-1, -walking * 0.28 * s);
    // The pole: up from the right wing's tip to the placard.
    final tip = right.transform3(vm.Vector3(0, -0.205, 0.035));
    final h = math.max(0.2, poleTop - tip.y);
    pole.localTransform = v.frame * trs(vm.Vector3(tip.x, tip.y + h / 2, tip.z), s: vm.Vector3(0.016, h, 0.016));
    return vm.Vector3(tip.x, 0, tip.z);
  }
}
