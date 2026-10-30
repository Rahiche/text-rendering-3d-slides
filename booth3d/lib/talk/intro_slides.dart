import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:fountain_pen/fountain_pen.dart';

import 'title_slide.dart';

/// The talk's opening, before the city: the presenter's slides, as plain as
/// slides come (title_slide.dart's look: white, Arial, a presentation app's
/// default layout, a number in the corner). Writing was done by hand for
/// nearly all of its history, on walls, trees and paper, with centuries of
/// rules nobody wrote down; then came computers, and the problem is bringing
/// all of that from the physical world into the digital one. Each slide's
/// sketches draw themselves in as it comes up, in a fountain pen's
/// blue-black (fountain_pen writes their words). The last one is on the
/// laptop the next press pulls back from: this can't be told in 2D.
abstract final class IntroSlides {
  /// How many there are, the title the first.
  static const count = 6;

  /// Paints page [page] into [size] (16:9), [t] seconds after it came up:
  /// its sketches as far as they've been drawn (all of them by [drawn]).
  static void paint(Canvas c, Size size, int page, double t) {
    if (page <= 0) {
      TitleSlide.paint(c, size);
      return;
    }
    final p = _pages[page - 1];
    c
      ..save()
      ..scale(size.height / 900)
      ..drawRect(const Rect.fromLTWH(0, 0, 1600, 900), Paint()..color = const Color(0xFFFFFFFF));
    p.title.paint(c, const Offset(110, 64));
    p.number.paint(c, Offset(1490 - p.number.width, 842));
    for (final m in p.marks) {
      if (t > m.at) m.paint(c, t - m.at);
    }
    c.restore();
  }

  /// When page [page]'s sketches are all drawn (s after it came up).
  static double drawn(int page) => page <= 0 ? 0 : _pages[page - 1].end;

  static final _pages = [_notFlutter(), _physical(), _rules(), _computers(), _problem()];
}

/// fountain_pen's blue-black, and a spell checker's red.
const _ink = Color(0xFF16204A), _red = Color(0xFFD93025);

/// Not a Flutter problem: the platforms named, a spell checker's squiggle
/// under each as it's named; then, by hand, the same problems everywhere.
_Page _notFlutter() {
  final pen = _Pen()..clock = 0.8;
  const names = ['Flutter', 'Android', 'iOS', 'Chrome'], gap = 110.0, top = 392.0;
  final typed = [for (final n in names) _typed(n, 64)];
  final width = typed.fold(0.0, (w, t) => w + t.width) + gap * (names.length - 1);
  final under = top + typed.first.computeDistanceToActualBaseline(TextBaseline.alphabetic) + 13;
  var x = 800 - width / 2;
  for (final t in typed) {
    pen.marks.add(_Typed(0, t, Offset(x, top)));
    pen.line(_wave(Offset(x, under), Offset(x + t.width, under), 4, 14), color: _red, width: 2.6, waver: 0, speed: 650);
    pen.clock += 0.3;
    x += t.width + gap;
  }
  pen.clock += 0.3;
  pen.write('the same problems, everywhere', const Offset(800, 640), size: 60, duration: 1.8);
  return _Page('Not a Flutter problem', 2, pen);
}

