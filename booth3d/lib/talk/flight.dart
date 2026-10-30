import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../world/ease.dart';
import '../world/shot.dart';
import '../world/volume.dart';

/// The talk's camera on its way from one framing to the next, planned as
/// it sets off: the eye along one smooth curve (out of the room it's in by
/// its door; up over whatever's in the way and down again, a gentle arc,
/// never straight up; in by the next room's door), the view turning
/// steadily from the first framing's to the next's (round the vertical,
/// the shorter way, and up or down), as far off as theirs. It takes as
/// long as the turn and the distance need, so it never whips round: a
/// beat's own time at least.
class Flight {
  Flight(this.from, Shot to, List<Volume> volumes, {required double fly, required bool back, bool cut = false, this.cruise = 16}) {
    final a = from.eye, b = to.eye;
    // Out of the room it's in, by its door; into the one it's going to.
    final out = _roomOf(a, volumes), into = _roomOf(b, volumes);
    if (!identical(out, into)) {
      if (out?.door case final d?) {
        if (d.depthOf(a) > 1.8) _head.add(d.through(a, -1.2));
        _head.add(d.through(a, 2.6));
      }
      if (into?.door case final d?) {
        _tail.add(d.through(b, 2.6));
        if (d.depthOf(b) > 1.8) _tail.add(d.through(b, -1.2));
      }
    }
    // (Up out of the ground first, from under the street; but from one
    // place in the archive's hall to another, along it, under its ceiling.)
    final under = a.y < -0.2 && b.y < -0.2;
    if (a.y < -0.2 && !under && _head.isEmpty) _head.add(vm.Vector3(a.x, 1.8, a.z));
    // Over what's in the way between: how high above the straight way the
    // eye has to be at each point of it (none at its ends).
    final p0 = _head.isEmpty ? a : _head.last, p1 = _tail.isEmpty ? b : _tail.first;
    final flat = math.sqrt((p1.x - p0.x) * (p1.x - p0.x) + (p1.z - p0.z) * (p1.z - p0.z));
    final needs = <(double, double)>[];
    if ((p1 - p0).length > 1) {
      const n = 40;
      for (var j = 1; j < n; j++) {
        final s = j / n, p = p0 + (p1 - p0) * s;
        var need = 0.0;
        for (final v in volumes) {
          if (v.soft && (s < 0.15 || s > 0.85)) continue;
          if (identical(v, out) || identical(v, into) || !v.over(p, 2.0) || p.y < v.middle.y - v.half.y - 1.5) continue;
          need = math.max(need, v.top + 2.5 - p.y);
        }
        // (A long way: over the park's trees and the scenes' roofs, climbed
        // to and come down from gently.)
        if (flat > 20 && !under) need = math.max(need, (cruise - p.y) * math.min(1.0, math.min(s, 1 - s) / 0.35));
        // (And a little higher the farther it goes: an arc; a low one
        // under the street.)
        need = math.max(need, math.min(0.1 * flat, under ? 1.2 : 24.0) * math.sin(math.pi * s));
        if (need > 0) needs.add((s, need));
      }
    }
    // The heights at the way's points: each need reached by an eased climb
    // from the way's start and an eased descent to its end.
    double lift(double s) {
      var h = 0.0;
      for (final (sj, need) in needs) {
        h = math.max(h, need * (s <= sj ? smooth(0, sj, s) : 1 - smooth(sj, 1, s)));
      }
      return h;
    }

    final k = flat < 3 && needs.isEmpty ? 0 : 7;
    for (var i = 1; i <= k; i++) {
      _leg.add((i / (k + 1), lift(i / (k + 1))));
    }
    // How long: a beat's own time, longer for a big turn or a long way.
    final da = _dir(from), db = _dir(to);
    _yaw0 = math.atan2(da.x, da.z);
    _pitch0 = math.asin(da.y.clamp(-1.0, 1.0));
    _turn = _wrap(math.atan2(db.x, db.z) - _yaw0);
    final pitch = math.asin(db.y.clamp(-1.0, 1.0)) - _pitch0;
    final degrees = math.sqrt(_turn * _turn + pitch * pitch) * 180 / math.pi;
    final len = _length(_points(to.eye));
    time = cut
        ? 0
        : back
        ? math.min(3.0, math.max(math.max(math.min(fly, 1.1), degrees / 60), 0.6 + math.sqrt(len) / 6))
        : math.min(6.0, math.max(math.max(fly, degrees / 32), 1.0 + math.sqrt(len) / 4));
  }

  final Shot from;
  final double cruise;

  /// How long it takes (seconds).
  late final double time;

  /// Its fixed points: out of the room it starts in; the arc between (each
  /// point's share of the way and its height over the straight way); into
  /// the room it ends in.
  final _head = <vm.Vector3>[], _tail = <vm.Vector3>[];
  final _leg = <(double, double)>[];

