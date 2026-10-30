import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'figure.dart';
import 'kit.dart';
import 'motion.dart';
import 'shot.dart';
import 'vignette.dart';

/// 分割 · Itemize, up the right-hand side street (where a block was): a
/// works whose open ground floor cuts text into runs before it's shaped,
/// as Flutter's engine does (SkParagraph, with ICU), a press a part:
///
/// * in (0–4 s): the paragraph's whole text comes in on the belt at once,
///   a block a character, in the order a string stores them (all of it
///   left to right: mixing directions is the bidi stop's, later);
/// * read (4–10 s): a scanner gives each character its Unicode script
///   (Latin; Hiragana and Han, one language but two scripts; spaces and 👋
///   are Common, they've none of their own) and marks a cut wherever the
///   script changes, or the font must (👋: the emoji font); then the
///   spaces take their run's colour, staying with it;
/// * out (10–17.5 s): blades come down on the marks, the runs part, each
///   gets its tag (its script, its direction, the font it'll be shaped
///   with), and they go on, one by one, to shaping.
class ItemizeWorks extends Vignette {
  ItemizeWorks(super.kit);

  @override
  String get name => 'itemize';
  @override
  String get kick => 'ITEMIZE';
  @override
  String get line => 'One string, four runs';
  @override
  String get note => 'cut where the script changes: each run gets a direction and a font';

  @override
  double get loop => 19.0;
  @override
  double get visit => 17.5;

  /// Facing the plaza across the street.
  @override
  final frame = trs(vm.Vector3(28.4, 0, 29.2), rotY: math.pi / 2);

  /// Its building (the camera only looks in).
  @override
  late final volumes = [building(12, 9.6, 10.3)];

  /// The text, a block a character (in the order the string stores them),
  /// each one's Unicode script, and the run it ends up in (Common takes the
  /// run it's in).
  static const _chars = ['H', 'i', ' ', 'こ', 'ん', 'に', 'ち', 'は', '世', '界', ' ', '👋'];
  static const _scriptOf = ['Latin', 'Latin', 'Common', 'Hiragana', 'Hiragana', 'Hiragana', 'Hiragana', 'Hiragana', 'Han', 'Han', 'Common', 'Common'];
  static const _runOf = [0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 3];

  /// The runs: their script, font, colour (all left to right); why each
  /// ends where it does (the cut after it: こんにちは and 世界 share a font,
  /// not a script).
  static const _script = ['Latin', 'Hiragana', 'Han', 'Emoji'];
  static const _font = ['Space Grotesk', 'Noto Sans JP', 'Noto Sans JP', 'Noto Color Emoji'];
  static const _colors = [0x6C9BE0, 0x3FA37A, 0xE8505F, 0xF2B13A];
  static const _why = ['script · font', 'script', 'font: emoji'];

  /// A script's colour (Common: grey).
  static int _scriptColor(String s) => switch (s) {
    'Latin' => _colors[0],
    'Hiragana' => _colors[1],
    'Han' => _colors[2],
    _ => 0x9AA3B2,
  };

  /// The belt (its top, its depth line: well inside, so the camera can
  /// stand in the doorway, the street behind it), the blocks' height and
  /// depth, the gap the cuts open; a character's block width (the emoji's
  /// wider; a space's as wide as a letter's, so its script's tag fits over
  /// it without touching the next).
  static const _beltY = 1.0, _beltZ = 3.2, _h = 0.56, _d = 0.32, _gap = 0.36;
  static double _cw(int i) => _chars[i] == '👋' ? 0.5 : 0.4;
  static final _barW = [for (var i = 0; i < _chars.length; i++) _cw(i)].reduce((a, b) => a + b);

  /// Where character [i]'s middle is in the bar (from its middle).
  static double _cx(int i) {
    var x = -_barW / 2;
    for (var j = 0; j < i; j++) {
      x += _cw(j);
    }
    return x + _cw(i) / 2;
  }

  /// Run [k]'s first and last character; the joint after it (a cut there).
  static int _first(int k) => _runOf.indexOf(k);
  static int _last(int k) => _runOf.lastIndexOf(k);
  static double _joint(int k) => _cx(_last(k)) + _cw(_last(k)) / 2;

