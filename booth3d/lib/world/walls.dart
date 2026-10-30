import 'dart:math' as math;

import 'package:flutter/painting.dart';

// Two storeys of a house's wall in different countries' ways, painted
// into a rectangle of a canvas (the outskirts' houses, ICU City's fronts).

/// [x], [y], [w], [h] as fractions of [r].
Rect _in(Rect r, double x, double y, double w, double h) => Rect.fromLTWH(r.left + x * r.width, r.top + y * r.height, w * r.width, h * r.height);

/// A Japanese house's wall: near-white plaster, aluminium windows; [k] 0
/// its front (a door, a balcony), 1 its back, 2 a side.
void paintJapanWall(Canvas c, Rect r, int k) {
  c
    ..drawRect(r, Paint()..color = const Color(0xFFF4F2EE))
    ..drawRect(_in(r, 0, 0.49, 1, 0.016), Paint()..color = const Color(0xFFB9B4AA))
    ..drawRect(_in(r, 0, 0.97, 1, 0.03), Paint()..color = const Color(0xFF8E8B85));
  void window(double x, double y, double w, double h) {
    final o = _in(r, x, y, w, h);
    c.drawRect(o, Paint()..color = const Color(0xFF9EA4A8));
    final g = o.deflate(5);
    c
      ..drawRect(
        g,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5E7488), Color(0xFF2A3644), Color(0xFF3E5064)],
          ).createShader(g),
      )
      ..drawRect(Rect.fromLTWH(g.center.dx - 2, g.top, 4, g.height), Paint()..color = const Color(0xFF9EA4A8));
  }

  switch (k) {
    case 0:
      // Upstairs two windows over a balcony; downstairs a window and the
      // door.
      window(0.12, 0.12, 0.3, 0.26);
      window(0.56, 0.12, 0.3, 0.26);
      c.drawRect(_in(r, 0.08, 0.36, 0.84, 0.07), Paint()..color = const Color(0xFFD9D6D0));
      for (var x = 0.1; x < 0.9; x += 0.04) {
        c.drawRect(_in(r, x, 0.36, 0.006, 0.07), Paint()..color = const Color(0xFF8E959A));
      }
      window(0.1, 0.6, 0.36, 0.24);
      final door = _in(r, 0.62, 0.56, 0.2, 0.42);
      c
        ..drawRect(door, Paint()..color = const Color(0xFF6B4A33))
        ..drawRect(Rect.fromLTWH(door.right - 18, door.center.dy, 8, 30), Paint()..color = const Color(0xFFC9A36B));
    case 1:
      window(0.14, 0.13, 0.28, 0.24);
      window(0.58, 0.13, 0.28, 0.24);
      window(0.14, 0.62, 0.28, 0.22);
      window(0.58, 0.62, 0.28, 0.22);
    default:
      window(0.36, 0.15, 0.28, 0.2);
      window(0.42, 0.64, 0.18, 0.16);
  }
}

/// An English house's wall: red brick, white sash windows under stone
/// lintels, a black door with a fanlight ([k] as for [paintJapanWall]).
void paintBrickWall(Canvas c, Rect r, int k) {
  // Brick: courses of stretchers in mortar, a few bricks darker.
  c.drawRect(r, Paint()..color = const Color(0xFF9E4E38));
  final rnd = math.Random(k + 5), mortar = Paint()
    ..color = const Color(0xFFCFC2B0)
    ..strokeWidth = 1.5;
  const course = 9.0, brick = 22.0;
  for (var y = r.top, n = 0; y < r.bottom; y += course, n++) {
    for (var x = r.left - (n.isEven ? 0 : brick / 2); x < r.right; x += brick) {
      if (rnd.nextDouble() < 0.18) c.drawRect(Rect.fromLTWH(x, y, brick, course), Paint()..color = Color.lerp(const Color(0xFF7E3A2A), const Color(0xFFB4634A), rnd.nextDouble())!);
      c.drawLine(Offset(x, y), Offset(x, y + course), mortar);
    }
    c.drawLine(Offset(r.left, y), Offset(r.right, y), mortar);
  }
  // A stone band between the storeys, the plinth.
  c
    ..drawRect(_in(r, 0, 0.485, 1, 0.025), Paint()..color = const Color(0xFFE2D9C6))
    ..drawRect(_in(r, 0, 0.96, 1, 0.04), Paint()..color = const Color(0xFF5E5650));
  void sash(double x, double y, double w, double h) {
    final o = _in(r, x, y, w, h);
    c
      ..drawRect(_in(r, x - 0.02, y - 0.035, w + 0.04, 0.03), Paint()..color = const Color(0xFFE8E0CE))
      ..drawRect(_in(r, x - 0.015, y + h, w + 0.03, 0.02), Paint()..color = const Color(0xFFE8E0CE))
      ..drawRect(o, Paint()..color = const Color(0xFFF4F2EC));
    final g = o.deflate(4);
    c.drawRect(g, Paint()..color = const Color(0xFF2C3846));
    final bar = Paint()
      ..color = const Color(0xFFF4F2EC)
      ..strokeWidth = 3;
    for (final f in [1 / 3, 2 / 3]) {
      c.drawLine(Offset(g.left + g.width * f, g.top), Offset(g.left + g.width * f, g.bottom), bar);
    }
    for (final f in [0.25, 0.5, 0.75]) {
      c.drawLine(Offset(g.left, g.top + g.height * f), Offset(g.right, g.top + g.height * f), f == 0.5 ? (Paint()..color = const Color(0xFFF4F2EC)..strokeWidth = 6) : bar);
    }
  }

  switch (k) {
    case 0:
      sash(0.14, 0.1, 0.26, 0.3);
      sash(0.6, 0.1, 0.26, 0.3);
      sash(0.12, 0.58, 0.28, 0.32);
      // The door: black, a fanlight over it, a stone surround and step.
      c
        ..drawRect(_in(r, 0.58, 0.5, 0.3, 0.47), Paint()..color = const Color(0xFFE8E0CE))
        ..drawRect(_in(r, 0.62, 0.62, 0.22, 0.35), Paint()..color = const Color(0xFF15171B))
        ..drawArc(_in(r, 0.62, 0.53, 0.22, 0.18), math.pi, math.pi, true, Paint()..color = const Color(0xFF2C3846))
        ..drawCircle(_in(r, 0.79, 0.8, 0, 0).topLeft, 4, Paint()..color = const Color(0xFFC9A36B));
    case 1:
      sash(0.14, 0.1, 0.26, 0.3);
      sash(0.6, 0.1, 0.26, 0.3);
      sash(0.14, 0.58, 0.26, 0.3);
      sash(0.6, 0.58, 0.26, 0.3);
    default:
      sash(0.38, 0.12, 0.24, 0.28);
      sash(0.4, 0.6, 0.2, 0.26);
  }
}

