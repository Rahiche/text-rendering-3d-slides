import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'devices.dart' show deviceScreen;
import 'kit.dart';
import 'live_screen.dart';
import 'shot.dart';
import 'vignette.dart';

/// 改行 · Line breaking, for the talk: a board on a gantry over the park's
/// long path, short of the tram, painted live by Flutter ([_Board]) — so
/// its lines are broken by Flutter's own line breaker. Three paragraphs,
/// each in a column of the same maxWidth: English filled greedily, a word
/// at a time, the one that won't fit starting the next line, then its
/// break opportunities (the spaces, UAX #14); Thai, with no spaces, cut
/// into words by ICU's dictionary; Japanese, breakable almost anywhere —
/// but the full stop may not start a line (kinsoku): a naive break leaves
/// it there, and the line gives up its last character to go with it.
/// Timed to the narration (01 lines1).
class TalkBreaks extends Vignette {
  TalkBreaks(super.kit);

  @override
  String get name => 'breaks';
  @override
  String get kick => 'LINE BREAKING';
  @override
  String get line => 'Fill the line, then the next';
  @override
  String get note => 'where a line may break: spaces, a dictionary, kinsoku';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 38;
  @override
  double get visit => 36;

  /// Over the long path, facing the forge (its −z: south).
  @override
  final frame = trs(vm.Vector3(0, 0, 60));

  /// The board: its middle, its size (16:9).
  static const _y = 4.4, _w = 6.4, _h = 3.6;

  @override
  List<(String, TextStyle)> get fontRuns => [
    (_Board.en, _Board.enStyle),
    (_Board.th, _Board.thStyle),
    (_Board.ja, _Board.jaStyle),
    ('ENGLISH THAI JAPANESE maxWidth spaces UAX #14 no spaces ICU dictionary kinsoku 禁則', const TextStyle(fontFamily: BP.mono)),
  ];

  final _u = ValueNotifier<double>(0);
  late final LiveScreen _screen;
  final _root = Node(name: 'breaks gantry');
  bool _ready = false;

  @override
  Future<void> init() async {
    detail.add(_root);
    final b = Batch();
    final coat = pbr(rgb(1, 1, 1), roughness: 0.45, metallic: 0.55);
    final m = pbr(rgb(1, 1, 1), roughness: 0.8);
    // The gantry: a post either side of the path, a beam over it, the
    // board's bezel hung from the beam.
    for (final x in [-3.45, 3.45]) {
      box(b, coat, 0.18, 6.4, 0.18, x, 3.2, 0.05, Vignette.c(0x2A2E35));
      box(b, coat, 0.5, 0.08, 0.5, x, 0.04, 0.05, Vignette.c(0x2A2E35));
    }
    box(b, coat, 7.1, 0.24, 0.24, 0, 6.4, 0.05, Vignette.c(0x2A2E35));
    for (final x in [-2.2, 2.2]) {
      box(b, coat, 0.06, 6.4 - _y - _h / 2, 0.06, x, (6.4 + _y + _h / 2) / 2, 0.05, Vignette.c(0x5A6470));
    }
    box(b, m, _w + 0.14, _h + 0.14, 0.08, 0, _y, 0.05, Vignette.c(0x101216));
    b.buildInto(_root, 'breaks gantry', castsShadows: false, lightChannelMask: 0x01);
    final dark = await paintedTexture(4, 4, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = _Board.bg));
    final screen = deviceScreen(dark);
    _root.add(
      Node(
        name: 'breaks screen',
        mesh: Mesh(boardGeometry(_w, _h, thick: 0.01), screen),
        localTransform: place(vm.Matrix4.translation(vm.Vector3(0, _y, 0))),
      )..castsShadows = false,
    );
    _screen = LiveScreen(_Board.w, _Board.h, CustomPaint(painter: _Board(_u)), pixelRatio: kIsWeb ? 0.6 : 1.25)..show(screen);
    _root.visible = false;
    _ready = true;
  }

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    // (Only while the talk's here.)
    _root.visible = visited;
    if (!visited) return;
    _u.value = u;
    _screen.capture();
  }

  /// Square on to the board, from over the path.
  @override
  Shot shot(double u) => Shot(vm.Vector3(-0.3, _y, -8.2), vm.Vector3(0, _y, 0), fov: 44, settle: 1.1, drift: 0.3);

  /// (The tram's waiting words show under the board: not while it's on.)
  @override
  List<String> get hides => const ['tram'];
}

