import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'devices.dart' show deviceScreen;
import 'kit.dart';
import 'live_screen.dart';
import 'shapes.dart' show roundedSlab;
import 'shot.dart';
import 'vignette.dart';

/// 家族 · A string ≠ text, on the lawn behind the site: a board in the park.
/// First what everyone assumes: "Hello", five letters, counted every way a
/// String can — characters, runes, UTF-16 units, UTF-8 bytes — five each
/// time, each letter one code point. Then, in front of it, 👨‍👩‍👧‍👦 on a
/// tile, out for a walk — one emoji, one grapheme. Under the hood it comes apart into what the string holds,
/// 👨 ZWJ 👩 ZWJ 👧 ZWJ 👦: seven code points, the three joiners glowing
/// between the people. Take the joiners out (they drop) and four people
/// stand apart. The board ([_Board], painted live) counts it the four ways
/// a String can — characters, runes, UTF-16 units, UTF-8 bytes — each as
/// the narration says it, and shows that accents, flags and skin tones
/// are sequences too. A press a part (the narration's clips: 01 string0,
/// Hello; string1 from [_walkIn], the family; string2 from [_out]).
class ZwjFamily extends Vignette {
  ZwjFamily(super.kit);

  @override
  String get name => 'family';
  @override
  String get kick => 'STRING ≠ TEXT';
  @override
  String get line => '👨‍👩‍👧‍👦 = 1 grapheme';
  @override
  String get note => '7 code points joined by ZWJ · 11 UTF-16 units · 25 bytes';

  @override
  double get loop => 66;
  @override
  double get visit => 18;

  /// Facing the site.
  @override
  final frame = trs(vm.Vector3(6.6, 0, 15.2), rotY: math.pi);

  // The timeline (scene seconds, as the narration says each part): Hello,
  // counted; the family walks in, is one grapheme, comes apart, its
  // joiners glow; from [_out]: the joiners out, the people apart.
  static const _walkIn = 8.3, _one = 12.8, _split = 14.6, _glue = 17.0, _joiners = 19.3;
  static const _out = 32.6, _spread = 33.8;

  /// The board: its middle, its size (16:9), how far in front of it the
  /// tiles stand; the tiles' height.
  static const _boardY = 0.5 + _boardH / 2, _boardZ = 0.62, _boardW = 5.2, _boardH = 2.925;
  static const _tileY = 1.95, _tileZ = 0.25, _depth = 0.09;

  /// The code points in a row (👨 ZWJ 👩 ZWJ 👧 ZWJ 👦), and the people apart.
  static const _rowX = [-1.47, -0.98, -0.49, 0.0, 0.49, 0.98, 1.47];
  static const _apartX = [-1.86, -0.62, 0.62, 1.86];
  static const _people = ['👨', '👩', '👧', '👦'], _codes = ['U+1F468', 'U+1F469', 'U+1F467', 'U+1F466'];

  @override
  List<(String, TextStyle)> get fontRuns => [
    ('👨‍👩‍👧‍👦 👨👩👧👦 👨 👩 👧 👦 🇯🇵 🇯 🇵 👋🏽 👋 🏽 é ✓', const TextStyle()),
    ('Hello', const TextStyle(fontFamily: BP.display)),
    ('ZWJ 200D U+1F468 U+1F469 U+1F467 U+1F466 U+0048 U+0065 U+006C U+006F .characters .runes .length utf8 bytes 0123456789 = letter code point unit byte', const TextStyle(fontFamily: BP.mono)),
  ];

  final _u = ValueNotifier<double>(0);
  late final LiveScreen _screen;
  late final Node _big;
  final _persons = <Node>[], _joinTiles = <Node>[];
  late final PhysicallyBasedMaterial _glow;
  final _m = vm.Matrix4.identity();
  bool _ready = false;