/// A German house's wall: dark beams over white plaster, windows with
/// green shutters and boxes of flowers ([k] as for [paintJapanWall]).
void paintTimberWall(Canvas c, Rect r, int k) {
  c.drawRect(r, Paint()..color = const Color(0xFFF5F0E4));
  final beam = Paint()
    ..color = const Color(0xFF4A3426)
    ..strokeWidth = 12
    ..strokeCap = StrokeCap.square;
  Offset at(double x, double y) => Offset(r.left + x * r.width, r.top + y * r.height);
  // The frame: sills and plates at each storey, posts in four bays.
  for (final y in [0.02, 0.5, 0.97]) {
    c.drawLine(at(0, y), at(1, y), beam..strokeWidth = 14);
  }
  beam.strokeWidth = 11;
  for (final x in [0.02, 0.26, 0.5, 0.74, 0.98]) {
    c
      ..drawLine(at(x, 0.02), at(x, 0.5), beam)
      ..drawLine(at(x, 0.5), at(x, 0.97), beam);
  }
  // Windows (white frames, green shutters, a box of flowers) in some
  // bays, braces crossing the others.
  final windows = switch (k) {
    0 => const [(0, 0), (2, 0), (3, 0), (0, 1)],
    1 => const [(0, 0), (3, 0), (0, 1), (3, 1)],
    _ => const [(1, 0), (2, 1)],
  };
  for (var bay = 0; bay < 4; bay++) {
    for (var storey = 0; storey < 2; storey++) {
      final x0 = 0.02 + bay * 0.24, y0 = 0.02 + storey * 0.48;
      final door = k == 0 && storey == 1 && bay == 2;
      if (door) {
        c
          ..drawRect(_in(r, x0 + 0.04, y0 + 0.12, 0.16, 0.35), Paint()..color = const Color(0xFF6B4A33))
          ..drawArc(_in(r, x0 + 0.04, y0 + 0.06, 0.16, 0.12), math.pi, math.pi, true, Paint()..color = const Color(0xFF6B4A33));
        continue;
      }
      if (windows.contains((bay, storey))) {
        final w = _in(r, x0 + 0.06, y0 + 0.1, 0.12, 0.22);
        c
          ..drawRect(w.inflate(4), Paint()..color = const Color(0xFFF4F2EC))
          ..drawRect(w, Paint()..color = const Color(0xFF2C3846))
          ..drawLine(Offset(w.center.dx, w.top), Offset(w.center.dx, w.bottom), Paint()..color = const Color(0xFFF4F2EC)..strokeWidth = 3)
          ..drawLine(Offset(w.left, w.center.dy), Offset(w.right, w.center.dy), Paint()..color = const Color(0xFFF4F2EC)..strokeWidth = 3);
        for (final side in [-1.0, 1.0]) {
          c.drawRect(Rect.fromLTWH(side < 0 ? w.left - 4 - w.width * 0.42 : w.right + 4, w.top, w.width * 0.42, w.height), Paint()..color = const Color(0xFF3C7A4E));
        }
        if (storey == 0) {
          c.drawRect(Rect.fromLTWH(w.left - 6, w.bottom + 6, w.width + 12, 10), Paint()..color = const Color(0xFF6B4A33));
          final rnd = math.Random(bay * 7 + k);
          for (var f = 0; f < 6; f++) {
            c.drawCircle(Offset(w.left + rnd.nextDouble() * w.width, w.bottom + 2), 5, Paint()..color = [const Color(0xFFD9344A), const Color(0xFFF06A8A), const Color(0xFFF4E04D)][rnd.nextInt(3)]);
          }
        }
      } else {
        // A brace each way (the "man" figure's arms).
        c
          ..drawLine(at(x0, y0 + 0.46), at(x0 + 0.12, y0 + 0.02), beam..strokeWidth = 9)
          ..drawLine(at(x0 + 0.24, y0 + 0.46), at(x0 + 0.12, y0 + 0.02), beam);
      }
    }
  }
}
