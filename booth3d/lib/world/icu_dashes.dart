import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'dashes.dart';
import 'ease.dart';
import 'v_icu.dart' show IcuCity;

/// ICU City's Dashes: a few out walking on its square, sightseeing, on
/// holiday, on the way to work (round its middle, and the other way round
/// a wider loop, clear of the scenes' cameras and the road; one or two on
/// its outer ring); and, a hidden gem, ninja
/// Dashes on its roofs. They crouch behind the parapets (a tuft over the
/// top all you see) and now and then peek over; one keeps a lookout from
/// a tall block; one sprints along a roof and leaps the gap to the next,
/// and back again a while later.
class IcuDashes {
  IcuDashes(this.scene);

  final Scene scene;
  late final _dashes = Dashes(scene);
  bool _ready = false;

  Future<void> init() async {
    await _dashes.build();
    _ready = true;
  }

  /// The walkers' loops: round the square's middle, the other way round a
  /// wider loop (both east of where the locale scene's camera comes in,
  /// north of the road), and on the outer ring (bearings, degrees from
  /// north: out along the inner radius, back along the outer).
  static final _loops = [
    _Loop.ellipse(2, 2, 10, 9, clockwise: true),
    _Loop.ellipse(3, 1, 15, 13, clockwise: false),
    _Loop.band(-86, -14, 34.5, 39.5),
    _Loop.band(26, 46, 34.5, 40),
  ];

  /// Who walks which (loop, how far along it to start, m/s, size, kind).
  static const _walkers = [
    (0, 0.0, 0.55, 1.0, DashKind.sightseer),
    (0, 0.36, 0.55, 0.92, DashKind.holiday),
    (0, 0.7, 0.55, 1.06, DashKind.commuter),
    (1, 0.15, 0.5, 0.96, DashKind.backpacker),
    (1, 0.62, 0.5, 1.04, DashKind.holiday),
    (2, 0.3, 0.58, 0.9, DashKind.sightseer),
    (3, 0.5, 0.52, 0.94, DashKind.commuter),
  ];

  void update(double t) {
    if (!_ready) return;
    _dashes.begin();
    for (final (i, (loop, start, speed, size, kind)) in _walkers.indexed) {
      final l = _loops[loop], s = start * l.length + speed * t;
      final p = l.at(s), dir = l.at(s + 0.5) - l.at(s - 0.5);
      _dashes.place(i, kind, p.x, p.z, math.atan2(-dir.x, -dir.z), size, step: s / (0.14 * size) * math.pi, walking: 1, t: t);
    }
    _ninjas(t);
    _dashes.end();
  }

  // ── The ninjas ────────────────────────────────────────────────────────────

  void _ninjas(double t) {
    var no = _walkers.length;
    // Crouched behind a parapet, peeking over for a moment now and then
    // (block, along its front, period, how long, when), looking about.
    for (final (block, x, period, up, phase) in const [(5, -2.5, 13.0, 2.6, 3.0), (1, 3.0, 17.0, 2.2, 9.0)]) {
      final (p, yaw) = IcuCity.onRoof(block, x, 0.45);
      final u = (t + phase) % period;
      final peek = u < up ? smooth(0, 0.5, u) * (1 - smooth(up - 0.5, up, u)) : 0.0;
      final look = 0.35 * math.sin((u / up) * math.pi * 2) * peek;
      _dashes.place(no++, DashKind.ninja, p.x, p.z, yaw + look, 0.9, step: 0, walking: 0, t: t, y: p.y + 0.24 * peek);
    }
    // A lookout on a tall block, its head over the parapet, slowly
    // scanning the square.
    {
      final (p, yaw) = IcuCity.onRoof(6, -6, 0.5);
      _dashes.place(no++, DashKind.ninja, p.x, p.z, yaw + 0.4 * math.sin(t * 0.23), 0.95, step: 0, walking: 0, t: t, y: p.y + 0.22);
    }
    // A runner: from behind one block's parapet along its roof, over the
    // gap and up onto the next, and down out of sight; back again later.
    _runner(no, t);
  }

