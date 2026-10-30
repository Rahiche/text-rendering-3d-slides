import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// An elastic strip pinned at its ends: a row of points, each pair held as
/// far apart as at rest (it doesn't stretch), each one's bend held to its
/// rest bend softly (it bends, stiffly, and springs back), damped (the fast
/// wiggles far more than its sway). A thread is tied to its middle point
/// ([tied]), its other end in Dash's beak ([beak]: Dash hovering [depth] out
/// in front of it, flying about below it); taut, the thread pulls that
/// point Dash's way. From a duel on ([advanceTo]'s `duel`), a rival Dash
/// flies in, ties its own thread to the same point and the two pull it each
/// their own way ([rival]). Squeezed ([advanceTo]'s `squeeze`), its pins
/// slide in and down and it bows up into a tighter curve; let go, they slide
/// back out. The presenter's hand takes hold of the point nearest it as it
/// presses and pulls that point along. Stepped by XPBD (small steps, one
/// pass each: Macklin et al., "Small Steps in Physics Simulation", 2019) at
/// a fixed rate from its start, so a time shows the same shape however the
/// frames fall; going back starts it again.
///
/// Its px are the board's (100 a metre). The thread's knot, hands and the
/// points they're shown on are on its band ([band]), [under] px below the
/// curve itself (the text stands on the curve, its joins clear of the
/// band).
class Strip {
  Strip(this._rest)
    : _p = [..._rest],
      _v = List.filled(_rest.length, Offset.zero),
      _len = [for (var i = 0; i + 1 < _rest.length; i++) (_rest[i + 1] - _rest[i]).distance],
      _bend = [for (var i = 1; i + 1 < _rest.length; i++) _turn(_rest[i - 1], _rest[i], _rest[i + 1])],
      _reachA = _reachFrom(_rest),
      _reachB = _reachFrom(_rest.reversed.toList()).reversed.toList(),
      tied = _rest.length ~/ 2,
      _knot = _restKnot(_rest);

  /// Along an arc round [centre], [radius] out, [spread] radians either side
  /// of its top; left to right (the text stands on its outside).
  factory Strip.arc(Offset centre, double radius, double spread, {int points = 21}) => Strip([
    for (var i = 0; i < points; i++)
      () {
        final a = -math.pi / 2 - spread + 2 * spread * i / (points - 1);
        return centre + Offset(math.cos(a), math.sin(a)) * radius;
      }(),
  ]);

  final List<Offset> _rest;
  final List<double> _len, _bend, _reachA, _reachB;

  /// The knot at rest (on the band): where the Dashes' flights are reckoned
  /// from.
  final Offset _knot;
  List<Offset> _p;
  List<Offset> _v;
  double _t = 0;

  /// The point the thread's tied to: the middle one.
  final int tied;

  /// The thread's length, and how far out in front of the strip Dash holds
  /// its end (px).
  static const thread = 250.0, depth = 170.0;

  /// How far across the board the thread reaches (its length, less what
  /// Dash's depth takes).
  static final _across = math.sqrt(thread * thread - depth * depth);

  /// How taut each thread's been of late (0 slack … 1 pulling): Dash's,
  /// the rival's.
  double _pull = 0, _rivalPull = 0;

  /// The strip's clock as the rival came, if it has.
  double? _duel;

  /// How far its pins are squeezed in (0 at rest … 1 all the way), how
  /// fast, and toward which; how far they go, each (px: in, and down).
  double _squeeze = 0, _squeezeV = 0;
  bool _squeezing = false;
  static const _inward = 175.0, _drop = 135.0;

  /// When the squeeze began and ended (Dash leaves off pulling meanwhile,
  /// hovering in the middle below the word, its thread slack: the tight
  /// curve kept clear and clean).
  double? _squeezedAt, _releasedAt;

  /// How far its pins are squeezed in (0 … 1).
  double get squeeze => _squeeze;