  @override
  Future<void> init() async {
    final b = Batch();
    final coat = pbr(rgb(1, 1, 1), roughness: 0.45, metallic: 0.55);
    final m = pbr(rgb(1, 1, 1), roughness: 0.8);
    // The board's posts and feet, its bezel.
    for (final x in [-_boardW / 2 - 0.14, _boardW / 2 + 0.14]) {
      box(b, coat, 0.1, _boardY + _boardH / 2 + 0.1, 0.1, x, (_boardY + _boardH / 2 + 0.1) / 2, _boardZ + 0.05, Vignette.c(0x2A2E35));
      box(b, coat, 0.16, 0.06, 0.8, x, 0.03, _boardZ + 0.05, Vignette.c(0x2A2E35));
    }
    box(b, m, _boardW + 0.14, _boardH + 0.14, 0.07, 0, _boardY, _boardZ + 0.05, Vignette.c(0x101216));
    b.buildInto(detail, 'family board', castsShadows: false, lightChannelMask: 0x01);

    // The board's screen: dark until its first capture.
    final dark = await paintedTexture(4, 4, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = _Board.bg));
    final screen = deviceScreen(dark);
    detail.add(
      Node(
        name: 'family screen',
        mesh: Mesh(boardGeometry(_boardW, _boardH, thick: 0.01), screen),
        localTransform: place(vm.Matrix4.translation(vm.Vector3(0, _boardY, _boardZ))),
      )..castsShadows = false,
    );
    _screen = LiveScreen(_Board.w, _Board.h, CustomPaint(painter: _Board(_u)), pixelRatio: kIsWeb ? 0.6 : 1.25)..show(screen);

    // The tiles: white, the emoji on their faces; the joiners glowing.
    final white = pbr(rgb(1, 1, 1), roughness: 0.42);
    _glow = pbr(rgb(1, 1, 1), roughness: 0.35, emissive: lin(const Color(0xFF39D3F0)), emissiveStrength: 0.8);
    Future<Node> tile(double w, double h, PhysicallyBasedMaterial slab, vm.Vector4 color, int px, void Function(Canvas c, Size s) face) async {
      final tex = await paintedTexture(px, (px * h / w).round(), face);
      final faceMat = PhysicallyBasedMaterial()
        ..baseColorTexture = tex
        ..roughnessFactor = 0.55
        ..emissiveTexture = tex
        ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
        ..emissiveStrength = 0.3;
      final n = Node(name: 'family tile', mesh: Mesh(MeshGeometry.fromMeshData(painted(roundedSlab(w, h, _depth, corner: 0.06, edge: 0.018, cornerSteps: 3, edgeSteps: 2), color)), slab))
        ..castsShadows = false
        ..visible = false;
      n.add(
        Node(
          name: 'family tile face',
          mesh: Mesh(boardGeometry(w * 0.88, h * 0.88, thick: 0.004), faceMat),
          localTransform: vm.Matrix4.translation(vm.Vector3(0, 0, -_depth / 2 - 0.004)),
        )..castsShadows = false,
      );
      detail.add(n);
      return n;
    }

