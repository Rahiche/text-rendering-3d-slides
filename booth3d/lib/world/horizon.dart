import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';

/// What stands far off round the towns, in front of the mountains, from
/// all over (the talk is about every language), old or common kinds of
/// landmark: west, a castle keep on its walled hill, and Pisa's leaning
/// tower beside Fuji (one Japanese landmark in a view is enough); north
/// of the city, a big wheel; east, a castle on a wooded crag, a TV tower
/// and a wind farm. The wheel and the turbines turn.
///
/// They stand where the talk's cameras look: a whole run's camera log
/// (CAM lines) scored by how long each far spot is in view beside the
/// card: north most, then east, then west.
class Horizon {
  Horizon(this.scene);

  final Scene scene;

  /// The ground each one takes (centre, half extents), for the land round
  /// the towns to keep clear of.
  final solids = <(vm.Vector3, vm.Vector3)>[];

  final _b = Batch();
  late final PhysicallyBasedMaterial _matte, _steel, _land;

  /// What turns: its node, where it stands, how fast about its local z
  /// (rad/s), where it starts.
  final _turning = <(Node, vm.Matrix4, double, double)>[];

  /// Where they stand: a bearing from the middle of things (degrees from
  /// north, clockwise, as the outskirts' Fuji), how far. (The bell tower:
  /// on the drive into ICU City, between Fuji and the town's sign.)
  static final castleJa = _far(-75, 580), belltower = _far(-101.5, 600), wheel = _far(10, 600), castleDe = _far(100, 620), tvTower = _far(125, 650);
  static final _turbines = [for (final (b, d) in const [(48.0, 640.0), (54.0, 600.0), (60.0, 655.0), (66.0, 612.0), (72.0, 648.0)]) _far(b, d)];

  static vm.Vector3 _far(double deg, double dist) {
    final a = deg * math.pi / 180;
    return vm.Vector3(math.sin(a) * dist, 0, 20 + math.cos(a) * dist);
  }

  /// The yaw that turns a thing's front (local −z) to the city.
  static double _toCity(vm.Vector3 p) => math.atan2(p.x, p.z - 20);

  Future<void> init() async {
    _matte = pbr(rgb(1, 1, 1), roughness: 0.85);
    _steel = pbr(rgb(1, 1, 1), roughness: 0.35, metallic: 0.5);
    _land = pbr(rgb(1, 1, 1), roughness: 1);
    _castleJa();
    _leaningTower();
    _wheel();
    _castleDe();
    _tvTower();
    _windFarm();
    _b.build(scene, 'horizon', castsShadows: false, lightChannelMask: 0x01);
  }

  /// The wheel and the rotors at [t] (s).
  void update(double t) {
    for (final (node, base, speed, phase) in _turning) {
      node.localTransform = base * vm.Matrix4.rotationZ(phase + speed * t);
    }
  }

  // ── Pieces ────────────────────────────────────────────────────────────────

  static final _unit = CuboidGeometry(vm.Vector3(1, 1, 1)).extractMeshData();

  /// A box [w]×[h]×[d] in [f], its bottom's middle at (x, y, z).
  void _box(vm.Matrix4 f, double w, double h, double d, double x, double y, double z, int rgb, {Material? m}) =>
      _b.add(m ?? _matte, painted(_unit.transformed(f * trs(vm.Vector3(x, y + h / 2, z), s: vm.Vector3(w, h, d))), v4(hex3(rgb))));

  /// An upright cylinder (or cone) in [f], its bottom's middle at (x, y, z).
  void _cyl(vm.Matrix4 f, double r0, double r1, double h, double x, double y, double z, int rgb, {int sides = 16, Material? m}) => _b.add(
    m ?? _matte,
    part(CylinderGeometry(bottomRadius: r0, topRadius: r1, height: h, radialSegments: sides), f * vm.Matrix4.translation(vm.Vector3(x, y + h / 2, z)), v4(hex3(rgb))),
  );

  /// [d] put in [f] at (x, y, z), turned [rotY].
  void _put(vm.Matrix4 f, MeshData d, double x, double y, double z, int rgb, {double rotY = 0}) =>
      _b.add(_matte, painted(d.transformed(f * trs(vm.Vector3(x, y, z), rotY: rotY)), v4(hex3(rgb))));