/// Writing was always physical: on a wall (a hand on it, a count kept), on
/// a tree (a heart carved in it), on paper (with a quill).
_Page _physical() {
  final pen = _Pen();
  // The wall.
  pen.line(
    _through(const [
      Offset(190, 282), Offset(262, 262), Offset(352, 272), Offset(440, 258), Offset(478, 302), Offset(470, 392), Offset(486, 470), //
      Offset(452, 536), Offset(362, 546), Offset(270, 538), Offset(196, 520), Offset(176, 440), Offset(186, 360),
    ], closed: true),
    waver: 1.6,
    speed: 2400,
  );
  pen.line(_through([for (final p in _hand) p + const Offset(290, 414)]), speed: 1800);
  for (var i = 0; i < 4; i++) {
    pen.line(_straight(Offset(388 + 15.0 * i, 376), Offset(384 + 15.0 * i, 446)), speed: 1200);
  }
  pen.line(_straight(const Offset(374, 432), const Offset(450, 388)), speed: 1200);
  pen.write('on a wall', const Offset(330, 630), size: 46, duration: 0.8);
  // The tree.
  pen.line(_cloud(const Offset(800, 322), 128, 96), waver: 1.2, speed: 2400);
  pen.line(_through(const [Offset(783, 414), Offset(780, 480), Offset(771, 560), Offset(752, 570)]), speed: 1600);
  pen.line(_through(const [Offset(818, 414), Offset(821, 480), Offset(830, 560), Offset(850, 569)]), speed: 1600);
  pen.line(_straight(const Offset(690, 574), const Offset(910, 574), bow: 2), speed: 2000);
  pen.line(_heart(const Offset(801, 486), 24), waver: 0.3, speed: 600);
  pen.write('on a tree', const Offset(800, 630), size: 46, duration: 0.8);
  // The paper, written on, and a quill.
  const c = Offset(1250, 400);
  Offset on(Offset p) => _turn(c + p, c, -0.1);
  pen.box([on(const Offset(-115, -145)), on(const Offset(115, -145)), on(const Offset(115, 145)), on(const Offset(-115, 145))]);
  for (var i = 0; i < 6; i++) {
    final y = -105.0 + 40 * i;
    pen.line([for (final p in _wave(Offset(-88, y), Offset(i == 5 ? 10 : 88, y), 5.5, 17)) on(p)], width: 2.6, waver: 0.6, speed: 2600);
  }
  const a = Offset(1316, 550), b = Offset(1430, 290);
  final along = b - a, n = Offset(-along.dy, along.dx) / along.distance;
  pen.line(_straight(a - along / along.distance * 14, b), speed: 1500);
  for (final side in [1.0, -1.0]) {
    pen.line([
      for (var i = 0; i <= 30; i++) a + along * (0.3 + 0.7 * i / 30) + n * (side * 24 * math.pow(math.sin(math.pi * i / 30), 0.7).toDouble()),
    ], speed: 1500);
  }
  for (final s in [0.48, 0.62, 0.76]) {
    final p = a + along * s;
    pen.line(_straight(p, p + n * 18 - along / along.distance * 10), waver: 0, speed: 900);
  }
  pen.write('on paper', const Offset(1250, 630), size: 46, duration: 0.8);
  return _Page('Writing was always physical', 3, pen);
}

/// Centuries of rules nobody wrote down: a page of handwriting, a few of
/// its rules pointed out, and many more.
_Page _rules() {
  final pen = _Pen();
  pen.box(const [Offset(190, 205), Offset(590, 205), Offset(590, 760), Offset(190, 760)], speed: 2500);
  // Its lines, word by word, scribbled in quickly: a wide space on the
  // second, the fifth running to the margin, the eighth's last word joined
  // up.
  const words = [
    [(228.0, 300.0), (318.0, 412.0), (430.0, 520.0)],
    [(228.0, 286.0), (304.0, 362.0), (380.0, 452.0), (500.0, 552.0)],
    [(228.0, 330.0), (348.0, 420.0), (438.0, 552.0)],
    [(228.0, 270.0), (288.0, 396.0), (414.0, 488.0)],
    [(228.0, 318.0), (336.0, 400.0), (418.0, 552.0)],
    [(228.0, 290.0), (308.0, 410.0), (428.0, 500.0)],
    [(228.0, 350.0), (368.0, 430.0), (448.0, 552.0)],
    [(228.0, 300.0), (318.0, 372.0), (390.0, 430.0), (448.0, 552.0)],
    [(228.0, 320.0), (338.0, 440.0), (458.0, 530.0)],
    [(228.0, 280.0), (298.0, 380.0)],
  ];
  for (final (i, line) in words.indexed) {
    final y = 262.0 + 50 * i;
    for (final (x0, x1) in line) {
      final joined = i == 7 && x0 >= 440;
      pen.line(joined ? _loops(Offset(x0, y + 6), Offset(x1, y + 6), 22) : _wave(Offset(x0, y), Offset(x1, y), 5, 12), width: 2.3, waver: 0.5, speed: 6000, lift: 0);
    }
  }
  pen.clock += 0.3;
  for (final (text, y, to) in const [
    ('a space between words', 300.0, Offset(476, 300)),
    ("don't break a word here", 452.0, Offset(564, 456)),
    ('join the letters', 604.0, Offset(562, 600)),
  ]) {
    final w = pen.write(text, Offset(1030, y), size: 44, duration: 0.9);
    pen.arrow(Offset(1030 + w.writing.bounds.left - 22, y + 4), to, bow: -16);
  }
  pen.write('...and many more', const Offset(1030, 740), size: 44, duration: 0.8);
  return _Page('Centuries of unwritten rules', 4, pen);
}