    _big = await tile(1.0, 1.0, white, Vignette.c(0xF6F3EC), 1024, (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF6F3EC));
      _emoji(c, '👨‍👩‍👧‍👦', Offset(s.width / 2, s.height / 2), s.width * 0.62);
    });
    for (var i = 0; i < 4; i++) {
      _persons.add(
        await tile(0.56, 0.68, white, Vignette.c(0xF6F3EC), 512, (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF6F3EC));
          _emoji(c, _people[i], Offset(s.width / 2, s.height * 0.42), s.width * 0.62);
          _label(c, _codes[i], Offset(s.width / 2, s.height * 0.86), s.width * 0.1, const Color(0xFF5B6475));
        }),
      );
    }
    for (var i = 0; i < 3; i++) {
      _joinTiles.add(
        await tile(0.26, 0.68, _glow, Vignette.c(0x1B6E8A), 256, (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0E3B4D));
          c.drawRRect(
            RRect.fromRectAndRadius((Offset.zero & s).deflate(8), const Radius.circular(18)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..color = const Color(0xFF5BE3FF),
          );
          _label(c, 'ZWJ', Offset(s.width / 2, s.height * 0.44), s.width * 0.26, const Color(0xFFDDF8FF));
          _label(c, '200D', Offset(s.width / 2, s.height * 0.58), s.width * 0.17, const Color(0xFF7FE4F8));
        }),
      );
    }
    _ready = true;
  }

  static void _emoji(Canvas c, String s, Offset at, double size) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  static void _label(Canvas c, String s, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: BP.mono, fontSize: size, fontWeight: FontWeight.w700, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  // ── Posing ────────────────────────────────────────────────────────────────

  /// Puts tile [n] at (x, y) of the row (its frame), [s] its size, turned
  /// [roll] about its middle.
  void _put(Node n, double x, double y, double s, {double roll = 0, double z = _tileZ}) {
    if (s <= 0.001) {
      n.visible = false;
      return;
    }
    n.visible = true;
    _m.setFromTranslationRotationScale(vm.Vector3(x, y, z), vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll), vm.Vector3.all(s));
    n.localTransform = frame * _m;
  }

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    // (The crowd walks round the board.)
    for (var x = -2.4; x <= 2.41; x += 0.8) {
      kit.walkers.add(world(x, 0, _boardZ));
    }
    if (visited) {
      _u.value = u;
      _screen.capture();
    }
    // The family, one tile, walks in along the board (a hop a step), and
    // stands; then shrinks away as its people come out of it.
    final walk = seg(u, _walkIn, _walkIn + 2.1);
    if (u < _walkIn || u >= _split + 0.45) {
      _big.visible = false;
    } else {
      final hop = (math.sin(math.pi * 4 * walk)).abs() * (1 - walk);
      final shrink = 1 - eio(seg(u, _split, _split + 0.45));
      _put(
        _big,
        lerp(-3.0, 0, eio(walk)),
        _tileY + 0.14 * hop,
        math.min(1.0, seg(u, _walkIn, _walkIn + 0.3)) * shrink * (1 + 0.04 * math.sin(math.pi * seg(u, _one - 0.2, _one + 0.4))),
        roll: 0.07 * math.sin(math.pi * 4 * walk) * (1 - walk),
      );
    }
    // The people: out of it to their places in the row; apart once the
    // joiners are out (each its own character, bobbing on its own).
    final spread = eio(seg(u, _spread, _spread + 1.2));
    for (var i = 0; i < 4; i++) {
      final k = seg(u, _split + 0.1 + 0.12 * i, _split + 1.0 + 0.12 * i);
      if (k <= 0) {
        _persons[i].visible = false;
        continue;
      }
      final e = Curves.easeOutBack.transform(k);
      final x = lerp(lerp(0, _rowX[2 * i], e), _apartX[i], spread);
      final bob = spread * 0.05 * math.sin(t * 2.1 + i * 1.7);
      _put(_persons[i], x, _tileY + bob, lerp(0.3, 1, math.min(1.0, e)), roll: spread * 0.04 * math.sin(t * 1.6 + i * 2.3));
    }
    // The joiners: up into the gaps, glowing (brighter as the narration
    // names them); out: they drop, tumbling, and are gone.
    final drop = seg(u, _out, _out + 1.0);
    for (var j = 0; j < 3; j++) {
      final k = seg(u, _glue + 0.15 * j, _glue + 0.8 + 0.15 * j);
      final gone = seg(u, _out + 0.75 + 0.05 * j, _out + 1.15 + 0.05 * j);
      if (k <= 0 || gone >= 1) {
        _joinTiles[j].visible = false;
        continue;
      }
      final e = Curves.easeOutBack.transform(k);
      final d = drop * drop;
      _put(_joinTiles[j], _rowX[2 * j + 1], _tileY - 0.9 * (1 - e) - 1.6 * d, e * (1 - gone), roll: (j - 1) * 0.9 * d + 0.5 * d);
    }
    final named = smooth(_joiners - 0.3, _joiners + 0.2, u) * (1 - smooth(_joiners + 1.4, _joiners + 2.4, u));
    _glow.emissiveStrength = 0.8 + 1.6 * named + 0.25 * math.sin(t * 4);
  }

  // ── The camera ────────────────────────────────────────────────────────────

  /// Square on to the board, the tiles in front of it.
  @override
  Shot shot(double u) => Shot(vm.Vector3(-0.35, 1.9, -5.1), vm.Vector3(0, 1.95, _boardZ), fov: 46, settle: 1.1, drift: 0.3);
}

/// The family's board, painted by Flutter as the scene runs ([u]: its
/// seconds), 1600×900: along the top, the strings counted four ways (each
/// count as the narration says it): Hello first, where every count agrees,
/// then the family's; in the middle, Hello's letters one by one with their
/// code points, then, dark, behind the tiles, what they are (one grapheme,
/// seven code points, four characters); along the bottom, other sequences
/// that make one character.
class _Board extends CustomPainter {
  _Board(this.u) : super(repaint: u);

  final ValueListenable<double> u;

  static const w = 1600.0, h = 900.0;
  static const bg = Color(0xFF0B1628);