  /// The rails its pins slide along (on the band, where they're shown),
  /// while they're off their rest.
  List<(Offset, Offset)>? get rails {
    if (_squeeze < 0.01) return null;
    final n = _p.length;
    // (Down from the curve: the right of travel, as [band]'s.)
    Offset shown(Offset pin, Offset travel) => pin + Offset(-travel.dy, travel.dx) / travel.distance * under;
    final a = _rest[1] - _rest[0], b = _rest[n - 1] - _rest[n - 2];
    return [
      (shown(_rest.first, a), shown(_rest.first + const Offset(_inward, _drop), a)),
      (shown(_rest.last, b), shown(_rest.last + const Offset(-_inward, _drop), b)),
    ];
  }

  /// The point in hand, if any, and where it was from the hand as it took
  /// hold (easing to nothing: no jolt as it takes hold); whether the hand's
  /// pressed.
  int? _held;
  Offset _grip = Offset.zero;
  bool _pressed = false;

  /// The curve's points now.
  List<Offset> get points => _p;

  /// The point in hand, if any.
  int? get held => _held;

  /// Dash's beak now (px, over the board), and how hard it's pulling (0
  /// the thread slack … 1 taut); the rival's (null till it comes), whether
  /// it's tied its thread on, how hard it's pulling.
  Offset get beak => beakAt(_t);
  double get pull => _pull;
  Offset? get rival => rivalAt(_t);
  bool get rivalTied => _rivalTiedAt(_t);
  double get rivalPull => _rivalPull;

  static const under = 22.0;

  /// The step; the bend's compliance (its softness, in XPBD's terms, a unit
  /// mass a point); the hand's; the thread's; the damping (/s), and the
  /// fast wiggles' (a share of each point's speed evened with its
  /// neighbours' a step).
  static const _dt = 1 / 600.0, _bendSoft = 1.6e-7, _handSoft = 2e-5, _threadSoft = 5e-5, _damping = 0.9, _smooth = 0.05;

  /// How far a press reaches for a point (px); how much of the slack
  /// between a point and a pin (the strip between them less the straight
  /// line at rest) a pull may take up (so it's never pulled straight); how
  /// fast a hand's grip eases to it (s).
  static const _reach = 90.0, _give = 0.6, _gripEase = 0.25;

  /// How far each point may be pulled from the first pin ([_give] of its
  /// slack out).
  static List<double> _reachFrom(List<Offset> rest) {
    var along = 0.0;
    return [
      for (var i = 0; i < rest.length; i++)
        () {
          if (i > 0) along += (rest[i] - rest[i - 1]).distance;
          final straight = (rest[i] - rest.first).distance;
          return straight + _give * (along - straight);
        }(),
    ];
  }

  /// Where point [i] is shown: on the band.
  Offset band(int i) => _p[i] + _normal(i) * under;

  /// Down from the curve at point [i] (the right of travel, left to right).
  Offset _normal(int i) {
    final a = _p[math.max(i - 1, 0)], b = _p[math.min(i + 1, _p.length - 1)];
    final t = b - a, len = t.distance;
    return len < 1e-9 ? const Offset(0, 1) : Offset(-t.dy, t.dx) / len;
  }

  /// To [t] s from its start, [hand] the presenter's pointer while pressed
  /// (px on the band), else null; [duel] the time the rival came, if it has;
  /// [squeeze] whether its pins are to be squeezed in.
  void advanceTo(double t, {Offset? hand, double? duel, bool squeeze = false}) {
    if (t < _t - 1e-6) {
      _p = [..._rest];
      _v = List.filled(_rest.length, Offset.zero);
      _t = 0;
      _pull = _rivalPull = 0;
      _squeeze = _squeezeV = 0;
      _squeezedAt = _releasedAt = null;
      _held = null;
      _pressed = false;
    }
    _duel = duel;
    if (squeeze != _squeezing) {
      if (squeeze) {
        _squeezedAt = _t;
        _releasedAt = null;
      } else {
        _releasedAt = _t;
      }
    }
    _squeezing = squeeze;
    while (_t + _dt <= t) {
      _step(hand);
      _t += _dt;
    }
  }

  /// The point nearest [at] (on the band), if one's in reach; never a pin.
  int? _nearest(Offset at) {
    int? best;
    var d = _reach;
    for (var i = 1; i + 1 < _p.length; i++) {
      final e = (band(i) - at).distance;
      if (e < d) {
        d = e;
        best = i;
      }
    }
    return best;
  }