/// Then, computers: a line for writing's whole history, by hand, and at its
/// very end the sliver that's been computers', one drawn over it.
_Page _computers() {
  final pen = _Pen();
  const y = 520.0, x0 = 150.0, x1 = 1450.0;
  pen.line(_straight(const Offset(x0, y), const Offset(x1, y), bow: 3), width: 3.6, waver: 1.2, speed: 1400);
  pen.line(_straight(const Offset(x0, y - 18), const Offset(x0, y + 18)), waver: 0, speed: 600);
  pen.write('the first writing', const Offset(x0 + 130, y - 60), size: 42, duration: 0.9);
  pen.write('five thousand years, by hand', const Offset(640, y + 72), size: 54, duration: 1.5);
  // A computer, at the very end.
  pen.box(const [Offset(1318, 262), Offset(1462, 262), Offset(1462, 372), Offset(1318, 372)]);
  pen.box(const [Offset(1334, 278), Offset(1446, 278), Offset(1446, 356), Offset(1334, 356)], over: 3, width: 2.4);
  pen.line(_straight(const Offset(1372, 372), const Offset(1366, 392)), waver: 0, speed: 600);
  pen.line(_straight(const Offset(1408, 372), const Offset(1414, 392)), waver: 0, speed: 600);
  pen.line(_straight(const Offset(1340, 394), const Offset(1440, 394)), speed: 900);
  pen.box(const [Offset(1330, 410), Offset(1450, 410), Offset(1464, 438), Offset(1316, 438)], over: 4);
  pen.line(_straight(const Offset(1338, 424), const Offset(1442, 424)), width: 2, waver: 0.4, speed: 900);
  // Its sliver: about 60 of the 5,200 years.
  const sliver = 60 / 5200 * (x1 - x0);
  pen.line(_straight(const Offset(x1 - sliver, y), const Offset(x1, y)), color: _red, width: 8, waver: 0, speed: 60);
  pen.arrow(const Offset(1430, 452), const Offset(x1 - sliver / 2, y - 14), bow: -6);
  pen.write('sixty years', const Offset(x1 - 50, y + 66), size: 42, duration: 0.8);
  return _Page('Then, computers', 5, pen);
}

/// The problem: a word written on paper by hand (fountain_pen writes it),
/// the same word as a screen has it, in pixels, and between them the way
/// across.
_Page _problem() {
  final pen = _Pen();
  const c = Offset(370, 430);
  Offset on(Offset p) => _turn(c + p, c, -0.06);
  pen.box([on(const Offset(-165, -120)), on(const Offset(165, -120)), on(const Offset(165, 120)), on(const Offset(-165, 120))]);
  pen.write('Hello', c, size: 96, duration: 1.4, maxWidth: 270);
  pen.write('physical', const Offset(370, 640), size: 46, duration: 0.8);
  pen.arrow(const Offset(590, 432), const Offset(1010, 432), bow: 18, head: 22);
  pen.write('?', const Offset(800, 350), size: 96, duration: 0.5);
  // A screen, its word lit at once.
  pen.box(const [Offset(1062, 290), Offset(1418, 290), Offset(1418, 545), Offset(1062, 545)]);
  pen.box(const [Offset(1084, 310), Offset(1396, 310), Offset(1396, 525), Offset(1084, 525)], over: 4, width: 2.4);
  pen.line(_straight(const Offset(1226, 545), const Offset(1220, 578)), waver: 0, speed: 600);
  pen.line(_straight(const Offset(1254, 545), const Offset(1260, 578)), waver: 0, speed: 600);
  pen.line(_straight(const Offset(1176, 580), const Offset(1304, 580)), speed: 900);
  pen.pixels('Hello', const Offset(1240, 418), 9);
  pen.write('digital', const Offset(1240, 640), size: 46, duration: 0.8);
  return _Page('From physical to digital', 6, pen);
}