  static const _heads = ['.characters', '.runes', '.length', 'utf8 bytes'];
  static const _strings = ['Hello', '👨‍👩‍👧‍👦', '👨👩👧👦'];
  static const _counts = [
    [5, 5, 5, 5],
    [1, 7, 11, 25],
    [4, 4, 8, 16],
  ];

  /// When each count's said (the people apart's alongside the family's).
  static const _at = [
    [2.4, 3.1, 3.8, 4.5],
    [12.8, 38.0, 39.6, 40.9],
    [35.2, 38.0, 39.6, 40.9],
  ];

  /// When each row comes in: Hello from the start; the family as it walks
  /// in; the people apart as they're counted. When Hello's counts are all
  /// in, agreeing (a tick). The rows' heights.
  static const _rowIn = [0.6, ZwjFamily._walkIn, 34.6], _agree = 5.1;
  static const _rowY = [128.0, 197.0, 260.0];

  /// Hello's letters, their code points.
  static const _hello = ['H', 'e', 'l', 'l', 'o'], _helloCodes = ['U+0048', 'U+0065', 'U+006C', 'U+006C', 'U+006F'];

  /// "Count what? Characters, runes, code units, or bytes?": each column
  /// then; "the characters package" after.
  static const _ask = 49.5, _heads2 = [51.6, 53.2, 54.3, 55.4], _package = 57.4;

  /// The other sequences (when each comes in), and the accented e's turn.
  static const _examples = [
    ('e\u0301', '= e + U+0301', '2 code points'),
    ('🇯🇵', '= 🇯 + 🇵', '2 regional indicators'),
    ('👋🏽', '= 👋 + 🏽', 'hand + skin tone'),
  ];
  static const _exampleAt = [22.3, 24.9, 27.0], _accentE = 42.8;

  static const _colX = [600.0, 870.0, 1110.0, 1370.0];

  /// Laid-out text, kept (each string in each of its looks laid out once).
  final _laid = <String, TextPainter>{};

  TextPainter _tp(String key, String text, TextStyle style) {
    final hit = _laid[key];
    if (hit != null) return hit;
    if (_laid.length > 600) {
      for (final p in _laid.values) {
        p.dispose();
      }
      _laid.clear();
    }
    return _laid[key] = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
  }

  static TextStyle _mono(double size, Color color, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: BP.mono, fontSize: size, fontWeight: weight, color: color);

  static void _put(Canvas c, TextPainter tp, Offset at, {bool left = false}) =>
      tp.paint(c, at - Offset(left ? 0 : tp.width / 2, tp.height / 2));

  static const _dim = Color(0xFF6F84A6), _ink = Color(0xFFE8F0FA);

  @override
  void paint(Canvas c, Size s) {
    final t = math.max(0.0, u.value);
    c.save();
    c.scale(s.width / w);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
    _table(c, t);
    _latin(c, t);
    _middle(c, t);
    _bottom(c, t);
    c.restore();
  }

  /// Which column's lit after the counts are all out (null: none yet).
  static int? _column(double t) {
    if (t >= _package) return 0;
    int? lit;
    for (var i = 0; i < 4; i++) {
      if (t >= _heads2[i]) lit = i;
    }
    return lit;
  }

