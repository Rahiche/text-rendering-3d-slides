import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:text_on_path/text_on_path.dart';
import 'package:text_slides/deck/theme.dart';

import 'strip.dart';

/// Package Town's fifth screen (v_package.dart): a word standing on an
/// elastic strip pinned at its ends ([Strip]: its points held their spacing
/// apart and bent stiffly, as a real band bends), Dash out in front of the
/// screen pulling a thread tied to its middle (hover_dash.dart: off down
/// one way, tugging, letting go to let it wobble back); set by text_on_path
/// itself, one example a press, the common case first ([_presses]): English,
/// each letter turned whole to the curve as other packages put text on a
/// path (`mode: rigid`: fine, nothing joins); English in cursive, its pins
/// squeezed in so it bows into a tight curve (its joins, short hairlines
/// near the baseline overlapping the next letter, hold on gentle bends but
/// split on one about an em round); Arabic, every word joined, back on the
/// gentle strip (the joins split all the same); then Arabic text_on_path's
/// own way, the letters rigid and only the rows they join on bent (the joins
/// stay shut however it bends), a rival Dash flying in to fight over the
/// strip. The presenter can take hold of it too (the mouse on the screen).
/// Package Town moves the strip ([strip]); this draws it as it is.
class PathBoard extends StatelessWidget {
  const PathBoard(this.strip, this.state, {super.key});

  final Strip strip;

  /// Which press it's on (0 … [fix]), and the seconds into the turn (the
  /// strip's clock).
  final ValueListenable<(int, double)> state;

  static const w = 1400.0, h = 960.0;

  /// The words: "joined", and Arabic's "connected" (four joins).
  static const english = 'joined', line = 'متصلة';

  /// The strip's rest: an arc of [_r] round a centre [_top] + [_r] down,
  /// [_spread] radians either side of its top (the Arabic word's em 2.2
  /// times over).
  static const _r = 484.0, _top = 400.0, _spread = 1.05;

  /// The presses: the word, as it's set (its font and size, px to the em:
  /// each word some 600 px long; right to left; text_on_path's way, else
  /// each letter turned whole), what the chip says, in what colour.
  static const _presses = [
    (english, TextStyle(fontFamily: BP.display, fontSize: 200, color: _ink), false, false, 'each letter turned whole: fine in English', _sky),
    (english, TextStyle(fontFamily: 'DancingScript', fontSize: 270, fontVariations: [FontVariation('wght', 700)], color: _ink), false, false, 'in cursive, on a tight curve: the joins split', _red),
    (line, TextStyle(fontFamily: BP.arabic, fontSize: 220, color: _ink), true, false, 'in Arabic, the joins split', _red),
    (line, TextStyle(fontFamily: BP.arabic, fontSize: 220, color: _ink), true, true, 'text_on_path: only the joins bend', _green),
  ];

  /// The press the strip's squeezed into a tight curve on (the cursive);
  /// the one text_on_path's own way is on (the rival Dash with it).
  static const tight = 1, fix = 3;

  /// Each press's word as it's set (to load its glyphs ahead).
  static List<(String, TextStyle)> get fontRuns => [for (final p in _presses) (p.$1, p.$2)];

  /// The strip, at rest.
  static Strip arch() => Strip.arc(const Offset(w / 2, _top + _r), _r, _spread);

  /// The threads' colours: Dash's a light sky blue, the rival's a coral
  /// (its headband's red, lighter).
  static const thread = Color(0xFF8FDBFF), rivalThread = Color(0xFFFF8A73);