/// A slide: its title and number (typed), its marks in the order they're
/// drawn, and when the last is done.
class _Page {
  _Page(String title, int number, _Pen pen)
    : title = _typed(title, 72),
      number = _typed('$number', 24, color: const Color(0xFF8C8C8C)),
      marks = pen.marks,
      end = pen.clock;

  final TextPainter title, number;
  final List<_Mark> marks;
  final double end;
}

/// [text] in the slides' Arial, [size] px.
TextPainter _typed(String text, double size, {Color color = const Color(0xFF000000)}) =>
    TextPainter(text: TextSpan(text: text, style: TitleSlide.style(size, color)), textDirection: TextDirection.ltr)..layout();

/// Draws a page a mark after another, keeping its time: lines at a hand's
/// pace, the pen lifted a moment between; words as fountain_pen writes
/// them.
class _Pen {
  final marks = <_Mark>[];

  /// When the next mark starts (s after the page comes up).
  double clock = 0.4;
  var _seed = 1;

  /// A line along [points], wavering up to [waver] px as a hand does, drawn
  /// at [speed] px a second, the pen lifted [lift] s after it.
  void line(List<Offset> points, {double width = 3.2, Color color = _ink, double waver = 1, double speed = 1500, double lift = 0.05}) {
    final p = _wavering(_even(points), _seed++, waver), length = _length(p) / speed;
    marks.add(_Line(clock, length, p, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round));
    clock += length + lift;
  }

  /// A four-sided shape through [corners], a side at a time, each run on
  /// [over] px past its corners and a little bowed, as sketched.
  void box(List<Offset> corners, {double over = 6, double width = 3.2, double speed = 1500}) {
    for (var i = 0; i < 4; i++) {
      line(_straight(corners[i], corners[(i + 1) % 4], over: over, bow: i.isEven ? 2 : -2), width: width, speed: speed);
    }
  }

  /// An arrow from [a] to [b], its shaft bowed [bow] px: the shaft, then its
  /// head in one stroke.
  void arrow(Offset a, Offset b, {double bow = 0, double head = 16}) {
    final shaft = _straight(a, b, bow: bow);
    line(shaft, speed: 1800);
    final d = shaft.last - shaft[shaft.length - 3], back = -d / d.distance;
    Offset turned(double r) => Offset(back.dx * math.cos(r) - back.dy * math.sin(r), back.dx * math.sin(r) + back.dy * math.cos(r));
    line([b + turned(0.45) * head, b, b + turned(-0.45) * head], waver: 0, speed: 900);
  }

  /// [text] written by hand, [size] px to the em (or narrower: [maxWidth]),
  /// centred on [centre], taking [duration] s.
  _Words write(String text, Offset centre, {double size = 44, double duration = 1, double? maxWidth}) {
    final w = _Words(clock, PenWriting(text, fontSize: size, duration: duration, maxWidth: maxWidth, seed: _seed++), centre);
    marks.add(w);
    clock += w.writing.duration + 0.12;
    return w;
  }

  /// [text] in a screen's 5×7 pixel font, its middle at [centre], [cell] px
  /// a pixel: lit a row at a time, all at once.
  void pixels(String text, Offset centre, double cell) {
    final cols = text.length * 6 - 1;
    final left = centre.dx - cols * cell / 2, top = centre.dy - 7 * cell / 2;
    final rows = <List<Rect>>[
      for (var r = 0; r < 7; r++)
        [
          for (final (i, ch) in text.split('').indexed)
            for (var col = 0; col < 5; col++)
              if (_pixelFont[ch]![r][col] == '1') Rect.fromLTWH(left + (i * 6 + col) * cell, top + r * cell, cell - 1.5, cell - 1.5),
        ],
    ];
    marks.add(_Pixels(clock, rows));
    clock += 0.3;
  }
}