  /// The runner's way: along block 4's roof to its end, a leap over the
  /// gap onto block 3's, along it (behind the parapets: its head over
  /// them); the times (s) it spends out of sight at either end.
  static const _hide = 10.0, _run1 = 1.4, _leap = 0.8, _run2 = 0.7;

  void _runner(int no, double t) {
    const out = _run1 + _leap + _run2, period = 2 * (_hide + out);
    final u = t % period;
    // (There: 0 … out; and back, the same way reversed.)
    final going = u < _hide + out;
    final k = going ? u - _hide : u - (2 * _hide + out);
    final f = k <= 0 ? 0.0 : (k >= out ? out : k);
    final along = going ? f : out - f;
    final (a, facing) = IcuCity.onRoof(4, 5.5, 0.6);
    final (b, _) = IcuCity.onRoof(4, -7.6, 0.6);
    final (c, _) = IcuCity.onRoof(3, 8.6, 0.6);
    final (d, _) = IcuCity.onRoof(3, 2.0, 0.6);
    vm.Vector3 where(double s) {
      if (s < _run1) return a + (b - a) * (s / _run1);
      if (s < _run1 + _leap) {
        final e = (s - _run1) / _leap;
        return (b + (c - b) * e)..y += 1.8 * math.sin(math.pi * e);
      }
      return c + (d - c) * c01((s - _run1 - _leap) / _run2);
    }

    final p = where(along), ahead = where((along + (going ? 0.05 : -0.05)).clamp(0.0, out)) - p;
    final moving = k > 0 && k < out;
    final inAir = moving && along > _run1 && along < _run1 + _leap;
    // (Out of sight, crouched facing the square.)
    final yaw = moving && ahead.length > 1e-4 ? math.atan2(-ahead.x, -ahead.z) : facing;
    _dashes.place(no, DashKind.ninja, p.x, p.z, yaw, 0.9, step: along / (0.14 * 0.9) * math.pi * 1.4, walking: moving && !inAir ? 1 : 0, t: t, y: p.y, flap: inAir ? 0.7 : 0);
  }
}

/// A walker's loop on the square (in the world, closed): its length, and
/// where a Dash is so far along it.
class _Loop {
  _Loop(this._pts) {
    _pts.add(_pts.first.clone());
    _at.add(0);
    for (var k = 1; k < _pts.length; k++) {
      _at.add(_at.last + (_pts[k] - _pts[k - 1]).length);
    }
  }

  /// Round an ellipse about (cx, cz) in ICU City's frame, [rx] across and
  /// [rz] north–south.
  factory _Loop.ellipse(double cx, double cz, double rx, double rz, {required bool clockwise}) {
    final o = IcuCity.o;
    const n = 64;
    return _Loop([
      for (var k = 0; k < n; k++)
        () {
          final a = (clockwise ? 1 : -1) * k / n * math.pi * 2;
          return vm.Vector3(o.x + cx + rx * math.sin(a), 0, o.z + cz + rz * math.cos(a));
        }(),
    ]);
  }

  /// Part of the ring round the square: out along [rIn] from bearing [b0]
  /// to [b1] (degrees from north), back along [rOut].
  factory _Loop.band(double b0, double b1, double rIn, double rOut) {
    final o = IcuCity.o;
    vm.Vector3 p(double b, double r) => vm.Vector3(o.x + r * math.sin(b * math.pi / 180), 0, o.z + r * math.cos(b * math.pi / 180));
    final n = ((b1 - b0) / 2).ceil();
    return _Loop([
      for (var k = 0; k <= n; k++) p(b0 + (b1 - b0) * k / n, rIn),
      for (var k = 0; k <= n; k++) p(b1 - (b1 - b0) * k / n, rOut),
    ]);
  }

  final List<vm.Vector3> _pts;
  final _at = <double>[];

  double get length => _at.last;

  /// Where it is [s] metres along (round and round).
  vm.Vector3 at(double s) {
    final d = s % length;
    var k = 1;
    while (k < _at.length - 1 && _at[k] < d) {
      k++;
    }
    final e = (d - _at[k - 1]) / math.max(1e-6, _at[k] - _at[k - 1]);
    return _pts[k - 1] + (_pts[k] - _pts[k - 1]) * e;
  }
}