  void _table(Canvas c, double t) {
    final panel = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 28, w - 80, 266), const Radius.circular(22));
    c.drawRRect(panel, Paint()..color = const Color(0xFF10203A));
    c.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF243A5C),
    );
    final col = _column(t);
    final asking = t >= _ask && col == null;
    // The headers.
    _put(c, _tp('head s', 'String', _mono(26, _dim)), const Offset(170, 70));
    for (var i = 0; i < 4; i++) {
      final lit = col == i || (asking && (t * 2).floor().isEven);
      _put(c, _tp('head $i $lit', _heads[i], _mono(30, lit ? BP.amber : const Color(0xFF9DB2D4))), Offset(_colX[i], 70));
    }
    if (t >= _package) {
      final k = smooth(_package, _package + 0.4, t);
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(_colX[0], 168), width: 230, height: 250), const Radius.circular(18));
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = BP.amber.withValues(alpha: k),
      );
      final tag = _tp('package', 'package:characters', _mono(20, const Color(0xFF0B1628), weight: FontWeight.w700));
      final box = Rect.fromCenter(center: Offset(_colX[0], 40), width: tag.width + 24, height: 34);
      c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(9)), Paint()..color = BP.amber.withValues(alpha: k));
      _put(c, tag, box.center);
    }
    // The strings (each as it comes in) and their counts: a dash until
    // said, then counted up, lit until the next.
    var latest = (-1, -1);
    var latestAt = -1.0;
    for (var r = 0; r < 3; r++) {
      for (var i = 0; i < 4; i++) {
        final a = _at[r][i];
        if (t >= a && a >= latestAt && (r < 2 || i == 0)) {
          latestAt = a;
          latest = (r, i);
        }
      }
    }
    for (var r = 0; r < 3; r++) {
      final y = _rowY[r];
      final rowAlpha = smooth(_rowIn[r], _rowIn[r] + 0.6, t);
      if (rowAlpha <= 0) continue;
      final str = _tp('str $r', _strings[r], TextStyle(fontFamily: r == 0 ? BP.display : null, fontSize: const [44.0, 50.0, 38.0][r], fontWeight: FontWeight.w600, color: _ink));
      c.saveLayer(Rect.fromCenter(center: Offset(170, y), width: 260, height: 70), Paint()..color = Color.fromRGBO(255, 255, 255, rowAlpha));
      _put(c, str, Offset(170, y));
      c.restore();
      for (var i = 0; i < 4; i++) {
        final a = _at[r][i];
        final Color color;
        final String text;
        if (t < a) {
          text = '—';
          color = const Color(0xFF3C4E6C);
        } else {
          final k = Curves.easeOutCubic.transform(seg(t, a, a + 0.5));
          text = '${(_counts[r][i] * k).round()}';
          final lit = col == null ? latest == (r, i) || (r == 2 && i > 0 && latest == (1, i)) : col == i;
          color = lit ? BP.amber : (r == 1 ? _ink : const Color(0xFFAFC0DA));
        }
        final tp = _tp('val $r $i $text ${color.toARGB32()}', text, _mono(const [44.0, 50.0, 40.0][r], color, weight: FontWeight.w700));
        c.saveLayer(Rect.fromCenter(center: Offset(_colX[i], y), width: 200, height: 70), Paint()..color = Color.fromRGBO(255, 255, 255, rowAlpha));
        _put(c, tp, Offset(_colX[i], y));
        c.restore();
      }
      // Hello's four counts agree: a tick at the row's end.
      if (r == 0) {
        final k = smooth(_agree, _agree + 0.35, t);
        if (k > 0) {
          final tick = _tp('agree', '✓ all 5', _mono(26, const Color(0xFF6FCF97), weight: FontWeight.w700));
          c.saveLayer(Rect.fromCenter(center: Offset(1490, y), width: 150, height: 60), Paint()..color = Color.fromRGBO(255, 255, 255, k * rowAlpha));
          _put(c, tick, Offset(1490, y));
          c.restore();
        }
      }
    }
  }

  /// In the middle (before the family comes to stand in front of it):
  /// Hello's letters one by one, each one code point, one UTF-16 unit, one
  /// byte.
  void _latin(Canvas c, double t) {
    final k = smooth(1.0, 1.6, t) * (1 - smooth(ZwjFamily._walkIn - 0.7, ZwjFamily._walkIn - 0.1, t));
    if (k <= 0) return;
    c.saveLayer(const Rect.fromLTWH(0, 300, w, 380), Paint()..color = Color.fromRGBO(255, 255, 255, k));
    const bw = 170.0, bh = 200.0, gap = 26.0, top = 340.0;
    const x0 = (w - 5 * bw - 4 * gap) / 2;
    for (var i = 0; i < 5; i++) {
      final e = smooth(1.2 + 0.18 * i, 1.6 + 0.18 * i, t);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x0 + i * (bw + gap), top + 16 * (1 - e), bw, bh), const Radius.circular(18));
      c.drawRRect(r, Paint()..color = const Color(0xFF10203A).withValues(alpha: e));
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF5FB8FF).withValues(alpha: e),
      );
      final ch = _tp('hello $i', _hello[i], const TextStyle(fontFamily: BP.display, fontSize: 104, fontWeight: FontWeight.w600, color: _ink));
      final code = _tp('hello code $i', _helloCodes[i], _mono(24, const Color(0xFF9DB2D4)));
      c.saveLayer(r.outerRect, Paint()..color = Color.fromRGBO(255, 255, 255, e));
      _put(c, ch, Offset(r.center.dx, r.top + 88));
      _put(c, code, Offset(r.center.dx, r.bottom - 30));
      c.restore();
    }
    final note = _tp('hello note', '1 letter = 1 code point = 1 UTF-16 unit = 1 byte', _mono(26, const Color(0xFF6FCF97), weight: FontWeight.w600));
    c.saveLayer(const Rect.fromLTWH(0, 560, w, 60), Paint()..color = Color.fromRGBO(255, 255, 255, smooth(_agree, _agree + 0.4, t)));
    _put(c, note, const Offset(w / 2, 590));
    c.restore();
    c.restore();
  }

  /// Under the tiles: a bracket, what they are.
  void _middle(Canvas c, double t) {
    void bracket(double half, String label, double k) {
      if (k <= 0) return;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF7FB6FF).withValues(alpha: k);
      const y = 636.0;
      c.drawPath(
        Path()
          ..moveTo(w / 2 - half, y - 12)
          ..lineTo(w / 2 - half, y)
          ..lineTo(w / 2 + half, y)
          ..lineTo(w / 2 + half, y - 12),
        p,
      );
      final tp = _tp('bracket $label', label, _mono(26, const Color(0xFFBFD8FF)));
      final r = Rect.fromCenter(center: Offset(w / 2, y), width: tp.width + 28, height: 38);
      c.drawRect(r, Paint()..color = bg);
      c.saveLayer(r, Paint()..color = Color.fromRGBO(255, 255, 255, k));
      _put(c, tp, r.center);
      c.restore();
    }

    bracket(170, '1 grapheme', smooth(ZwjFamily._one, ZwjFamily._one + 0.3, t) * (1 - smooth(ZwjFamily._split, ZwjFamily._split + 0.3, t)));
    bracket(560, '7 code points · 3 of them joiners', smooth(ZwjFamily._split + 1.6, ZwjFamily._split + 2.0, t) * (1 - smooth(ZwjFamily._out, ZwjFamily._out + 0.3, t)));
    bracket(680, '4 code points · 4 characters', smooth(ZwjFamily._spread + 1.2, ZwjFamily._spread + 1.6, t));
  }

  /// Along the bottom: not just emoji.
  void _bottom(Canvas c, double t) {
    final k0 = smooth(_exampleAt[0] - 0.3, _exampleAt[0], t);
    if (k0 <= 0) return;
    c.saveLayer(const Rect.fromLTWH(0, 680, w, 220), Paint()..color = Color.fromRGBO(255, 255, 255, k0));
    _put(c, _tp('not just', 'NOT JUST EMOJI', _mono(20, _dim)), const Offset(80, 700), left: true);
    c.restore();
    for (var i = 0; i < 3; i++) {
      final k = smooth(_exampleAt[i] - 0.3, _exampleAt[i], t);
      if (k <= 0) continue;
      final x = 80.0 + i * 490;
      final card = RRect.fromRectAndRadius(Rect.fromLTWH(x, 724, 460, 150), const Radius.circular(18));
      // Lit: the newest, while it's new; the accented e, when its turn
      // comes again.
      final next = i < 2 ? _exampleAt[i + 1] : _exampleAt[i] + 3;
      final lit = (t >= _exampleAt[i] && t < next) || (i == 0 && t >= _accentE && t < _accentE + 3.5);
      c.saveLayer(card.outerRect.inflate(4), Paint()..color = Color.fromRGBO(255, 255, 255, k));
      c.drawRRect(card, Paint()..color = const Color(0xFF10203A));
      c.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lit ? 3 : 2
          ..color = lit ? BP.amber : const Color(0xFF243A5C),
      );
      final (glyph, parts, note) = _examples[i];
      _put(c, _tp('ex $i', glyph, TextStyle(fontFamily: BP.display, fontSize: 84, color: _ink)), Offset(x + 88, 799));
      _put(c, _tp('parts $i', parts, TextStyle(fontFamily: BP.mono, fontSize: 36, fontWeight: FontWeight.w600, color: _ink)), Offset(x + 172, 778), left: true);
      _put(c, _tp('note $i $lit', note, _mono(20, lit ? BP.amber : _dim)), Offset(x + 172, 834), left: true);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_Board old) => old.u != u;
}