  /// A square beam [t] thick from [a] to [b].
  static MeshData _beam(vm.Vector3 a, vm.Vector3 b, double t, int rgb) {
    final d = b - a, len = d.length;
    final q = vm.Quaternion.fromTwoVectors(vm.Vector3(0, 1, 0), d / len);
    return painted(_unit.transformed(trsQ((a + b) / 2, q, vm.Vector3(t, len, t))), v4(hex3(rgb)));
  }

  /// A frustum up local y: a [w0]×[d0] rectangle at its foot, [w1]×[d1]
  /// [h] over it (a roof, a battered wall, a blade; a zero top is a
  /// pyramid's point). Flat faces, each wound to face out.
  static MeshData _frustum(double w0, double d0, double w1, double d1, double h) {
    final pos = <double>[], nor = <double>[], idx = <int>[];
    final mid = vm.Vector3(0, h / 2, 0);
    void face(List<vm.Vector3> ps) {
      var n = (ps[1] - ps[0]).cross(ps[2] - ps[0]);
      if (n.length2 < 1e-10) n = (ps[2] - ps[0]).cross(ps[3] - ps[0]);
      if (n.length2 < 1e-10) return;
      final c = ps.fold(vm.Vector3.zero(), (s, p) => s + p) / ps.length.toDouble();
      if (n.dot(c - mid) < 0) {
        ps = ps.reversed.toList();
        n.negate();
      }
      n.normalize();
      final base = pos.length ~/ 3;
      for (final p in ps) {
        pos.addAll([p.x, p.y, p.z]);
        nor.addAll([n.x, n.y, n.z]);
      }
      idx.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    vm.Vector3 lo(double sx, double sz) => vm.Vector3(sx * w0 / 2, 0, sz * d0 / 2);
    vm.Vector3 hi(double sx, double sz) => vm.Vector3(sx * w1 / 2, h, sz * d1 / 2);
    face([lo(-1, -1), lo(1, -1), hi(1, -1), hi(-1, -1)]);
    face([lo(1, -1), lo(1, 1), hi(1, 1), hi(1, -1)]);
    face([lo(1, 1), lo(-1, 1), hi(-1, 1), hi(1, 1)]);
    face([lo(-1, 1), lo(-1, -1), hi(-1, -1), hi(-1, 1)]);
    if (w1 > 0 && d1 > 0) face([hi(-1, -1), hi(1, -1), hi(1, 1), hi(-1, 1)]);
    final n = pos.length ~/ 3;
    return MeshData(positions: Float32List.fromList(pos), vertexCount: n, normals: Float32List.fromList(nor), texCoords: Float32List(n * 2), indices: idx);
  }

  /// A gable roof: [w] along local x, its ridge [h] over the eaves, [d]
  /// deep; the gables closed.
  static MeshData _gable(double w, double h, double d) => _frustum(w, d, w, 0.001, h);

  /// A hill round [at]: [r] out to its foot, [h] high, flat on top out to
  /// [top] (for what stands there), the steeper under its brow the more
  /// [crag]; wooded, [rock] showing under the brow.
  void _hill(vm.Vector3 at, double r, double h, double top, {double crag = 1.8, bool rock = false}) {
    const steps = 72, rings = 14;
    final pos = <double>[], col = <double>[], idx = <int>[];
    for (var s = 0; s <= steps; s++) {
      final a = s / steps * math.pi * 2;
      final wob = 1 + 0.07 * math.sin(a * 3 + at.x) + 0.04 * math.sin(a * 7 + at.z);
      for (var k = 0; k <= rings + 1; k++) {
        // (Ring 0: the top's middle; 1: the brow; out to the foot, under
        // the ground.)
        final f = k == 0 ? 0.0 : (k - 1) / rings;
        final rr = k == 0 ? 0.0 : (top + (r - top) * f) * wob;
        final y = k == 0 ? h : (k == rings + 1 ? -1.0 : h * math.pow(1 - f, crag) + 2.2 * math.sin(a * 11 + f * 7) * f * (1 - f) * 4);
        pos.addAll([at.x + math.sin(a) * rr, y.toDouble(), at.z + math.cos(a) * rr]);
        final c = hex3(
          k <= 1
              ? 0x6E7E5B
              : rock && f < 0.16
              ? 0x857F74
              : f > 0.86
              ? 0x5B744F
              : math.sin(a * 13 + f * 9) > 0.25
              ? 0x41603F
              : 0x37533A,
        );
        col.addAll([c.x, c.y, c.z, 1]);
      }
    }
    const n = rings + 2;
    for (var s = 0; s < steps; s++) {
      for (var k = 0; k + 1 < n; k++) {
        final a = s * n + k, b = (s + 1) * n + k;
        idx.addAll([a, a + 1, b + 1, a, b + 1, b]);
      }
    }
    _b.add(_land, _upward(pos, col, idx));
    solids.add((at + vm.Vector3(0, h / 2, 0), vm.Vector3(r * 0.8, h / 2, r * 0.8)));
  }

  /// Mesh data for a height field from [pos], [col] and [idx]: every face
  /// wound to face up, normals averaged round each vertex.
  static MeshData _upward(List<double> pos, List<double> col, List<int> idx) {
    vm.Vector3 p(int v) => vm.Vector3(pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]);
    final nor = Float32List(pos.length);
    for (var t = 0; t < idx.length; t += 3) {
      var fn = (p(idx[t + 1]) - p(idx[t])).cross(p(idx[t + 2]) - p(idx[t]));
      if (fn.y < 0) {
        final b = idx[t + 1];
        idx[t + 1] = idx[t + 2];
        idx[t + 2] = b;
        fn = -fn;
      }
      for (final v in [idx[t], idx[t + 1], idx[t + 2]]) {
        nor[v * 3] += fn.x;
        nor[v * 3 + 1] += fn.y;
        nor[v * 3 + 2] += fn.z;
      }
    }
    for (var v = 0; v < nor.length; v += 3) {
      final l = math.sqrt(nor[v] * nor[v] + nor[v + 1] * nor[v + 1] + nor[v + 2] * nor[v + 2]);
      if (l > 0) {
        nor[v] /= l;
        nor[v + 1] /= l;
        nor[v + 2] /= l;
      }
    }
    final n = pos.length ~/ 3;
    return MeshData(positions: Float32List.fromList(pos), vertexCount: n, normals: nor, texCoords: Float32List(n * 2), colors: Float32List.fromList(col), indices: idx);
  }