/// The board, painted by Flutter as the scene runs ([u]: its seconds),
/// 1600×900: three columns, each its paragraph broken at the same
/// maxWidth by Flutter's own line breaker (laid out once, its glyphs'
/// places read back), shown as the narration comes to it.
class _Board extends CustomPainter {
  _Board(this.u) : super(repaint: u);

  final ValueListenable<double> u;

  static const w = 1600.0, h = 900.0;
  static const bg = Color(0xFF0B1628);

  static const en = 'Each line is filled up to the max width, then the next one starts.';
  static const th = 'สวัสดีครับยินดีต้อนรับสู่ฟลัตเตอร์';
  static const thWords = ['สวัสดี', 'ครับ', 'ยินดี', 'ต้อนรับ', 'สู่', 'ฟลัตเตอร์'];
  static const ja = '行頭に来ません。禁則と言います。';

  static const enStyle = TextStyle(fontFamily: BP.display, fontSize: 46, fontWeight: FontWeight.w600, color: _ink, height: 1.3);
  static const thStyle = TextStyle(fontSize: 46, color: _ink, height: 1.6, locale: Locale('th'));
  static const jaStyle = TextStyle(fontSize: 50, color: _ink, height: 1.5, locale: Locale('ja'));

  static const _ink = Color(0xFFE8F0FA), _dim = Color(0xFF6F84A6), _amber = BP.amber, _red = Color(0xFFFF5A5F);

  /// The columns' text areas' left edges; their tops; maxWidth (Japanese:
  /// seven characters exactly).
  static const _x0 = [70.0, 600.0, 1130.0], _top = 210.0, _max = 380.0, _maxJa = 352.0;

  // When each part comes (seconds into the scene, as the narration says
  // it: its clip's pauses, 1.5 s before the scene's start).
  static const _fillAt = 2.8, _wordStep = 0.36, _scripts = 7.8, _spaces = 13.0, _uax = 14.8;
  static const _thaiAt = 17.6, _noSpaces = 18.4, _dict = 20.4, _dictStep = 0.48;
  static const _japan = 24.3, _anywhere = 25.5, _catch = 29.6, _reflow = 31.3, _kinsoku = 33.0;

  // ── Layout (once) ─────────────────────────────────────────────────────────

  late final _en = _lay(en, enStyle, _max);
  late final _th = _lay(th, thStyle, _max);
  late final _ja = _lay(ja, jaStyle, _maxJa);

  /// The words' boxes as Flutter breaks each paragraph at its maxWidth
  /// (its characters', for Japanese).
  late final _enBoxes = [for (final (a, b) in _ranges(en, en.split(' '))) _box(_en, a, b)];
  late final _thBoxes = [for (final (a, b) in _ranges(th, thWords)) _box(_th, a, b)];
  late final _jaBoxes = [for (var i = 0; i < ja.length; i++) _box(_ja, i, i + 1)];

  static TextPainter _lay(String s, TextStyle style, double max) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout(maxWidth: max);

  /// Where each of [parts] is in [s] (start, end), in order.
  static List<(int, int)> _ranges(String s, List<String> parts) {
    final out = <(int, int)>[];
    var at = 0;
    for (final p in parts) {
      final i = s.indexOf(p, at);
      out.add((i, i + p.length));
      at = i + p.length;
    }
    return out;
  }