  /// Where a pull can take point [h] (on the curve) toward [at]: no further
  /// from either pin than its reach.
  Offset _within(int h, Offset at) {
    final a = _p.first, b = _p.last, ra = _reachA[h], rb = _reachB[h];
    var q = at;
    for (var k = 0; k < 4; k++) {
      if ((q - a).distance > ra) q = a + (q - a) / (q - a).distance * ra;
      if ((q - b).distance > rb) q = b + (q - b) / (q - b).distance * rb;
    }
    return q;
  }

  void _step(Offset? hand) {
    // Taking hold as the hand presses (if a point's in reach), letting go
    // as it lifts.
    if (hand == null) {
      _held = null;
      _pressed = false;
    } else if (!_pressed) {
      _pressed = true;
      _held = _nearest(hand);
      if (_held != null) _grip = band(_held!) - hand;
    }
    final n = _p.length, old = [..._p], keep = 1 - _damping * _dt;
    // The pins, sliding in and down while it's squeezed, out after (a
    // critically damped spring: no jolt either way).
    const w = 3.5;
    _squeezeV += (w * w * ((_squeezing ? 1.0 : 0.0) - _squeeze) - 2 * w * _squeezeV) * _dt;
    _squeeze += _squeezeV * _dt;
    _p[0] = _rest.first + const Offset(_inward, _drop) * _squeeze;
    _p[n - 1] = _rest.last + const Offset(-_inward, _drop) * _squeeze;
    for (var i = 1; i < n - 1; i++) {
      _v[i] *= keep;
      _p[i] += _v[i] * _dt;
    }
    // The hand: the point it holds (shown on the band) pulled toward it.
    final h = _held;
    if (h != null && hand != null) {
      _grip *= 1 - _dt / _gripEase;
      final to = _within(h, hand + _grip - _normal(h) * under), d = _p[h] - to;
      _p[h] -= d * (1 / (1 + _handSoft / (_dt * _dt)));
    }
    // The threads, Dash's and (once it's tied on) the rival's.
    _pull += (_threadFrom(beakAt(_t)) - _pull) * (_dt / 0.15);
    final r = rivalAt(_t);
    _rivalPull += ((r != null && _rivalTiedAt(_t) ? _threadFrom(r) : 0.0) - _rivalPull) * (_dt / 0.15);
    // Its bends: each point's turn back toward its rest turn, softly.
    final soft = _bendSoft / (_dt * _dt);
    for (var i = 1; i + 1 < n; i++) {
      final e1 = _p[i] - _p[i - 1], e2 = _p[i + 1] - _p[i];
      final l1 = e1.distanceSquared, l2 = e2.distanceSquared;
      if (l1 < 1e-9 || l2 < 1e-9) continue;
      var c = _turn(_p[i - 1], _p[i], _p[i + 1]) - _bend[i - 1];
      c = (c + math.pi) % (2 * math.pi) - math.pi;
      // The turn's gradient at the three points.
      final g0 = Offset(-e1.dy, e1.dx) / l1, g2 = Offset(-e2.dy, e2.dx) / l2, g1 = -g0 - g2;
      final w0 = i - 1 == 0 ? 0.0 : 1.0, w2 = i + 1 == n - 1 ? 0.0 : 1.0;
      final k = -c / (w0 * g0.distanceSquared + g1.distanceSquared + w2 * g2.distanceSquared + soft);
      _p[i - 1] += g0 * (w0 * k);
      _p[i] += g1 * k;
      _p[i + 1] += g2 * (w2 * k);
    }
    // Its length, last: each pair as far apart as at rest (the pins fixed;
    // along it and back, so a pull's felt from end to end).
    for (var k = 0; k < 2 * (n - 1); k++) {
      final i = k < n - 1 ? k : 2 * (n - 1) - 1 - k;
      final wa = i == 0 ? 0.0 : 1.0, wb = i + 1 == n - 1 ? 0.0 : 1.0;
      final d = _p[i + 1] - _p[i], len = d.distance;
      if (len < 1e-9) continue;
      final fix = d / len * ((len - _len[i]) / (wa + wb));
      _p[i] += fix * wa;
      _p[i + 1] -= fix * wb;
    }
    final v = [for (var i = 0; i < n; i++) i == 0 || i == n - 1 ? Offset.zero : (_p[i] - old[i]) / _dt];
    for (var i = 1; i < n - 1; i++) {
      _v[i] = v[i] + (v[i - 1] + v[i + 1] - v[i] * 2) * (_smooth / 2);
    }
  }

