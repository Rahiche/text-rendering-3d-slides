import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:fountain_pen/fountain_pen.dart';
import 'package:text_slides/deck/theme.dart';

/// Package Town's fourth screen (v_package.dart): one word, animated as
/// handwriting three ways, all in Homemade Apple (the font fountain_pen's
/// bundled hand is traced from), so only the way differs:
///
/// * a wipe: the typeset word, uncovered from left to right;
/// * Tegaki's way: the font's own outline uncovered along its strokes (a
///   brush down each traced centre line, in writing order, the typeset
///   word seen through it), ending as the typeset word;
/// * fountain_pen: a pen writing the word out, nib, ink and hand.
///
/// Painted live (a LiveScreen) from [clock]: seconds into the first two
/// rows' writing, into the pen's, and how far the pen's row has grown in.
class PenBoard extends CustomPainter {
  PenBoard(this.clock) : super(repaint: clock);

  final ValueListenable<(double, double, double)> clock;

  static const w = 1400.0, h = 960.0;

  /// The word, how long each way takes to write it (s).
  static const word = 'FlutterKaigi', write = 5.5;

  static const _ground = Color(0xFF0B1220), _band = Color(0xFF16263D), _inkLabel = Color(0xFFF2F5FA);
  static const _paper = Color(0xFFF3EEE2), _ink = Color(0xFF1C2742);
  static const _red = Color(0xFFE8505F), _green = Color(0xFF34C77B);
  static const _pad = 56.0, _band0 = 110.0, _row0 = 140.0, _rowH = 250.0, _rowGap = 20.0, _paperX = 440.0;

  /// The rows: what writes it, what it does.
  static const _rows = [('wipe', 'uncovers the text', _red), ('Tegaki', 'uncovers the font', _red), ('fountain_pen', 'writes it', _green)];

  /// The word's size (px to the em): as large as fits a strip, typeset or
  /// written.
  static final double _em = () {
    const room = w - _paperX - _pad - 2 * 60;
    final typeset = _typeset(100).width / 100, written = PenWriting(word, fontSize: 100, duration: write, seed: 3).size.width / 100;
    return math.min(132.0, room / math.max(typeset, written));
  }();

  static final _pen = PenWriting(word, fontSize: _em, duration: write, seed: 3);
  static final _word = _typeset(_em);

  /// Tegaki's way, laid out once: each stroke of the hand's (in writing
  /// order, the late ones once the word's done) on the typeset word, its
  /// brush's width, and when it starts and ends.
  static final _strokes = _brushes();