  // ── West: a castle keep, a leaning tower ─────────────────────────────────

  /// A Japanese castle on its hill: a battered stone base, the keep's five
  /// white storeys each under a wide dark roof (the top one hipped), two
  /// turrets, white walls along the brow.
  void _castleJa() {
    final o = castleJa;
    const hill = 30.0;
    _hill(o, 150, hill, 42, crag: 1.5);
    final f = trs(o + vm.Vector3(0, hill - 0.4, 0), rotY: _toCity(o) + 0.4);
    const white = 0xF1EFE8, roof = 0x3B4249, stone = 0x8F8B82;
    _put(f, _frustum(40, 32, 31, 24, 13), 0, 0, 0, stone);
    var y = 13.0;
    const tiers = [(26.0, 20.0, 4.6), (22.0, 17.0, 4.2), (18.0, 14.0, 4.0), (14.0, 11.0, 3.8), (10.5, 8.5, 3.8)];
    for (final (i, (w, d, h)) in tiers.indexed) {
      final last = i == tiers.length - 1;
      _box(f, w, h + 0.8, d, 0, y, 0, white);
      // Its roof, flared: wide shallow eaves, then steeper up to the next
      // storey (the top one hipped to a short ridge).
      _put(f, _frustum(w + 6.0, d + 6.0, w + 2.2, d + 2.2, 1.1), 0, y + h, 0, roof);
      _put(f, last ? _frustum(w + 2.2, d + 2.2, w * 0.4, 0.4, 4.6) : _frustum(w + 2.2, d + 2.2, w - 2.4, d - 2.4, 2.0), 0, y + h + 1.1, 0, roof);
      // A gable over the eaves, to the front on some storeys, to the
      // sides on others.
      if (i == 0 || i == 2) _put(f, _gable(5.0, 2.8, w * 0.4), 0, y + h + 0.4, -(d / 2 + 1.6), roof, rotY: math.pi / 2);
      if (i == 1 || i == 3) {
        for (final sx in [-1.0, 1.0]) {
          _put(f, _gable(d * 0.45, 2.6, 4.6), sx * (w / 2 + 1.5), y + h + 0.4, 0, roof);
        }
      }
      y += h + 2.4;
    }
    // Two turrets on the base's corners, their own little roofs.
    for (final (x, z) in const [(-25.0, -17.0), (24.0, 14.0)]) {
      _put(f, _frustum(10, 8, 8.4, 6.4, 5), x, 0, z, stone);
      _box(f, 7.6, 5.0, 5.8, x, 5, z, white);
      _put(f, _frustum(11.2, 9.4, 3.4, 0.4, 3.6), x, 10, z, roof);
    }
    // White walls (with a dark coping) along the brow, round the front.
    for (var k = 0; k < 8; k++) {
      final a = -1.2 + k * 0.343;
      final x = math.sin(a) * -35, z = math.cos(a) * -35;
      _put(f, _frustum(12.4, 1.0, 12.4, 1.0, 2.4), x, 0, z, white, rotY: a);
      _put(f, _frustum(13.0, 1.8, 13.0, 0.3, 0.6), x, 2.4, z, roof, rotY: a);
    }
  }