/// Something on a page, drawn in from [at] s after the page came up.
abstract class _Mark {
  _Mark(this.at);
  final double at;

  /// Paints it as drawn by [t] s after it began.
  void paint(Canvas c, double t);
}

/// A pen line along [points] (evenly spaced), drawn along over [length] s.
class _Line extends _Mark {
  _Line(super.at, this.length, this.points, this.pen);
  final double length;
  final List<Offset> points;
  final Paint pen;

  @override
  void paint(Canvas c, double t) {
    final u = math.min(1.0, t / length) * (points.length - 1), n = u.floor();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i <= n; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (n < points.length - 1) {
      final p = Offset.lerp(points[n], points[n + 1], u - n)!;
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, pen);
  }
}

/// Words written by hand, centred on [centre].
class _Words extends _Mark {
  _Words(super.at, this.writing, this.centre);
  final PenWriting writing;
  final Offset centre;

  @override
  void paint(Canvas c, double t) => writing.paint(c, centre, t);
}

/// Typed text, there from the start (as a slide's text is).
class _Typed extends _Mark {
  _Typed(super.at, this.text, this.topLeft);
  final TextPainter text;
  final Offset topLeft;

  @override
  void paint(Canvas c, double t) => text.paint(c, topLeft);
}

/// A screen's pixels, lit a row at a time in a moment.
class _Pixels extends _Mark {
  _Pixels(super.at, this.rows);
  final List<List<Rect>> rows;
  static final _lit = Paint()..color = _ink;

  @override
  void paint(Canvas c, double t) {
    for (var r = 0; r < (t >= rows.length * 0.03 ? rows.length : (t / 0.03).floor() + 1); r++) {
      for (final cell in rows[r]) {
        c.drawRect(cell, _lit);
      }
    }
  }
}

/// A hand, its fingers up (as stencilled on a cave's wall), round its palm.
const _hand = [
  Offset(-30, 75), Offset(-36, 35), Offset(-48, 12), Offset(-66, -8), Offset(-70, -22), Offset(-58, -24), Offset(-40, -6), //
  Offset(-36, -40), Offset(-36, -72), Offset(-28, -82), Offset(-19, -72), Offset(-17, -42), //
  Offset(-12, -50), Offset(-10, -88), Offset(-1, -97), Offset(8, -88), Offset(8, -46), //
  Offset(13, -48), Offset(16, -82), Offset(24, -90), Offset(32, -82), Offset(30, -40), //
  Offset(35, -34), Offset(41, -60), Offset(48, -66), Offset(55, -58), Offset(48, -18), Offset(44, 20), Offset(34, 75),
];

/// A screen's letters, 5×7 pixels each.
const _pixelFont = {
  'H': ['1...1', '1...1', '1...1', '11111', '1...1', '1...1', '1...1'],
  'e': ['.....', '.....', '.111.', '1...1', '11111', '1....', '.111.'],
  'l': ['.11..', '..1..', '..1..', '..1..', '..1..', '..1..', '...11'],
  'o': ['.....', '.....', '.111.', '1...1', '1...1', '1...1', '.111.'],
};

/// A straight line from [a] to [b], run on [over] px past both ends and
/// bowed [bow] px (left of its way).
List<Offset> _straight(Offset a, Offset b, {double over = 0, double bow = 0}) {
  final d = b - a, u = d / d.distance, n = Offset(u.dy, -u.dx);
  final a0 = a - u * over, b0 = b + u * over;
  return [
    for (var i = 0; i <= 24; i++) Offset.lerp(a0, b0, i / 24)! + n * (bow * 4 * (i / 24) * (1 - i / 24)),
  ];
}