  /// Which way it looks at the start, and how far it turns round (the
  /// shorter way, as it set off: kept, as the next framing moves on).
  late final double _yaw0, _pitch0, _turn;

  /// The camera [u] (0..1) of the way there, the next framing [to] now (a
  /// scene's camera moves on).
  Shot at(double u, Shot to) {
    final e = u * u * u * (u * (u * 6 - 15) + 10);
    final eye = _along(_points(to.eye), e);
    // The view: turned round as planned, up or down to the next's.
    final db = _dir(to);
    final yaw = _yaw0 + (_turn + _wrap(math.atan2(db.x, db.z) - _yaw0 - _turn)) * e;
    final pitch = lerp(_pitch0, math.asin(db.y.clamp(-1.0, 1.0)), e);
    final dir = vm.Vector3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch));
    final fa = (from.target - from.eye).length, fb = (to.target - to.eye).length;
    final far = fa * math.pow(fb / math.max(fa, 1e-3), e);
    return Shot(eye, eye + dir * far.toDouble(), fov: lerp(from.fov, to.fov, e), settle: to.settle, drift: lerp(from.drift, to.drift, e));
  }

  /// The way's points, its end at [end].
  List<vm.Vector3> _points(vm.Vector3 end) {
    final p0 = _head.isEmpty ? from.eye : _head.last, p1 = _tail.isEmpty ? end : _tail.first;
    return [
      from.eye,
      ..._head,
      for (final (s, h) in _leg) (p0 + (p1 - p0) * s)..y += h,
      ..._tail,
      end,
    ];
  }

  /// [e] (0..1) of the way along a smooth curve through [pts] (centripetal
  /// Catmull-Rom), by distance.
  static vm.Vector3 _along(List<vm.Vector3> pts, double e) {
    final line = _curve(pts);
    final lens = [for (var i = 0; i + 1 < line.length; i++) line[i].distanceTo(line[i + 1])];
    var d = e * lens.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < lens.length; i++) {
      if (d <= lens[i] || i == lens.length - 1) {
        final f = lens[i] < 1e-9 ? 0.0 : (d / lens[i]).clamp(0.0, 1.0);
        return line[i] + (line[i + 1] - line[i]) * f;
      }
      d -= lens[i];
    }
    return line.last.clone();
  }

  static double _length(List<vm.Vector3> pts) {
    final line = _curve(pts);
    var s = 0.0;
    for (var i = 0; i + 1 < line.length; i++) {
      s += line[i].distanceTo(line[i + 1]);
    }
    return s;
  }

  /// The curve through [pts], a few points between each two.
  static List<vm.Vector3> _curve(List<vm.Vector3> pts) {
    // (Points on top of each other add nothing.)
    final p = <vm.Vector3>[];
    for (final q in pts) {
      if (p.isEmpty || p.last.distanceTo(q) > 0.05) p.add(q);
    }
    if (p.length < 2) return [pts.first, pts.last];
    const steps = 10;
    final out = <vm.Vector3>[p.first];
    for (var i = 0; i + 1 < p.length; i++) {
      final p0 = i == 0 ? p[0] * 2 - p[1] : p[i - 1], p1 = p[i], p2 = p[i + 1], p3 = i + 2 < p.length ? p[i + 2] : p[i + 1] * 2 - p[i];
      for (var k = 1; k <= steps; k++) {
        out.add(_catmull(p0, p1, p2, p3, k / steps));
      }
    }
    return out;
  }

  /// Centripetal Catmull-Rom between [p1] and [p2], [t] of the way.
  static vm.Vector3 _catmull(vm.Vector3 p0, vm.Vector3 p1, vm.Vector3 p2, vm.Vector3 p3, double t) {
    double knot(vm.Vector3 a, vm.Vector3 b) => math.max(math.sqrt(a.distanceTo(b)), 1e-4);
    final t1 = knot(p0, p1), t2 = t1 + knot(p1, p2), t3 = t2 + knot(p2, p3);
    final u = lerp(t1, t2, t);
    vm.Vector3 mix(vm.Vector3 a, vm.Vector3 b, double ta, double tb) => a * ((tb - u) / (tb - ta)) + b * ((u - ta) / (tb - ta));
    final a1 = mix(p0, p1, 0, t1), a2 = mix(p1, p2, t1, t2), a3 = mix(p2, p3, t2, t3);
    final b1 = mix(a1, a2, 0, t2), b2 = mix(a2, a3, t1, t3);
    return mix(b1, b2, t1, t2);
  }

  static vm.Vector3 _dir(Shot s) => (s.target - s.eye)..normalize();

  /// [a] as an angle between −π and π.
  static double _wrap(double a) => a - 2 * math.pi * ((a + math.pi) / (2 * math.pi)).floorToDouble();

  /// The room (a volume with a door) [p] is in, if any.
  static Volume? _roomOf(vm.Vector3 p, List<Volume> volumes) {
    for (final v in volumes) {
      if (v.door != null && v.contains(p)) return v;
    }
    return null;
  }
}