  static Rect _box(TextPainter tp, int a, int b) {
    final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: b));
    var r = boxes.first.toRect();
    for (final x in boxes.skip(1)) {
      r = r.expandToInclude(x.toRect());
    }
    return r;
  }

  /// Laid-out labels and words, kept.
  final _laid = <String, TextPainter>{};

  TextPainter _tp(String key, String text, TextStyle style) =>
      _laid[key] ??= TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

  static TextStyle _mono(double size, Color color, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: BP.mono, fontSize: size, fontWeight: weight, color: color);

  // ── Painting ──────────────────────────────────────────────────────────────

  @override
  void paint(Canvas c, Size s) {
    final t = math.max(0.0, u.value);
    c.save();
    c.scale(s.width / w);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
    _columns(c, t);
    _english(c, t);
    _thaiColumn(c, t);
    _japanese(c, t);
    c.restore();
  }

  /// Each column: its panel, its language and rule (as they come up), its
  /// maxWidth ruler.
  void _columns(Canvas c, double t) {
    const names = ['ENGLISH', 'THAI', 'JAPANESE'];
    const rules = ['spaces · UAX #14', 'no spaces · ICU dictionary', '。 never starts a line · kinsoku 禁則'];
    final shown = [1.0, smooth(_scripts + 0.6, _scripts + 1.0, t), smooth(_scripts + 1.2, _scripts + 1.6, t)];
    final ruleAt = [_uax, _dict + 0.6, _kinsoku];
    for (var i = 0; i < 3; i++) {
      if (shown[i] <= 0) continue;
      final x = _x0[i] - 30;
      final panel = RRect.fromRectAndRadius(Rect.fromLTWH(x, 40, 500, 820), const Radius.circular(22));
      c.saveLayer(panel.outerRect.inflate(4), Paint()..color = Color.fromRGBO(255, 255, 255, shown[i]));
      c.drawRRect(panel, Paint()..color = const Color(0xFF10203A));
      c.drawRRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF243A5C),
      );
      _put(c, _tp('name $i', names[i], _mono(26, _dim, weight: FontWeight.w700)), Offset(_x0[i], 92), left: true);
      final r = smooth(ruleAt[i], ruleAt[i] + 0.4, t);
      if (r > 0) {
        final tp = _tp('rule $i', rules[i], _mono(i == 2 ? 17 : 21, _amber));
        c.saveLayer(Rect.fromLTWH(x, 112, 500, 50), Paint()..color = Color.fromRGBO(255, 255, 255, r));
        _put(c, tp, Offset(_x0[i], 138), left: true);
        c.restore();
      }
      // maxWidth: a dashed line down the column, named at its foot.
      final mx = _x0[i] + (i == 2 ? _maxJa : _max);
      final dash = Paint()
        ..color = const Color(0xFF7FB6FF)
        ..strokeWidth = 2.5;
      for (var y = 180.0; y < 800; y += 22) {
        c.drawLine(Offset(mx, y), Offset(mx, y + 12), dash);
      }
      _put(c, _tp('max', 'maxWidth', _mono(20, const Color(0xFF7FB6FF))), Offset(mx, 822));
      c.restore();
    }
  }

  /// English: filled a word at a time (one that won't fit tried at the
  /// end of the line, red, then down to start the next); then its break
  /// opportunities, the spaces.
  void _english(Canvas c, double t) {
    final words = en.split(' ');
    final o = Offset(_x0[0], _top);
    for (var k = 0; k < words.length; k++) {
      final at = _fillAt + _wordStep * k;
      if (t < at) break;
      final r = _enBoxes[k];
      var pos = o + r.topLeft;
      var color = _ink;
      // A word that starts a line: tried first after the last one.
      if (k > 0) {
        final prev = _enBoxes[k - 1];
        if (r.top > prev.top + 4) {
          final tried = o + Offset(prev.right + 12, prev.top);
          final f = seg(t, at + 0.3, at + 0.55);
          pos = Offset.lerp(tried, pos, eio(f))!;
          if (f < 1) color = _red;
        }
      }
      _put(c, _tp('en $k ${color.toARGB32()}', words[k], enStyle.copyWith(color: color)), pos, left: true, top: true);
    }
    // The spaces: where a line may break.
    for (var k = 0; k + 1 < words.length; k++) {
      final m = smooth(_spaces + 0.12 * k, _spaces + 0.12 * k + 0.2, t);
      if (m <= 0) continue;
      final r0 = _enBoxes[k], r1 = _enBoxes[k + 1];
      // (At the end of the line when the next word starts another.)
      final x = r1.top > r0.top + 4 ? r0.right + 10 : (r0.right + r1.left) / 2;
      _bar(c, o + Offset(x, r0.top + 8), r0.height - 16, _amber, m);
    }
  }

  /// Thai: no spaces; ICU's dictionary finds the words, one by one.
  void _thaiColumn(Canvas c, double t) {
    final k0 = smooth(_thaiAt, _thaiAt + 0.4, t);
    if (k0 <= 0) return;
    final o = Offset(_x0[1], _top);
    c.saveLayer(Rect.fromLTWH(o.dx - 20, o.dy - 20, 500, 640), Paint()..color = Color.fromRGBO(255, 255, 255, k0));
    // The word being looked up.
    for (var k = 0; k < thWords.length; k++) {
      final at = _dict + _dictStep * k;
      final on = smooth(at, at + 0.1, t) * (1 - smooth(at + _dictStep, at + _dictStep + 0.15, t));
      if (on > 0) {
        final r = _thBoxes[k].shift(o).inflate(4);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = _amber.withValues(alpha: 0.22 * on));
      }
    }
    _th.paint(c, o);
    // The words' ends, found.
    for (var k = 0; k + 1 < thWords.length; k++) {
      final m = smooth(_dict + _dictStep * (k + 1) - 0.05, _dict + _dictStep * (k + 1) + 0.1, t);
      if (m <= 0) continue;
      final r0 = _thBoxes[k], r1 = _thBoxes[k + 1];
      final x = r1.top > r0.top + 4 ? r0.right + 6 : (r0.right + r1.left) / 2;
      _bar(c, o + Offset(x, r0.top + 10), r0.height - 20, _amber, m);
    }
    final n = smooth(_noSpaces, _noSpaces + 0.3, t) * (1 - smooth(_dict, _dict + 0.3, t));
    if (n > 0) {
      c.saveLayer(Rect.fromLTWH(o.dx, 700, 420, 60), Paint()..color = Color.fromRGBO(255, 255, 255, n));
      _put(c, _tp('no spaces', 'no spaces: where are the words?', _mono(20, _dim)), Offset(o.dx, 730), left: true);
      c.restore();
    }
    c.restore();
  }

  /// Japanese: a break almost anywhere; a naive one leaves 。 starting a
  /// line, kinsoku takes ん down with it (Flutter's own breaks).
  void _japanese(Canvas c, double t) {
    final k0 = smooth(_japan, _japan + 0.4, t);
    if (k0 <= 0) return;
    final o = Offset(_x0[2], _top);
    final lineH = _ja.preferredLineHeight;
    c.saveLayer(Rect.fromLTWH(o.dx - 20, o.dy - 20, 500, 640), Paint()..color = Color.fromRGBO(255, 255, 255, k0));
    final n = ja.length;
    final reflow = eio(seg(t, _reflow, _reflow + 0.7));
    // Each character: in the naive lines (seven to a line), then where
    // Flutter puts it.
    final places = <Rect>[];
    for (var i = 0; i < n; i++) {
      final real = _jaBoxes[i];
      final naive = Rect.fromLTWH(jaStyle.fontSize! * (i % 7), lineH * (i ~/ 7), real.width, real.height);
      final r = Rect.lerp(naive, real, reflow)!;
      places.add(r);
      final bad = i == 7 && t >= _catch && reflow < 1;
      final color = bad ? _red : (i == 6 || i == 7) && reflow > 0 && t < _kinsoku + 2 ? _amber : _ink;
      _put(c, _tp('ja $i ${color.toARGB32()}', ja[i], jaStyle.copyWith(color: color)), o + r.topLeft, left: true, top: true);
    }
    // Where it may break: between any two (not before 。, once kinsoku's
    // on).
    for (var i = 1; i < n; i++) {
      final m = smooth(_anywhere + 0.08 * i, _anywhere + 0.08 * i + 0.15, t);
      if (m <= 0) continue;
      final a = places[i - 1], b = places[i];
      if ((b.top - a.top).abs() > 4) continue;
      final closing = ja[i] == '。';
      final bad = closing && t >= _catch;
      _bar(c, o + Offset((a.right + b.left) / 2, a.top + 10), a.height - 20, bad ? _red : _amber, bad ? 1 : m * (closing ? 0.5 : 1));
    }
    // The catch: 。 starting a line, ✕.
    final x = smooth(_catch, _catch + 0.2, t) * (1 - smooth(_reflow, _reflow + 0.3, t));
    if (x > 0) {
      final r = places[7].shift(o);
      final p = Paint()
        ..color = _red.withValues(alpha: x)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final cx = r.left - 24, cy = r.center.dy;
      c.drawLine(Offset(cx - 12, cy - 12), Offset(cx + 12, cy + 12), p);
      c.drawLine(Offset(cx + 12, cy - 12), Offset(cx - 12, cy + 12), p);
    }
    c.restore();
  }

  /// A break mark: a short upright bar at [at], [len] long.
  static void _bar(Canvas c, Offset at, double len, Color color, double k) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - 2.5, at.dy, 5, len), const Radius.circular(2.5)),
      Paint()..color = color.withValues(alpha: k),
    );
  }

  /// [tp] at [at]: its middle (its left, [left]; its top, [top]).
  static void _put(Canvas c, TextPainter tp, Offset at, {bool left = false, bool top = false}) =>
      tp.paint(c, at - Offset(left ? 0 : tp.width / 2, top ? 0 : tp.height / 2));

  @override
  bool shouldRepaint(_Board old) => old.u != u;
}