  /// Pisa's bell tower, leaning south (side-on to the drive into ICU
  /// City): marble, a blind-arcaded ground storey, six open galleries
  /// (white columns round a shadowed core), the belfry; on its lawn. Half
  /// as tall again as the real one, to read from this far.
  void _leaningTower() {
    final o = belltower;
    const marble = 0xEEE8DC, inset = 0xD8D1C4, shade = 0x8E887E;
    final g = trs(o);
    _cyl(g, 40, 40, 0.15, 0, 0, 0, 0x7FA05C, sides: 40);
    _cyl(g, 13, 12.2, 1.2, 0, 0, 0, marble, sides: 32);
    final f = trs(o + vm.Vector3(0, 0.9, 0), rotX: -0.07, s: vm.Vector3.all(1.4));
    // The ground storey, its blind arches.
    _cyl(f, 7.7, 7.7, 11, 0, 0, 0, marble, sides: 30);
    for (var k = 0; k < 15; k++) {
      final a = k / 15 * math.pi * 2;
      _put(f, _frustum(1.7, 0.2, 1.7, 0.2, 7.5), math.sin(a) * 7.72, 1.2, math.cos(a) * 7.72, inset, rotY: a);
    }
    // The galleries: a floor, the colonnade round the shadowed wall, the
    // arches' band over it.
    const storey = 6.4;
    for (var i = 0; i < 6; i++) {
      final y = 11.0 + i * storey;
      _cyl(f, 8.0, 8.0, 0.6, 0, y, 0, marble, sides: 30);
      _cyl(f, 6.0, 6.0, storey, 0, y, 0, shade, sides: 24);
      for (var k = 0; k < 30; k++) {
        final a = (k + 0.5) / 30 * math.pi * 2;
        _cyl(f, 0.3, 0.3, storey - 1.4, math.sin(a) * 7.35, y + 0.6, math.cos(a) * 7.35, marble, sides: 6);
      }
      _cyl(f, 7.9, 7.9, 0.8, 0, y + storey - 0.8, 0, marble, sides: 30);
    }
    // The belfry, its openings, the roof's rim.
    const top = 11.0 + 6 * storey;
    _cyl(f, 5.2, 5.2, 6.6, 0, top, 0, marble, sides: 24);
    for (var k = 0; k < 6; k++) {
      final a = k / 6 * math.pi * 2;
      _put(f, _frustum(1.5, 0.3, 1.5, 0.3, 3.2), math.sin(a) * 5.2, top + 1.8, math.cos(a) * 5.2, shade, rotY: a);
    }
    _cyl(f, 5.6, 5.0, 0.7, 0, top + 6.6, 0, marble, sides: 24);
    solids.add((o + vm.Vector3(0, 40, 0), vm.Vector3(28, 40, 28)));
  }

  // ── North: a big wheel ────────────────────────────────────────────────────