  /// A thread from [beak]: taut, the knot pulled back within its reach
  /// (across the board), and 1; slack, 0.
  double _threadFrom(Offset beak) {
    final d = band(tied) - beak, len = d.distance;
    if (len <= _across) return 0;
    final to = _within(tied, beak + d / len * _across - _normal(tied) * under);
    _p[tied] += (to - _p[tied]) * (1 / (1 + _threadSoft / (_dt * _dt)));
    return 1;
  }

  /// The turn from a→b to b→c (radians, + clockwise on screen).
  static double _turn(Offset a, Offset b, Offset c) {
    final e1 = b - a, e2 = c - b;
    return math.atan2(e1.dx * e2.dy - e1.dy * e2.dx, e1.dx * e2.dx + e1.dy * e2.dy);
  }

  /// The knot's place at rest.
  static Offset _restKnot(List<Offset> rest) {
    final i = rest.length ~/ 2, t = rest[i + 1] - rest[i - 1];
    return rest[i] + Offset(-t.dy, t.dx) / t.distance * under;
  }

  /// Dash's flight alone, again every [_period] s: its beak's place from
  /// the knot's at rest (px) from when, easing from each to the next. It
  /// hovers below the strip, the thread slack; flies off down and to the
  /// left and tugs twice; comes back, letting the strip go; then the same
  /// to the right; then straight down.
  static const _period = 12.0;
  static const _solo = [
    (0.0, Offset(-105, 105)),
    (1.2, Offset(-105, 105)),
    (2.3, Offset(-165, 175)),
    (2.55, Offset(-174, 186)),
    (2.75, Offset(-165, 175)),
    (3.0, Offset(-175, 187)),
    (3.2, Offset(-165, 175)),
    (3.7, Offset(-95, 95)),
    (5.0, Offset(-90, 105)),
    (6.0, Offset(160, 172)),
    (6.25, Offset(169, 183)),
    (6.45, Offset(160, 172)),
    (6.7, Offset(170, 184)),
    (6.9, Offset(160, 172)),
    (7.4, Offset(95, 95)),
    (8.6, Offset(90, 110)),
    (9.4, Offset(-20, 215)),
    (9.65, Offset(-22, 228)),
    (9.85, Offset(-20, 215)),
    (10.1, Offset(-22, 229)),
    (10.3, Offset(-20, 215)),
    (11.0, Offset(-70, 110)),
    (_period, Offset(-105, 105)),
  ];

  /// Where Dash watches the squeezed strip from (from the knot at rest):
  /// below the word, in the middle, its thread slack.
  static const _watching = Offset(0, 160);

  /// The duel: the rival flies in from the right and ties its thread on
  /// ([_tiedAt] s in), Dash easing over to the left meanwhile; from
  /// [_fightAt], round after round of [_round] s: both take up the slack,
  /// Dash heaves (the rival dragged in), the rival heaves (Dash dragged
  /// in), both heave down, both ease off (the strip springing back).
  static const _tiedAt = 1.9, _fightAt = 3.0, _round = 6.4;
  ///
  /// (Each a thread's reach from where the knot's to be, so both are taut:
  /// both pulling, a little below its rest; one winning, half a word's
  /// height down its way; both heaving, further down.)
  static const _dashIn = [(0.0, Offset(-115, 115)), (_tiedAt, Offset(-115, 115)), (_fightAt, Offset(-130, 145))];
  static const _rivalIn = [(0.0, Offset(760, 60)), (1.4, Offset(30, 50)), (_tiedAt, Offset(30, 50)), (_fightAt, Offset(130, 145))];
  static const _dashRound = [
    (0.0, Offset(-130, 145)),
    (1.0, Offset(-136, 150)),
    (2.2, Offset(-190, 184)),
    (3.4, Offset(-86, 174)),
    (4.6, Offset(-136, 192)),
    (5.6, Offset(-110, 110)),
    (_round, Offset(-130, 145)),
  ];
  static const _rivalRound = [
    (0.0, Offset(130, 145)),
    (1.0, Offset(136, 150)),
    (2.2, Offset(86, 174)),
    (3.4, Offset(190, 184)),
    (4.6, Offset(136, 192)),
    (5.6, Offset(110, 110)),
    (_round, Offset(130, 145)),
  ];