  static const _ground = Color(0xFF0B1220), _band = Color(0xFF16263D), _ink = Color(0xFFF2F5FA);
  static const _red = Color(0xFFE8505F), _green = Color(0xFF34C77B), _sky = Color(0xFF6CB8FF);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<(int, double)>(
    valueListenable: state,
    builder: (context, state, _) {
      final (word, style, rtl, joined, chip, accent) = _presses[state.$1.clamp(0, fix)];
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: _ground)),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 110,
              child: ColoredBox(
                color: _band,
                child: Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TEXT ON A PATH',
                      style: TextStyle(fontFamily: BP.display, fontSize: 57, fontWeight: FontWeight.w800, color: BP.amber),
                    ),
                  ),
                ),
              ),
            ),
            // The strip under the word: its band, its points, its pins, the
            // thread's knot.
            Positioned.fill(child: CustomPaint(painter: _StripPainter(strip))),
            // (Drawn from its outlines, sharp at any size; the atlas it finds
            // the joins in kept small, as text_on_path 0.1.0 needs.)
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(devicePixelRatio: 1),
                child: TextOnPath(
                  word,
                  curve: PathCurve.fromPath(strip.path),
                  style: style,
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  mode: joined ? TextOnPathMode.joined : TextOnPathMode.rigid,
                  rendering: TextOnPathRendering.vector,
                  oversample: 1,
                ),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 70, child: Center(child: _chip(chip, accent))),
          ],
        ),
      );
    },
  );

  static Widget _chip(String text, Color accent) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.16),
      border: Border.all(color: accent.withValues(alpha: 0.7), width: 3),
      borderRadius: BorderRadius.circular(40),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
      child: Text(
        text,
        style: TextStyle(fontFamily: BP.display, fontSize: 40, fontWeight: FontWeight.w700, color: accent),
      ),
    ),
  );
}

/// The strip: a band a little under the curve the word stands on (its
/// joins clear of it), its points on it (the one in hand lit, the one the
/// thread's tied to knotted), a pin at each end.
class _StripPainter extends CustomPainter {
  _StripPainter(this.strip);

  final Strip strip;

  static const _wood = Color(0xFFB98A5A), _bead = Color(0xFFF1D9B5), _lit = Color(0xFFFFC24D);

  @override
  void paint(Canvas c, Size s) {
    final n = strip.points.length, held = strip.held, tied = strip.tied;
    final band = [for (var i = 0; i < n; i++) strip.band(i)];
    final line = Path()..moveTo(band.first.dx, band.first.dy);
    for (var i = 0; i + 1 < n; i++) {
      final a = band[math.max(i - 1, 0)], b = band[i], cc = band[i + 1], d = band[math.min(i + 2, n - 1)];
      final c1 = b + (cc - a) / 6, c2 = cc - (d - b) / 6;
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cc.dx, cc.dy);
    }
    c.drawPath(
      line,
      Paint()
        ..color = _wood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 1; i + 1 < n; i++) {
      if (i == held || i == tied) continue;
      c
        ..drawCircle(band[i], 8.5, Paint()..color = const Color(0xFF0B1220))
        ..drawCircle(band[i], 6.5, Paint()..color = _bead);
    }
    // The knot: the thread wound round its point (the rival's round it
    // too, once it's tied on).
    if (strip.rivalTied) {
      c
        ..drawCircle(band[tied], 17, Paint()..color = const Color(0xFF0B1220))
        ..drawCircle(band[tied], 14.5, Paint()..color = PathBoard.rivalThread);
    }
    c
      ..drawCircle(band[tied], 12, Paint()..color = const Color(0xFF0B1220))
      ..drawCircle(band[tied], 10, Paint()..color = PathBoard.thread)
      ..drawCircle(band[tied], 4.5, Paint()..color = _bead);
    if (held != null) {
      c
        ..drawCircle(band[held], 22, Paint()..color = _lit.withValues(alpha: 0.25))
        ..drawCircle(band[held], 12, Paint()..color = _lit);
    }
    // The pins (on rails while they're squeezed in, so it's seen they
    // slide).
    final rail = strip.rails;
    if (rail != null) {
      for (final (a, b) in rail) {
        c.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFF5A6470).withValues(alpha: 0.6)
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (final e in [band.first, band.last]) {
      c
        ..drawCircle(e, 22, Paint()..color = const Color(0xFF5A6470))
        ..drawCircle(e, 9, Paint()..color = const Color(0xFF2A2F38));
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => true;
}