  /// A big observation wheel: a trussed rim on spokes, a capsule outside
  /// it every few metres, held from one side by an A-frame; it turns once
  /// in four minutes. A paved square at its foot, the boarding hall.
  void _wheel() {
    final o = wheel;
    const r = 50.0, hub = 56.0, w = 2.6, white = 0xEEF0F2;
    final yaw = _toCity(o) + 0.45;
    final base = trs(o + vm.Vector3(0, hub, 0), rotY: yaw);
    final parts = <MeshData>[];
    for (final z in [-w, w]) {
      parts.add(part(TorusGeometry(radius: r, tubeRadius: 0.8, radialSegments: 128, tubularSegments: 6), trs(vm.Vector3(0, 0, z), rotX: math.pi / 2), v4(hex3(white))));
    }
    const n = 32;
    for (var k = 0; k < n; k++) {
      final a = k / n * math.pi * 2, p = vm.Vector3(math.cos(a) * r, math.sin(a) * r, 0);
      parts
        ..add(_beam(p + vm.Vector3(0, 0, -w), p + vm.Vector3(0, 0, w), 0.6, white))
        ..add(_beam(vm.Vector3(0, 0, -w * 1.7), p + vm.Vector3(0, 0, -w), 0.3, 0xD5DADF))
        ..add(_beam(vm.Vector3(0, 0, w * 1.7), p + vm.Vector3(0, 0, w), 0.3, 0xD5DADF));
      final b = a + math.pi / n;
      parts.add(part(SphereGeometry(radius: 2.3, segments: 12, rings: 8), trs(vm.Vector3(math.cos(b) * (r + 3.3), math.sin(b) * (r + 3.3), 0), s: vm.Vector3(1, 1, 1.6)), v4(hex3(0xCFDCE6))));
    }
    parts.add(part(CylinderGeometry(bottomRadius: 2.6, topRadius: 2.6, height: w * 3.6, radialSegments: 16), trs(vm.Vector3.zero(), rotX: math.pi / 2), v4(hex3(0xB8BEC6))));
    final node = Node(name: 'big wheel', mesh: Mesh(merged(parts), pbr(rgb(1, 1, 1), roughness: 0.5, metallic: 0.1)), localTransform: base)..castsShadows = false;
    scene.add(node);
    _turning.add((node, base, 2 * math.pi / 240, 0.0));
    // The A-frame behind it, braced; the square, the hall.
    final at = base.transform3(vm.Vector3(0, 0, w * 2.2));
    final feet = [for (final s in [-1.0, 1.0]) trs(o, rotY: yaw).transform3(vm.Vector3(s * 24, 0, 36))];
    for (final g in feet) {
      _b.add(_matte, _beam(at, g, 2.4, white));
    }
    _b.add(_matte, _beam(at + (feet[0] - at) * 0.55, at + (feet[1] - at) * 0.55, 1.2, white));
    final f = trs(o, rotY: yaw);
    _cyl(f, 46, 46, 0.2, 0, 0, 6, 0xA7A49C, sides: 40);
    _box(f, 26, 5, 9, 0, 0, -9, 0x5D6670);
    solids.add((o + vm.Vector3(0, hub / 2, 0), vm.Vector3(55, hub / 2, 55)));
  }

  // ── East: a castle, a TV tower, a wind farm ───────────────────────────────