  /// Dash's beak at [t] s (px, over the board): alone, on its flight (eased
  /// to the middle while the strip's squeezed, and back); in the duel, eased
  /// over from where it was as the rival came.
  Offset beakAt(double t) {
    final d = _duel;
    if (d == null || t < d) {
      final a = _squeezedAt, b = _releasedAt;
      final watch = a == null || t < a ? 0.0 : (b == null || t < b ? _ease((t - a) / 0.9) : 1 - _ease((t - b) / 0.9));
      return _knot + Offset.lerp(_keyed(_solo, t % _period), _watching, watch)! + _bob(t, 0);
    }
    final u = t - d;
    final to = u < _fightAt ? _keyed(_dashIn, u) : _inRound(_dashRound, (u - _fightAt) % _round, 0);
    return _knot + Offset.lerp(_keyed(_solo, d % _period), to, _ease(u / 0.8))! + _bob(t, 0);
  }

  /// The rival's beak at [t] s (null before it comes): tying on, at the
  /// knot wherever the knot's got to.
  Offset? rivalAt(double t) {
    final d = _duel;
    if (d == null || t < d) return null;
    final u = t - d;
    final at = _knot + (u < _fightAt ? _keyed(_rivalIn, u) : _inRound(_rivalRound, (u - _fightAt) % _round, 1));
    final on = u < _tiedAt ? _ease((u - 0.7) / 0.7) : 1 - _ease((u - _tiedAt) / 0.5);
    // (Its beak just under the knot: its body clear of the word.)
    return Offset.lerp(at, band(tied) + const Offset(14, 36), on)! + _bob(t, 1.7);
  }

  bool _rivalTiedAt(double t) => _duel != null && t - _duel! >= _tiedAt;

  /// Place [v] s into a round from [keys]: heaving, it tugs (out along its
  /// thread, a few times a second); dragged in, it struggles. [who]: 0
  /// Dash, 1 the rival.
  static Offset _inRound(List<(double, Offset)> keys, double v, int who) {
    var at = _keyed(keys, v);
    final heaves = (v >= 3.4 && v < 4.6) || (who == 0 ? v >= 1.0 && v < 2.2 : v >= 2.2 && v < 3.4);
    final dragged = who == 0 ? v >= 2.2 && v < 3.4 : v >= 1.0 && v < 2.2;
    if (heaves) at += at / at.distance * (8 * math.max(0.0, math.sin(2 * math.pi * 2.5 * v)));
    if (dragged) at += Offset(5 * math.sin(2 * math.pi * 4 * v), 0);
    return at;
  }

  /// [keys] at [u], easing from each to the next.
  static Offset _keyed(List<(double, Offset)> keys, double u) {
    for (var k = 0; k + 1 < keys.length; k++) {
      final (t0, a) = keys[k];
      final (t1, b) = keys[k + 1];
      if (u < t1) return Offset.lerp(a, b, _ease((u - t0) / (t1 - t0)))!;
    }
    return keys.last.$2;
  }

  static double _ease(double s) {
    final c = s.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// A hover's bob (each Dash its own: [phase]).
  static Offset _bob(double t, double phase) => Offset(3 * math.sin(t * 2 * math.pi * 0.7 + phase), 5 * math.sin(t * 2 * math.pi * 1.5 + phase));

  /// A smooth path through its points (Catmull-Rom).
  Path get path {
    final p = _p, path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i + 1 < p.length; i++) {
      final a = p[math.max(i - 1, 0)], b = p[i], c = p[i + 1], d = p[math.min(i + 2, p.length - 1)];
      final c1 = b + (c - a) / 6, c2 = c - (d - b) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, c.dx, c.dy);
    }
    return path;
  }
}