/// A smooth curve through [p] (Catmull-Rom); [closed], round to its start
/// and a little past, where a hand closing a shape overshoots.
List<Offset> _through(List<Offset> p, {bool closed = false}) {
  final n = p.length;
  Offset at(int i) => closed ? p[i % n] : p[i.clamp(0, n - 1)];
  final out = <Offset>[];
  final segments = closed ? n + 1 : n - 1;
  for (var i = 0; i < segments; i++) {
    final p0 = at(closed ? i - 1 + n : i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    for (var j = 0; j < (closed && i == n ? 5 : 12); j++) {
      final t = j / 12, t2 = t * t, t3 = t2 * t;
      out.add((p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5);
    }
  }
  if (!closed) out.add(p.last);
  return out;
}

/// A wave from [a] to [b], [amp] px either side, a crest every [every] px.
List<Offset> _wave(Offset a, Offset b, double amp, double every) {
  final d = b - a, length = d.distance, u = d / length, n = Offset(-u.dy, u.dx);
  final steps = math.max(2, (length / 2).ceil());
  return [
    for (var i = 0; i <= steps; i++) a + u * (length * i / steps) + n * (amp * math.sin(length * i / steps / every * 2 * math.pi)),
  ];
}

/// Joined-up loops from [a] to [b] (level), [h] px high: a cursive word, its
/// letters joined.
List<Offset> _loops(Offset a, Offset b, double h) {
  final length = (b - a).distance, k = math.max(1, (length / 22).round()), steps = k * 24;
  return [
    for (var i = 0; i <= steps; i++) a + Offset(length * i / steps - 7 * math.sin(i / steps * k * 2 * math.pi), -h * (1 - math.cos(i / steps * k * 2 * math.pi)) / 2),
  ];
}

/// A tree's crown round [c] ([rx] by [ry]): a cloud of bumps, round once
/// and a little past.
List<Offset> _cloud(Offset c, double rx, double ry) => [
  for (var i = 0; i <= 160; i++)
    () {
      final a = -2.4 + i / 160 * (2 * math.pi + 0.3), r = 1 + 0.13 * math.sin(a * 4.5).abs();
      return c + Offset(math.cos(a) * rx * r, math.sin(a) * ry * r);
    }(),
];

/// A heart [size] px across, round [c].
List<Offset> _heart(Offset c, double size) => [
  for (var i = 0; i <= 90; i++)
    () {
      final t = i / 90 * 2 * math.pi, s = math.sin(t);
      return c + Offset(16 * s * s * s, -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))) * (size / 32);
    }(),
];

/// [p] turned [angle] radians round [c].
Offset _turn(Offset p, Offset c, double angle) {
  final d = p - c;
  return c + Offset(d.dx * math.cos(angle) - d.dy * math.sin(angle), d.dx * math.sin(angle) + d.dy * math.cos(angle));
}

/// [p] again, a point every [step] px along it.
List<Offset> _even(List<Offset> p, [double step = 3]) {
  if (p.length < 2) return p;
  final out = [p.first];
  var left = step;
  for (var i = 1; i < p.length; i++) {
    var a = p[i - 1];
    final b = p[i];
    var d = (b - a).distance;
    while (d >= left) {
      a = Offset.lerp(a, b, left / d)!;
      out.add(a);
      d -= left;
      left = step;
    }
    left -= d;
  }
  if ((out.last - p.last).distance > 0.01) out.add(p.last);
  return out;
}

double _length(List<Offset> p) {
  var s = 0.0;
  for (var i = 1; i < p.length; i++) {
    s += (p[i] - p[i - 1]).distance;
  }
  return s;
}

/// [p] wavering off its course by up to [px] either side, slowly, as a hand
/// does (the same each time for [seed]).
List<Offset> _wavering(List<Offset> p, int seed, double px) {
  if (px == 0 || p.length < 3) return p;
  final r = math.Random(seed);
  final waves = [for (var i = 0; i < 3; i++) (every: 60 + 140 * r.nextDouble(), phase: r.nextDouble() * 2 * math.pi, size: 0.4 + 0.6 * r.nextDouble())];
  final out = <Offset>[];
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    if (i > 0) s += (p[i] - p[i - 1]).distance;
    final d = p[math.min(i + 1, p.length - 1)] - p[math.max(i - 1, 0)];
    final n = d.distance == 0 ? Offset.zero : Offset(-d.dy, d.dx) / d.distance;
    var o = 0.0;
    for (final w in waves) {
      o += w.size * math.sin(s / w.every * 2 * math.pi + w.phase);
    }
    out.add(p[i] + n * (o / 1.6 * px));
  }
  return out;
}