  /// A castle on a wooded crag (the romantic kind): a long white palace
  /// under a steep slate roof and its gabled wing, slender round towers
  /// with pointed roofs, a square keep, a red-brown gatehouse in front.
  void _castleDe() {
    final o = castleDe;
    const hill = 64.0;
    _hill(o, 175, hill, 34, crag: 2.2, rock: true);
    final f = trs(o + vm.Vector3(0, hill - 1.5, 0), rotY: _toCity(o) + 0.5);
    const wall = 0xE6E0D3, roof = 0x55606D, brick = 0xA35A40, dark = 0x2E3440;
    // On a battered stone platform that comes out of the crag at its brow.
    _put(f, _frustum(58, 50, 52, 44, 15), 2, -15, -4, 0x8C8579);
    _box(f, 40, 26, 13, 0, 0, 0, wall);
    _put(f, _gable(41, 11, 14.5), 0, 26, 0, roof);
    for (var row = 0; row < 4; row++) {
      for (var k = 0; k < 11; k++) {
        _box(f, 1.3, 2.6, 0.3, -17 + k * 3.4, 4 + row * 5.6, -6.6, dark);
      }
    }
    _box(f, 14, 30, 16, 10, 0, 11, wall);
    _put(f, _gable(17, 9, 14.5), 10, 30, 11, roof, rotY: math.pi / 2);
    for (final (x, z, r, h) in const [(-21.0, -5.0, 4.0, 44.0), (21.0, 7.0, 3.2, 36.0), (13.0, -8.5, 2.4, 33.0), (-21.0, 7.0, 2.8, 31.0)]) {
      _cyl(f, r, r, h, x, 0, z, wall);
      _cyl(f, r + 0.8, 0, r * 3.4, x, h, z, roof);
    }
    _box(f, 9, 54, 9, -5, 0, 13, wall);
    _put(f, _frustum(10.5, 10.5, 0, 0, 11), -5, 54, 13, roof);
    // The gatehouse at the platform's front edge; its towers.
    _box(f, 16, 9, 9, 8, 0, -21, brick);
    _put(f, _gable(16.5, 5, 9.5), 8, 9, -21, roof);
    for (final x in [-0.5, 16.5]) {
      _cyl(f, 2.2, 2.2, 15, x, 0, -24.5, brick);
      _cyl(f, 2.8, 0, 7, x, 15, -24.5, roof);
    }
  }

  /// A TV tower: a tapering concrete shaft, a steel sphere with its band
  /// of windows, an antenna in red and white.
  void _tvTower() {
    final o = tvTower, f = trs(o);
    const concrete = 0xC9C5BD;
    _cyl(f, 12, 7.5, 9, 0, 0, 0, concrete);
    _cyl(f, 7.0, 4.6, 104, 0, 8, 0, concrete);
    _b.add(_steel, part(SphereGeometry(radius: 12.5, segments: 32, rings: 18), f * vm.Matrix4.translation(vm.Vector3(0, 123, 0)), v4(hex3(0xB9BFC7))));
    _cyl(f, 12.9, 12.9, 3.4, 0, 121.6, 0, 0x3B414A, sides: 32);
    _cyl(f, 3.2, 2.4, 14, 0, 134, 0, concrete);
    for (var k = 0; k < 5; k++) {
      _cyl(f, 1.5 - k * 0.2, 1.3 - k * 0.2, 7, 0, 148 + k * 7.0, 0, k.isEven ? 0xC8102E : 0xF2F2F0, sides: 10);
    }
    _cyl(f, 22, 22, 0.2, 0, 0, 0, 0xA7A49C, sides: 32);
    solids.add((o + vm.Vector3(0, 30, 0), vm.Vector3(24, 30, 24)));
  }

  /// Wind turbines, all into the same south-westerly: white towers, the
  /// nacelles, three blades each, turning at their own phase.
  void _windFarm() {
    // (Rotors facing south-west: towards the city, a little off.)
    const yaw = 0.96, white = 0xEDEFF0, hub = 89.8;
    for (final (i, p) in _turbines.indexed) {
      final f = trs(p, rotY: yaw);
      _box(f, 9, 0.6, 9, 0, 0, 0, 0xA7A49C);
      _cyl(f, 2.1, 1.25, 88, 0, 0, 0, white, sides: 14);
      _box(f, 3.6, 3.6, 11, 0, 88, 1.6, white);
      final parts = <MeshData>[
        part(CylinderGeometry(bottomRadius: 1.8, topRadius: 0.3, height: 4, radialSegments: 12), trs(vm.Vector3(0, 0, -2.0), rotX: -math.pi / 2), v4(hex3(white))),
        for (var k = 0; k < 3; k++) painted(_frustum(2.9, 0.7, 0.7, 0.25, 45).transformed(vm.Matrix4.rotationZ(k * math.pi * 2 / 3) * vm.Matrix4.translation(vm.Vector3(0, 1.2, 0))), v4(hex3(white))),
      ];
      final base = f * vm.Matrix4.translation(vm.Vector3(0, hub, -4.2));
      final node = Node(name: 'wind turbine rotor', mesh: Mesh(merged(parts), _matte), localTransform: base)..castsShadows = false;
      scene.add(node);
      _turning.add((node, base, 1.15, i * 1.3));
      solids.add((p + vm.Vector3(0, 45, 0), vm.Vector3(8, 45, 8)));
    }
  }
}