  static TextPainter _typeset(double size) => TextPainter(
    text: TextSpan(
      text: word,
      style: TextStyle(fontFamily: 'HomemadeApple', fontSize: size, color: _ink, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static List<(List<Offset>, double, double, double)> _brushes() {
    final tp = _word;
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final now = <(List<Offset>, double)>[], late = <(List<Offset>, double)>[];
    for (var i = 0; i < word.length; i++) {
      final g = homemadeApple.glyphs[word[i]];
      if (g == null) continue;
      final box = tp.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1)).first;
      for (final s in g.strokes) {
        final pts = <Offset>[];
        var r = 0.0;
        for (var j = 0; j + 2 < s.points.length; j += 3) {
          pts.add(Offset(box.left + s.points[j] * _em, baseline - s.points[j + 1] * _em));
          r = math.max(r, s.points[j + 2]);
        }
        if (pts.isEmpty) continue;
        // (Wide enough to take in the outline round the centre line.)
        (s.late ? late : now).add((pts, math.max(2.6 * r, 0.07) * _em));
      }
    }
    final all = [...now, ...late];
    double len(List<Offset> p) {
      var l = 0.0;
      for (var k = 1; k < p.length; k++) {
        l += (p[k] - p[k - 1]).distance;
      }
      return l;
    }

    // (Each stroke's time by its length, a short lift between.)
    const lift = 0.05;
    final total = all.fold(0.0, (a, s) => a + len(s.$1) + 4);
    final per = (write - lift * all.length) / total;
    var t = 0.0;
    return [
      for (final (pts, width) in all)
        () {
          final t0 = t + lift, t1 = t0 + (len(pts) + 4) * per;
          t = t1;
          return (pts, width, t0, t1);
        }(),
    ];
  }

  @override
  void paint(Canvas c, Size s) {
    final (tau, penTau, grow) = clock.value;
    c.drawRect(Offset.zero & s, Paint()..color = _ground);
    c.drawRect(const Rect.fromLTWH(0, 0, w, _band0), Paint()..color = _band);
    _label(c, 'HANDWRITING', const Offset(_pad, _band0 / 2), _band0 * 0.52, BP.amber, weight: FontWeight.w800);
    for (final (k, (name, does, accent)) in _rows.indexed) {
      final top = _row0 + k * (_rowH + _rowGap);
      final strip = Rect.fromLTWH(_paperX, top, w - _paperX - _pad, _rowH);
      final pen = k == 2;
      if (pen && grow <= 0) continue;
      c.save();
      if (pen && grow < 1) {
        final m = Offset(w / 2, strip.center.dy);
        c
          ..translate(m.dx, m.dy)
          ..scale(grow)
          ..translate(-m.dx, -m.dy);
      }
      _label(c, name, Offset(_pad, top + 80), 50, _inkLabel, mono: true);
      _chip(c, does, Offset(_pad, top + 168), 31, accent);
      c.drawRRect(RRect.fromRectAndRadius(strip, const Radius.circular(18)), Paint()..color = _paper);
      switch (k) {
        case 0:
          _wipe(c, strip, tau);
        case 1:
          _reveal(c, strip, tau);
        default:
          _pen.paint(c, strip.center, penTau);
      }
      c.restore();
    }
  }

  /// Where the typeset word sits in [strip]: centred.
  static Offset _at(Rect strip) => strip.center - Offset(_word.width / 2, _word.height / 2);

  /// The typeset word, uncovered left to right by [tau], a soft edge.
  static void _wipe(Canvas c, Rect strip, double tau) {
    final at = _at(strip), k = (tau / write).clamp(0.0, 1.0);
    if (k <= 0) return;
    final word = at & _word.size;
    c.saveLayer(strip, Paint());
    _word.paint(c, at);
    final edge = word.left + (word.width + 60) * k;
    c.drawRect(
      strip,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(Offset(edge - 60, 0), Offset(edge, 0), const [Color(0xFF000000), Color(0x00000000)]),
    );
    c.restore();
  }

  /// The typeset word seen through a brush laid down its strokes, in
  /// order, by [tau]; once all are down, the word itself.
  static void _reveal(Canvas c, Rect strip, double tau) {
    final at = _at(strip);
    if (tau >= write) {
      _word.paint(c, at);
      return;
    }
    c.saveLayer(strip, Paint());
    final brush = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (pts, width, t0, t1) in _strokes) {
      if (tau <= t0) break;
      final k = ((tau - t0) / (t1 - t0)).clamp(0.0, 1.0);
      final path = Path()..moveTo(at.dx + pts.first.dx, at.dy + pts.first.dy);
      if (pts.length == 1) {
        c.drawCircle(at + pts.first, width / 2, Paint()..color = const Color(0xFF000000));
        continue;
      }
      // (As far along it as the brush has got.)
      var total = 0.0;
      for (var j = 1; j < pts.length; j++) {
        total += (pts[j] - pts[j - 1]).distance;
      }
      var left = total * k;
      for (var j = 1; j < pts.length && left > 0; j++) {
        final d = (pts[j] - pts[j - 1]).distance;
        final p = d <= left ? pts[j] : Offset.lerp(pts[j - 1], pts[j], left / d)!;
        path.lineTo(at.dx + p.dx, at.dy + p.dy);
        left -= d;
      }
      c.drawPath(path, brush..strokeWidth = width);
    }
    c.saveLayer(strip, Paint()..blendMode = BlendMode.srcIn);
    _word.paint(c, at);
    c
      ..restore()
      ..restore();
  }

  static void _label(Canvas c, String text, Offset at, double size, Color color, {bool mono = false, FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: mono ? BP.mono : BP.display, fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx, at.dy - tp.height / 2));
    tp.dispose();
  }

  /// A rounded chip with [text] in [accent], its left middle at [at].
  static void _chip(Canvas c, String text, Offset at, double size, Color accent) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: BP.display, fontSize: size, color: accent, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromLTWH(at.dx, at.dy - tp.height / 2 - size * 0.22, tp.width + size * 0.9, tp.height + size * 0.44);
    c
      ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), Paint()..color = accent.withValues(alpha: 0.16))
      ..drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)),
        Paint()
          ..color = accent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    tp.paint(c, Offset(at.dx + size * 0.45, at.dy - tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(PenBoard old) => old.clock != clock;
}