  /// The timeline, a press a part: in on the belt; the scan, each
  /// character's script, the cuts marked, the spaces taking their run's
  /// colour; the blades, the runs' tags, out.
  static const _in0 = 0.3, _in1 = 2.6, _scan0 = 4.3, _scan1 = 8.3, _join = 8.8;
  static const _cut0 = 10.3, _cutEvery = 0.6, _tag0 = 12.4, _out0 = 14.5, _outEvery = 0.45;
  static double _cutAt(int k) => _cut0 + _cutEvery * k;

  /// When the scanner's over character [i].
  static double _readAt(int i) => _scan0 + (_scan1 - _scan0) * (_cx(i) + _barW / 2) / _barW;

  static const _style = TextStyle(fontFamily: BP.display, fontSize: 160, fontWeight: FontWeight.w700);

  final _blocks = <Node>[], _charTags = <Node>[], _tags = <Node>[], _reasons = <Node>[];
  int _operator = -1;
  final _p = FigurePose();
  bool _ready = false;

  @override
  List<(String, TextStyle)> get fontRuns => [('Hi こんにちは世界 👋 ITEMIZE Latin Hiragana Han Emoji Common LTR script font', _style)];

  @override
  Future<void> init() async {
    makePool(boxes: 16, glows: 64, cyls: 4);
    final b = Batch();
    final m = pbr(rgb(1, 1, 1), roughness: 0.75);
    storefront(b, trim: 0xC8442F);
    b.buildInto(shell, 'itemize works', lightChannelMask: 0x01);
    // The belt on its legs, the scanner's rails, the blades' beam, the
    // controls, the way out to shaping.
    final dark = Vignette.c(0x2B2E33), steel = Vignette.c(0x8A8F98);
    box(b, m, 11.4, 0.12, 0.7, 0, _beltY - 0.06, _beltZ, Vignette.c(0x3A3F48));
    for (var x = -5.0; x <= 5.01; x += 2.5) {
      for (final dz in [-0.28, 0.28]) {
        box(b, m, 0.08, _beltY - 0.12, 0.08, x, (_beltY - 0.12) / 2, _beltZ + dz, dark);
      }
    }
    for (final dz in [-0.48, 0.48]) {
      box(b, m, 7.0, 0.06, 0.06, 0, 2.35, _beltZ + dz, steel);
    }
    box(b, m, 4.2, 0.18, 0.5, 0, 2.45, _beltZ, dark);
    box(b, m, 0.5, 1.1, 0.4, 4.6, 0.55, _beltZ + 1.0, Vignette.c(0x2E6DA8));
    box(b, m, 1.4, 2.2, 0.1, 5.6, 1.1, _beltZ, Vignette.c(0x14181F));
    b.buildInto(detail, 'itemize belt', lightChannelMask: 0x01);
    final ink = const Color(0xFF14203A);
    await Future.wait([
      sign(
        7.0,
        1.3,
        vm.Matrix4.translation(vm.Vector3(0, 6.2, -0.05)),
        (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1E2433));
          Vignette.text(c, 'ITEMIZE', Rect.fromLTWH(0, 0, s.width, s.height * 0.66), s.height * 0.5, const Color(0xFFF2C94C), lang: 'ja');
          Vignette.text(c, 'ONE STRING → FOUR RUNS', Rect.fromLTWH(0, s.height * 0.62, s.width, s.height * 0.32), s.height * 0.22, const Color(0xFFF4EBD8));
        },
        glow: 0.5,
        shell: true,
      ),
      sign(
        1.3,
        0.34,
        vm.Matrix4.translation(vm.Vector3(5.6, 2.4, _beltZ - 0.08)),
        (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E3546));
          Vignette.text(c, '→ SHAPING', Rect.fromLTWH(0, 0, s.width, s.height), s.height * 0.5, const Color(0xFFF4EBD8));
        },
        glow: 0.6,
        thick: 0.02,
      ),
      // The bar: a block a character, its character on the front.
      for (var i = 0; i < _chars.length; i++)
        sign(
          _cw(i),
          _h,
          vm.Matrix4.identity(),
          (c, s) {
            c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF4F1EA));
            if (_chars[i] == ' ') {
              // (A space: its mark, as an editor shows it.)
              Vignette.text(c, '␣', Rect.fromLTWH(0, s.height * 0.1, s.width, s.height * 0.8), s.height * 0.5, const Color(0xFF9AA3B2));
              return;
            }
            Vignette.text(
              c,
              _chars[i],
              Rect.fromLTWH(0, s.height * 0.08, s.width, s.height * 0.84),
              s.height * 0.6,
              ink,
              lang: _scriptOf[i] == 'Han' || _scriptOf[i] == 'Hiragana' ? 'ja' : null,
            );
          },
          px: (_cw(i) * 400).round(),
          glow: 0.15,
          thick: _d,
        ),
      // Each character's script, on a tag over it (as wide as its block,
      // short of the next one's).
      for (var i = 0; i < _chars.length; i++)
        sign(
          _cw(i) - 0.03,
          0.17,
          vm.Matrix4.identity(),
          (c, s) {
            c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF1E2433));
            c.drawRect(Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14), Paint()..color = Color(0xFF000000 | _scriptColor(_scriptOf[i])));
            Vignette.text(c, _scriptOf[i], Rect.fromLTWH(0, 0, s.width, s.height * 0.86), s.height * 0.46, const Color(0xFFF4EBD8), weight: FontWeight.w600);
          },
          px: ((_cw(i) - 0.03) * 520).round(),
          glow: 0.45,
          thick: 0.012,
        ),
      // The runs' tags: the script and direction, the font.
      for (var k = 0; k < 4; k++)
        sign(
          k == 1 ? 1.5 : 1.0,
          0.38,
          vm.Matrix4.identity(),
          (c, s) {
            c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF4EBD8));
            c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height * 0.12), Paint()..color = Color(0xFF000000 | _colors[k]));
            final dir = k == 3 ? '' : ' · LTR →';
            Vignette.text(c, '${_script[k]}$dir', Rect.fromLTWH(0, s.height * 0.14, s.width, s.height * 0.44), s.height * 0.3, ink);
            Vignette.text(
              c,
              _font[k],
              Rect.fromLTWH(0, s.height * 0.58, s.width, s.height * 0.36),
              s.height * 0.22,
              const Color(0xFF3A4558),
              weight: FontWeight.w600,
            );
          },
          px: k == 1 ? 600 : 400,
          glow: 0.3,
          thick: 0.015,
        ),
      // Why each cut is where it is.
      for (var k = 0; k < 3; k++)
        sign(
          0.74,
          0.16,
          vm.Matrix4.identity(),
          (c, s) {
            c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFC8442F));
            Vignette.text(c, '✂ ${_why[k]}', Rect.fromLTWH(0, 0, s.width, s.height), s.height * 0.52, const Color(0xFFFFFFFF), weight: FontWeight.w700);
          },
          px: 360,
          glow: 0.5,
          thick: 0.012,
        ),
    ]).then((nodes) {
      final n = _chars.length;
      _blocks.addAll(nodes.sublist(2, 2 + n));
      _charTags.addAll(nodes.sublist(2 + n, 2 + 2 * n));
      _tags.addAll(nodes.sublist(2 + 2 * n, 6 + 2 * n));
      _reasons.addAll(nodes.sublist(6 + 2 * n, 9 + 2 * n));
    });
    for (final n in [..._blocks, ..._charTags, ..._tags, ..._reasons]) {
      n.visible = false;
    }
    _operator = person(
      FigureLook()
        ..top = rgbHex(0xF2F0EA)
        ..layer = rgbHex(0xC8442F)
        ..legs = rgbHex(0x2B3442)
        ..shoes = rgbHex(0x1B1C20)
        ..skin = rgbHex(0xC59A7C)
        ..hairColor = rgbHex(0x1A1714)
        ..cap = rgbHex(0xC8442F),
    );
    _ready = true;
  }

  // ── Posing ────────────────────────────────────────────────────────────────

  /// Where the bar's middle is on the belt at [u] (coming in from the left).
  static double _barX(double u) => lerp(-8.0, 0, eio(seg(u, _in0, _in1)));

  /// How far the cuts have parted run [k] from the bar's middle (each cut
  /// left of it pushes it on a gap; the whole kept centred).
  static double _parted(int k, double u) {
    var x = 0.0;
    for (var i = 0; i < 3; i++) {
      final f = eio(seg(u, _cutAt(i) + 0.25, _cutAt(i) + 0.55));
      x += (i < k ? 1 : 0) * _gap * f - _gap * 1.5 * f / 3;
    }
    return x;
  }

  /// Run [k] going out to shaping (the last first): how far along.
  static double _outOf(int k, double u) => eio(seg(u, _out0 + _outEvery * (3 - k), _out0 + _outEvery * (3 - k) + 1.1));

  /// Run [k]'s middle in the bar (from its middle), before it's parted.
  static double _runMid(int k) => (_cx(_first(k)) - _cw(_first(k)) / 2 + _joint(k)) / 2;

  final _mm = vm.Matrix4.identity();

  void _place(Node n, double x, double y, double z, {double s = 1}) {
    _mm
      ..setIdentity()
      ..setTranslationRaw(x, y, z);
    if (s != 1) _mm.scaleByDouble(s, s, s, 1);
    n.localTransform = frame * _mm;
  }

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    pool.begin();
    final bar = _barX(u);
    final last = _chars.length - 1;
    final scanX = lerp(_cx(0) - 0.5, _cx(last) + 0.5, seg(u, _scan0, _scan1));
    final scanning = u > _scan0 - 0.2 && u < _scan1 + 0.2;
    // The runs' tags: dropped on once they're cut free (the characters'
    // tags gone by then).
    final tagsGo = 1 - smooth(_cut0 - 0.4, _cut0, u);
    for (var i = 0; i < _chars.length; i++) {
      final k = _runOf[i], out = _outOf(k, u);
      final x0 = _cx(i) + _parted(k, u), x = bar + x0 + out * (6.4 - (_runMid(k) + _parted(k, u)));
      final shown = u >= _in0 && out < 0.98;
      final n = _blocks[i]..visible = shown;
      if (shown) _place(n, x, _beltY + _h / 2, _beltZ);
      // Read: its script's tag over it, its colour on the belt in front of
      // it once the scan's been; a space (Common) turns to its run's colour.
      final read = smooth(_readAt(i) - 0.1, _readAt(i) + 0.15, u);
      final tag = _charTags[i]..visible = shown && read > 0.01 && tagsGo > 0.01;
      if (tag.visible) _place(tag, x, _beltY + _h + 0.16 + 0.25 * (1 - eo(read)), _beltZ - _d / 2 - 0.02, s: math.min(1.0, read) * tagsGo);
      if (shown && read > 0.01) {
        final own = Vignette.c(_scriptColor(_scriptOf[i])), run = Vignette.c(_colors[k]);
        final j = _scriptOf[i] == 'Common' ? smooth(_join, _join + 0.5, u) : 0.0;
        final c = own + (run - own) * j, g = 1.8 * read;
        pglow(x, _beltY + 0.012, _beltZ - _d / 2 - 0.06, _cw(i) - 0.05, 0.03, 0.06, vm.Vector4(c.x * g, c.y * g, c.z * g, 1));
      }
    }
    for (var k = 0; k < 4; k++) {
      final out = _outOf(k, u), shown = u >= _in0 && out < 0.98;
      final x = bar + _runMid(k) + _parted(k, u) + out * (6.4 - (_runMid(k) + _parted(k, u)));
      // Its direction, once it's a run: an arrow on the belt.
      final dirOn = smooth(_tag0 - 0.2, _tag0 + 0.3, u);
      if (shown && dirOn > 0.01 && k < 3) {
        final c = Vignette.c(_colors[k]), g = 1.8 * dirOn;
        const dir = 1.0;
        final ax = x + dir * 0.18, ay = _beltY + 0.012, az = _beltZ - _d / 2 - 0.2;
        final col = vm.Vector4(c.x * g, c.y * g, c.z * g, 1);
        pglow(ax - dir * 0.16, ay, az, 0.32, 0.02, 0.03, col);
        pglow(ax + dir * 0.02, ay, az + 0.04, 0.12, 0.02, 0.03, col, yaw: dir * 0.7);
        pglow(ax + dir * 0.02, ay, az - 0.04, 0.12, 0.02, 0.03, col, yaw: -dir * 0.7);
      }
      final tag = smooth(_tag0 + 0.3 * k, _tag0 + 0.3 * k + 0.45, u);
      final tn = _tags[k]..visible = shown && tag > 0;
      if (tn.visible) _place(tn, x, _beltY + _h + 0.3 + 1.2 * (1 - eo(tag)), _beltZ - 0.02);
    }
    // The cuts: marked where the scanner finds a change (a red line through
    // the joint, why on a tag over it); then a blade down each, in turn.
    var pull = 0.0;
    for (var i = 0; i < 3; i++) {
      final bx = bar + (_joint(i) + _parted(i, u) + _cx(_first(i + 1)) - _cw(_first(i + 1)) / 2 + _parted(i + 1, u)) / 2;
      final mark = smooth(_readAt(_first(i + 1)) - 0.1, _readAt(_first(i + 1)) + 0.2, u) * (1 - smooth(_cutAt(i) + 0.3, _cutAt(i) + 0.6, u));
      if (mark > 0.01) {
        pglow(bx, _beltY + _h / 2, _beltZ - _d / 2 - 0.03, 0.03, (_h + 0.3) * mark, 0.02, vm.Vector4(2.6, 0.4, 0.3, 1));
      }
      final reason = _reasons[i]..visible = mark > 0.01;
      if (reason.visible) _place(reason, bx, _beltY - 0.22, _beltZ - _d / 2 - 0.08, s: mark);
      final a = _cutAt(i), f = math.sin(math.pi * seg(u, a, a + 0.4));
      pull = math.max(pull, f);
      final y = lerp(2.2, _beltY + _h / 2 + 0.02, f), top = y + (_h + 0.1) / 2;
      pbox(bx, y, _beltZ, 0.02, _h + 0.1, _d + 0.16, Vignette.c(0xC9CED6));
      pbox(bx, (top + 2.45) / 2, _beltZ, 0.05, math.max(0.05, 2.45 - top), 0.05, Vignette.c(0x5A6470));
      if (f > 0.85) pglow(bx, _beltY + 0.1, _beltZ - _d / 2 - 0.02, 0.06, 0.06, 0.02, vm.Vector4(2.4, 2.0, 1.4, 1));
    }
    // The scanner: a frame over the belt riding its rails, its light.
    final sx = scanning ? scanX : (u < _scan0 ? _cx(0) - 0.5 : _cx(last) + 0.5);
    pbox(sx, 1.68, _beltZ - 0.48, 0.1, 1.36, 0.08, Vignette.c(0x3A4252));
    pbox(sx, 1.68, _beltZ + 0.48, 0.1, 1.36, 0.08, Vignette.c(0x3A4252));
    pbox(sx, 2.36, _beltZ, 0.16, 0.12, 1.06, Vignette.c(0x3A4252));
    if (scanning) pglow(sx, _beltY + _h + 0.06, _beltZ, 0.03, 0.02, 0.9, vm.Vector4(0.6, 1.6, 2.4, 1));
    // The operator at the controls: a hand on the lever, pulled for each
    // cut.
    final p = _p..rest();
    p.pos.setValues(4.6, 0.2, _beltZ + 1.6);
    p.yaw = 0.25;
    Idle.stand(p, t, Manner.of(210), look: 0.25, at: vm.Vector3(0, 1.4, _beltZ));
    worldPose(p);
    kit.crew.aim(p, 1, world(4.42, 1.14 - 0.1 * pull, _beltZ + 1.0));
    kit.figures.draw(_operator, p);
    pcyl(4.42, 1.14 - 0.1 * pull, _beltZ + 1.0, 0.025, 0.1, Vignette.c(0xC8442F));
    pbox(4.45, 1.08 - 0.05 * pull, _beltZ + 1.0, 0.03, 0.14, 0.03, Vignette.c(0x5A6470), roll: 0.3);
    pool.end();
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    // From high over the street (pulled back for the card, still above the
    // park's trees: the way in comes over them, not through them; the
    // flight lands there before this moves): the works, then down and in
    // at the doorway on the belt, the whole text on it (all of it clear of
    // the card); along with the runs as they go.
    final k = smooth(1.8, 4.0, u), out = smooth(_out0 - 0.3, _out0 + 1.5, u);
    return Shot(
      vm.Vector3(lerp(3.0, 0.1, k) + 1.4 * out, lerp(8.0, 2.4, k), lerp(-7.8, -1.4, k)),
      vm.Vector3(lerp(0.3, -0.1, k) + 1.8 * out, lerp(3.0, 1.45, k), lerp(1.0, _beltZ, k)),
      fov: lerp(52, 48, k),
      settle: 1.1,
      drift: 0.4,
    );
  }
}
