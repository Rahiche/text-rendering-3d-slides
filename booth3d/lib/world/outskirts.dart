import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'volume.dart';
import 'walls.dart';

/// The land round the towns (they stood on a bare lawn): suburbs at their
/// edges — blocks of flats nearest, then houses along lanes — giving way
/// to fields, farm hamlets in their trees, woods towards the edge, and
/// mountains all round in the haze, Fuji to the west-south-west (ahead and
/// to the left on the drive to ICU City). The houses and fields are
/// different countries' by region ([_Style]): Japanese houses behind block
/// walls and rice paddies round ICU City; red-brick English houses with
/// slate roofs, chimneys and hedges, and fields between hedgerows, round
/// Flutter City and the towns south of it; German half-timbered houses
/// under steep red roofs, and open fields, round Engine Town.
///
/// Laid out once on a grid of 48 × 36 m plots, how built-up each is by how
/// near a town it is. All of it static, merged a material at a time,
/// casting no shadows (it's seen from afar, or going by).
/// Whose houses and fields: Japan's round ICU City (west), England's
/// round Flutter City and the towns south of it, Germany's round Engine
/// Town (east).
enum _Style {
  japan,
  english,
  german;

  static _Style at(double x) => x < -150 ? japan : (x > 150 ? german : english);
}

class Outskirts {
  Outskirts(this.scene);

  final Scene scene;

  /// Its buildings, for the talk's flights to go over rather than through.
  final volumes = <Volume>[];

  static const _cellW = 48.0, _cellD = 36.0, _lane = 5.0, _edge = 640.0;

  /// The towns (x0, z0, x1, z1) and how far out their suburbs go.
  static const _towns = [
    (-140.0, -25.0, 140.0, 125.0, 110.0), // Flutter City
    (-362.0, -12.0, -207.0, 100.0, 85.0), // ICU City, north of the avenue
    (-362.0, 8.0, -185.0, 100.0, 85.0), // (its blocks further out behind)
    (228.0, -12.0, 345.0, 90.0, 85.0), // Engine Town
    (40.0, -250.0, 112.0, -150.0, 70.0), // Tradeoff Town
    (118.0, -272.0, 262.0, -138.0, 85.0), // Package Town
  ];

  /// Where nothing stands up: the ground behind the plaza (the camera's arc
  /// round the name: fields only), and where the drives into ICU City and
  /// Engine Town climb off the avenue to look at them.
  static const _lowOnly = [
    (-75.0, -80.0, 75.0, -30.0),
    (-255.0, -62.0, -200.0, -6.0),
    (200.0, -62.0, 255.0, -6.0),
  ];

  /// Trade-off Town's street (x from, to), south from the avenue to the
  /// edge (v_tradeoff.dart), its lamps either side.
  static const _street = (67.0, 83.0);

  /// Fuji: which way from the middle of things (as a bearing: x = sin, z =
  /// cos), how far, how high, how wide at its foot.
  static const _fujiBearing = -1.9, _fujiDist = 1180.0, _fujiH = 230.0, _fujiR = 420.0;

  late final PhysicallyBasedMaterial _walls, _plain, _water, _wet, _hills;
  late final List<PhysicallyBasedMaterial> _facades;
  late final PhysicallyBasedMaterial _asphalt;
  final _b = Batch();
  final _near = <(vm.Matrix4, vm.Vector4)>[], _far = <(vm.Matrix4, vm.Vector4)>[];
  var _solids = const <(vm.Vector3, vm.Vector3)>[];

  /// Builds it, clear of the towns and of [solids] (the city's own, such
  /// as the high-rises out in the fields).
  Future<void> init(List<(vm.Vector3, vm.Vector3)> solids) async {
    _walls = PhysicallyBasedMaterial()
      ..baseColorTexture = await paintedTexture(1536, 1536, _paintWalls)
      ..metallicFactor = 0
      ..roughnessFactor = 0.8;
    _plain = pbr(rgb(1, 1, 1), roughness: 0.85);
    _water = pbr(rgb(0.05, 0.075, 0.07), roughness: 0.05);
    _wet = pbr(rgb(1, 1, 1), roughness: 0.3);
    _hills = pbr(rgb(1, 1, 1), roughness: 1);
    _facades = await Future.wait([photoPbr('facade_tile'), photoPbr('facade_stone'), photoPbr('facade_clad'), photoPbr('facade_panel')]);
    _asphalt = await photoPbr('asphalt');

    _solids = solids;
    final ni = (_edge / _cellW).ceil(), nj = (_edge / _cellD).ceil();
    for (var i = -ni; i < ni; i++) {
      for (var j = -nj; j < nj; j++) {
        final x0 = i * _cellW, z0 = j * _cellD, x1 = x0 + _cellW, z1 = z0 + _cellD;
        final cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
        final out = math.sqrt(cx * cx + (cz - 20) * (cz - 20));
        if (out > _edge) continue;
        final u = _urban(cx, cz) + (rnd(i, j, 1) - 0.5) * 0.24;
        final low = _lowOnly.any((r) => x1 > r.$1 && x0 < r.$3 && z1 > r.$2 && z0 < r.$4);
        if (u > 0.62 && !low) {
          if (!_flats(i, j, x0, z0, x1, z1)) _houses(i, j, x0, z0, x1, z1);
          _lanes(x0, z0, x1, z1);
        } else if (u > 0.26 && !low) {
          _houses(i, j, x0, z0, x1, z1);
          _lanes(x0, z0, x1, z1);
        } else {
          if (!low && rnd(i, j, 2) < (out - 480) / 140) {
            _woods(i, j, x0, z0, x1, z1);
          } else if (!low && rnd(i, j, 3) < 0.06) {
            _hamlet(i, j, x0, z0, x1, z1);
          } else {
            _fields(i, j, x0, z0, x1, z1);
          }
          // Farm roads, a coarse grid of them.
          if (i % 3 == 0) _road(x0 - 2, z0, x0 + 2, z1);
          if (j % 4 == 0) _road(x0, z0 - 2, x1, z0 + 2);
        }
      }
    }
    _mountains();
    _fuji();
    _b.build(scene, 'outskirts', castsShadows: false, lightChannelMask: 0x01);
    _plantTrees();
    // (Capture aid: how much there is.)
    if (const String.fromEnvironment('BOOTH3D_TIMES') != '') debugPrint('OUTSKIRTS ${volumes.length} buildings, ${_near.length} + ${_far.length} trees');
  }

  /// Whether something from (x0, z0) to (x1, z1) would be in the way: on a
  /// town, the avenue, a side street, by one of the city's own solids; or,
  /// unless it's [flat] (a field, a road), where only flat things go.
  bool _blocked(double x0, double z0, double x1, double z1, {bool flat = false}) {
    for (final (a, b, c, d, _) in _towns) {
      if (x1 > a && x0 < c && z1 > b && z0 < d) return true;
    }
    if (!flat) {
      for (final (a, b, c, d) in _lowOnly) {
        if (x1 > a && x0 < c && z1 > b && z0 < d) return true;
      }
    }
    // The avenue (its pavements and street lights) and the side streets,
    // their whole length.
    if (z1 > -25 && z0 < -6) return true;
    for (final s in [-1.0, 1.0]) {
      final lo = math.min(s * 15.0, s * 30.0), hi = math.max(s * 15.0, s * 30.0);
      if (x1 > lo && x0 < hi) return true;
    }
    // Trade-off Town's street, south off the avenue (and its lamps).
    if (z0 < -22 && x1 > _street.$1 && x0 < _street.$2) return true;
    for (final (c, h) in _solids) {
      if (x1 > c.x - h.x - 12 && x0 < c.x + h.x + 12 && z1 > c.z - h.z - 12 && z0 < c.z + h.z + 12) return true;
    }
    return false;
  }

  /// A flat thing's rectangle (a field, a bund, a road) trimmed off the
  /// avenue and the side streets, so it runs up to them; null if what's
  /// left is in the way, or nothing.
  (double, double, double, double)? _fit(double x0, double z0, double x1, double z1) {
    if (z1 > -25 && z0 < -6) {
      final south = -25 - z0, north = z1 + 6;
      if (south <= 0.5 && north <= 0.5) return null;
      if (south >= north) {
        z1 = -25;
      } else {
        z0 = -6;
      }
    }
    for (final (lo, hi, south) in [(-30.0, -15.0, false), (15.0, 30.0, false), (_street.$1, _street.$2, true)]) {
      if (x1 > lo && x0 < hi && (!south || z0 < -22)) {
        final left = lo - x0, right = x1 - hi;
        if (left <= 0.5 && right <= 0.5) return null;
        if (left >= right) {
          x1 = lo;
        } else {
          x0 = hi;
        }
      }
    }
    return _blocked(x0, z0, x1, z1, flat: true) ? null : (x0, z0, x1, z1);
  }

  /// How built-up the land at (x, z) is: 1 at a town's edge, 0 as far out
  /// as its suburbs go.
  static double _urban(double x, double z) {
    var u = 0.0;
    for (final (x0, z0, x1, z1, reach) in _towns) {
      final dx = math.max(0.0, math.max(x0 - x, x - x1)), dz = math.max(0.0, math.max(z0 - z, z - z1));
      u = math.max(u, 1 - math.sqrt(dx * dx + dz * dz) / reach);
    }
    return u;
  }

  // ── Building blocks ───────────────────────────────────────────────────────

  /// A box [w]×[h]×[d], its middle at (x, y, z), painted [rgb] onto [m].
  void _box(Material m, double w, double h, double d, double x, double y, double z, int rgb) =>
      _b.add(m, painted(_unit.transformed(trs(vm.Vector3(x, y, z), s: vm.Vector3(w, h, d))), v4(hex3(rgb))));

  /// A unit cube's mesh, scaled into every box out here.
  static final _unit = CuboidGeometry(vm.Vector3(1, 1, 1)).extractMeshData();

  /// Asphalt from (x0, z0) to (x1, z1), its photograph at 3 m a tile, its
  /// top a little over the lawn.
  void _road(double ax, double az, double bx, double bz) {
    final fit = _fit(ax, az, bx, bz);
    if (fit == null) return;
    final (x0, z0, x1, z1) = fit;
    final d = _unit.transformed(trs(vm.Vector3((x0 + x1) / 2, -0.03, (z0 + z1) / 2), s: vm.Vector3(x1 - x0, 0.1, z1 - z0)));
    final uv = Float32List(d.vertexCount * 2);
    for (var k = 0; k < d.vertexCount; k++) {
      uv
        ..[k * 2] = d.positions[k * 3] / 3
        ..[k * 2 + 1] = d.positions[k * 3 + 2] / 3;
    }
    _b.add(_asphalt, painted(d, vm.Vector4(1, 1, 1, 1), uvs: uv));
  }

  /// The lanes along a built-up plot's south and west sides.
  void _lanes(double x0, double z0, double x1, double z1) {
    _road(x0, z0, x1, z0 + _lane);
    _road(x0, z0 + _lane, x0 + _lane, z1);
  }

  /// A tree out here at (x, z), [s] its size: a rounded crown on a trunk
  /// (instanced; [far]: a coarser crown, for the woods).
  void _tree(double x, double z, double s, int seed, {bool far = false}) {
    if (_blocked(x - 2.5 * s, z - 2.5 * s, x + 2.5 * s, z + 2.5 * s)) return;
    const greens = [0x3E7F45, 0x4B8C4A, 0x5E9B50, 0x356F3E, 0x2F5A3A];
    final m = trs(vm.Vector3(x, 0, z), rotY: rnd(seed, 1) * 6, s: vm.Vector3(s, s * (0.9 + 0.3 * rnd(seed, 2)), s));
    (far ? _far : _near).add((m, v4(hex3(greens[(rnd(seed, 3) * greens.length).floor() % greens.length]))));
  }

  // ── Suburbs ───────────────────────────────────────────────────────────────

  /// Blocks of flats (3–5 storeys, the city's photographed facades) with a
  /// parapet and a tank or a stair house on the roof; a car park, a tree or
  /// two. Whether any fitted.
  bool _flats(int i, int j, double x0, double z0, double x1, double z1) {
    var built = 0;
    final ax = x0 + _lane + 2, az = z0 + _lane + 2, bx = x1 - 2, bz = z1 - 2;
    final two = rnd(i, j, 4) < 0.5;
    final blocks = two ? [(ax, az, (ax + bx) / 2 - 2, az + 12.0), ((ax + bx) / 2 + 2, bz - 12, bx, bz)] : [(ax, az, bx, az + 13.0)];
    for (final (k, (a, b, c, d)) in blocks.indexed) {
      if (_blocked(a - 1, b - 1, c + 1, d + 1)) continue;
      final storeys = 3 + (rnd(i, j, 5 + k) * 3).floor();
      final h = storeys * 2.6 + 0.3, w = c - a, dd = d - b;
      final mx = (a + c) / 2, mz = (b + d) / 2;
      final m = _facades[(i * 7 + j * 3 + k).abs() % _facades.length];
      _b.add(m, painted(_facadeBox(w, h, dd, rnd(i, j, 8 + k), rnd(i, j, 9 + k)).transformed(vm.Matrix4.translation(vm.Vector3(mx, 0, mz))), vm.Vector4(1, 1, 1, 1)));
      for (final s in [-1.0, 1.0]) {
        _box(_plain, w + 0.3, 0.7, 0.2, mx, h + 0.35, mz + s * (dd / 2 + 0.05), 0xC2BBAE);
        _box(_plain, 0.2, 0.7, dd, mx + s * (w / 2 + 0.05), h + 0.35, mz, 0xC2BBAE);
      }
      _box(_plain, 2.6, 2.2, 2.6, a + 3, h + 1.1, d - 3, rnd(i, j, 10 + k) < 0.5 ? 0x8F8A80 : 0xB9B5AD);
      volumes.add(Volume(vm.Vector3(mx, (h + 2.2) / 2, mz), vm.Vector3(w / 2, (h + 2.2) / 2, dd / 2)));
      built++;
    }
    if (built == 0) return false;
    if (!two) {
      // The car park behind it, trees along its far side.
      _road(ax, az + 15, bx, bz);
      for (var k = 0; k < 3; k++) {
        _tree(ax + 4 + k * (bx - ax - 8) / 2, bz + 0.5, 1.1, i * 131 + j * 17 + k);
      }
    }
    return true;
  }

  /// A plot of houses: eight lots, each a two-storey house (a few one)
  /// behind a block wall with a gap for its gate, its tiled roof hipped or
  /// gabled; a tree in some gardens.
  void _houses(int i, int j, double x0, double z0, double x1, double z1) {
    const lotsX = 4, lotsZ = 2;
    final ax = x0 + _lane, az = z0 + _lane, lw = (x1 - ax) / lotsX, ld = (z1 - az) / lotsZ;
    final style = _Style.at((x0 + x1) / 2);
    final (roofs, plaster) = switch (style) {
      _Style.japan => (const [0x4A5560, 0x3A3F47, 0x6B4A3A, 0x34506E, 0x5A5550, 0x8A4B3A, 0x2F3A44], const [0xEDE6DA, 0xE3DCCF, 0xF2EFE8, 0xD9D2C4, 0xCFC6B6, 0xB9AE9C, 0xDDE2E4]),
      _Style.english => (const [0x4A4E55, 0x55595F, 0x3E434A, 0x5A5148], const [0xFFFFFF, 0xF2E8E0, 0xE8DCD2, 0xFFF4EC]),
      _Style.german => (const [0xA3452F, 0xB5532F, 0x8E3B2A, 0x9C4A34], const [0xFFFFFF, 0xF6EEDC, 0xF4E4E4, 0xEDE9D8, 0xE8F0E8]),
    };
    for (var lx = 0; lx < lotsX; lx++) {
      for (var lz = 0; lz < lotsZ; lz++) {
        final seed = (i * 1009 + j * 101 + lx * 7 + lz) & 0x7fffffff;
        if (rnd(seed, 1) < 0.1) continue; // an empty lot
        final cx = ax + (lx + 0.5) * lw, cz = az + (lz + 0.5) * ld;
        if (_blocked(cx - lw / 2, cz - ld / 2, cx + lw / 2, cz + ld / 2)) continue;
        // Its front: onto the lane (the south row) or the other way.
        final front = lz == 0 ? -1.0 : 1.0;
        final w = math.min(lw - 2.0, 7 + 2 * rnd(seed, 2)), d = math.min(ld - 4.5, 7 + 1.5 * rnd(seed, 3));
        final hz = cz + front * (ld / 2 - d / 2 - 3.0);
        final h = rnd(seed, 4) < 0.15 ? 2.9 : 5.7;
        _house(cx, hz, w, d, h, front, v4(hex3(plaster[(rnd(seed, 5) * plaster.length).floor() % plaster.length])), roofs[(rnd(seed, 6) * roofs.length).floor() % roofs.length], hip: style == _Style.japan && rnd(seed, 7) < 0.6, door: rnd(seed, 8) < 0.5, style: style);
        // Along the lot's front, its gate to one side: a block wall (Japan),
        // a hedge (England), a low stone wall (Germany).
        final fz = cz + front * (ld / 2 - 0.3), gate = cx + (rnd(seed, 9) < 0.5 ? -1 : 1) * lw / 4;
        final (edgeH, edgeD, edge) = switch (style) {
          _Style.japan => (1.1, 0.14, 0xB8B5AE),
          _Style.english => (1.15, 0.6, 0x3F6B3A),
          _Style.german => (0.8, 0.3, 0xBDB6A8),
        };
        for (final (a, b) in [(cx - lw / 2 + 0.15, gate - 1.3), (gate + 1.3, cx + lw / 2 - 0.15)]) {
          if (b - a > 0.3) _box(_plain, b - a, edgeH, edgeD, (a + b) / 2, edgeH / 2 - 0.12, fz, edge);
        }
        if (rnd(seed, 10) < 0.45) _tree(cx + (gate < cx ? 1 : -1) * (lw / 2 - 1.4), cz - front * (ld / 2 - 1.5), 0.75 + 0.3 * rnd(seed, 11), seed);
      }
    }
  }

  /// A house [w]×[d], its walls [h] high (two storeys, or one), its middle
  /// at (x, z), its front towards [front] (−1: south, 1: north): its walls
  /// in the wall atlas (the front with a door or without, the back, the
  /// sides) in its [plaster], under a roof of [roof].
  void _house(double x, double z, double w, double d, double h, double front, vm.Vector4 plaster, int roof, {required bool hip, required bool door, _Style style = _Style.japan}) {
    if (_blocked(x - w / 2 - 0.5, z - d / 2 - 0.5, x + w / 2 + 0.5, z + d / 2 + 0.5)) return;
    final pos = <double>[], nor = <double>[], uv = <double>[], idx = <int>[];
    // A wall from (ax, az) to (bx, bz) facing (nx, nz): the atlas's
    // [region] third across, its style's third down (its lower half only
    // for a single storey).
    final row = style.index / 3, rowEnd = (style.index + 1) / 3;
    void wall(double ax, double az, double bx, double bz, double nx, double nz, int region) {
      final v0 = pos.length ~/ 3, u0 = region / 3, u1 = (region + 1) / 3, vTop = h > 3 ? row : row + 0.5 / 3;
      for (final (px, py, pz, pu, pv) in [(ax, 0.0, az, u0, rowEnd), (bx, 0.0, bz, u1, rowEnd), (bx, h, bz, u1, vTop), (ax, h, az, u0, vTop)]) {
        pos.addAll([px, py, pz]);
        nor.addAll([nx, 0, nz]);
        uv.addAll([pu, pv]);
      }
      idx.addAll([v0, v0 + 1, v0 + 2, v0, v0 + 2, v0 + 3]);
    }

    final hw = w / 2, hd = d / 2;
    final fz = z + front * hd, bz = z - front * hd;
    // (Each wall's left end as seen from outside first, so its picture
    // reads the right way round.)
    wall(x - front * hw, fz, x + front * hw, fz, 0, front, door ? 0 : 1);
    wall(x + front * hw, bz, x - front * hw, bz, 0, -front, 1);
    wall(x + hw, z + hd, x + hw, z - hd, 1, 0, 2);
    wall(x - hw, z - hd, x - hw, z + hd, -1, 0, 2);
    final walls = _woundOut(MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), texCoords: Float32List.fromList(uv), indices: idx));
    _b.add(_walls, painted(walls, plaster));
    // A Japanese roof low, an English one steeper, a German one steep.
    final rise = switch (style) {
      _Style.japan => hip ? 1.6 : 1.9,
      _Style.english => 2.3,
      _Style.german => 3.4,
    };
    _b.add(_plain, painted(_roof(x, z, w + 0.9, d + 0.9, h, rise, hip: hip), v4(hex3(roof))));
    if (style == _Style.english) {
      // A chimney stack at one end of the ridge.
      final along = (w >= d ? vm.Vector3(1, 0, 0) : vm.Vector3(0, 0, 1)) * (math.max(w, d) / 2 - 1.1);
      _box(_plain, 0.7, 1.4, 0.7, x + along.x, h + rise - 0.2, z + along.z, 0x8E4A36);
      _box(_plain, 0.8, 0.12, 0.8, x + along.x, h + rise + 0.55, z + along.z, 0x6E3A2C);
    }
    volumes.add(Volume(vm.Vector3(x, (h + rise) / 2, z), vm.Vector3(hw + 0.45, (h + rise) / 2, hd + 0.45)));
  }

  /// A roof over a [w]×[d] footprint (its eaves included) from height [h],
  /// [rise] to its ridge along the longer side: hipped, or gabled (the
  /// gables shut in the roof's colour); its underside shut too.
  static MeshData _roof(double x, double z, double w, double d, double h, double rise, {required bool hip}) {
    final alongX = w >= d;
    final long = alongX ? w : d, short = alongX ? d : w;
    final hl = long / 2, hs = short / 2, hr = hip ? math.max(0.0, hl - hs) : hl, top = h + rise;
    vm.Vector3 at(double a, double b, double y) => alongX ? vm.Vector3(x + a, y, z + b) : vm.Vector3(x + b, y, z + a);
    final middle = vm.Vector3(x, h + rise * 0.3, z);
    final pos = <double>[], nor = <double>[], idx = <int>[];
    // A face of [pts] (a fan), its normal outwards (or down: the underside).
    void face(List<vm.Vector3> pts, {bool under = false}) {
      // (Newell's normal: sound even with two corners at one point.)
      final n = vm.Vector3.zero(), c = vm.Vector3.zero();
      for (var k = 0; k < pts.length; k++) {
        final p = pts[k], q = pts[(k + 1) % pts.length];
        n.x += (p.y - q.y) * (p.z + q.z);
        n.y += (p.z - q.z) * (p.x + q.x);
        n.z += (p.x - q.x) * (p.y + q.y);
        c.add(p);
      }
      c.scale(1 / pts.length);
      var list = pts;
      if (under ? n.y > 0 : n.dot(c - middle) < 0) {
        list = pts.reversed.toList();
        n.negate();
      }
      n.normalize();
      final v0 = pos.length ~/ 3;
      for (final p in list) {
        pos.addAll([p.x, p.y, p.z]);
        nor.addAll([n.x, n.y, n.z]);
      }
      for (var k = 1; k + 1 < list.length; k++) {
        idx.addAll([v0, v0 + k, v0 + k + 1]);
      }
    }

    face([at(-hl, -hs, h), at(-hr, 0, top), at(hr, 0, top), at(hl, -hs, h)]);
    face([at(hl, hs, h), at(hr, 0, top), at(-hr, 0, top), at(-hl, hs, h)]);
    face([at(-hl, hs, h), at(-hr, 0, top), at(-hl, -hs, h)]);
    face([at(hl, -hs, h), at(hr, 0, top), at(hl, hs, h)]);
    face([at(-hl, -hs, h), at(hl, -hs, h), at(hl, hs, h), at(-hl, hs, h)], under: true);
    return _woundOut(MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), texCoords: Float32List(pos.length ~/ 3 * 2), indices: idx));
  }

  /// [d] with each triangle wound to face the way its normals point
  /// (counter-clockwise seen from there).
  static MeshData _woundOut(MeshData d) {
    final p = d.positions, n = d.normals!, ix = d.indices!, out = <int>[];
    for (var t = 0; t + 2 < ix.length; t += 3) {
      final a = ix[t], b = ix[t + 1], c = ix[t + 2];
      final ab = vm.Vector3(p[b * 3] - p[a * 3], p[b * 3 + 1] - p[a * 3 + 1], p[b * 3 + 2] - p[a * 3 + 2]);
      final ac = vm.Vector3(p[c * 3] - p[a * 3], p[c * 3 + 1] - p[a * 3 + 1], p[c * 3 + 2] - p[a * 3 + 2]);
      final f = ab.cross(ac).dot(vm.Vector3(n[a * 3], n[a * 3 + 1], n[a * 3 + 2]));
      out.addAll(f >= 0 ? [a, b, c] : [a, c, b]);
    }
    return MeshData(positions: d.positions, vertexCount: d.vertexCount, normals: d.normals, texCoords: d.texCoords, colors: d.colors, indices: out);
  }

  /// A block [w]×[h]×[d] (its bottom middle at the origin) in a facade
  /// photograph at its real scale (8×8 bays of 1.7 × 2.6 m a texture),
  /// from [ou], [ov] into it; its roof plain.
  static MeshData _facadeBox(double w, double h, double d, double ou, double ov) {
    const cw = 1.7 * 8, ch = 2.6 * 8;
    ou = (ou * 8).floorToDouble() / 8;
    ov = (ov * 8).floorToDouble() / 8;
    final pos = <double>[], nor = <double>[], uv = <double>[], idx = <int>[];
    void quad(vm.Vector3 o, vm.Vector3 u, vm.Vector3 v, vm.Vector3 n, double uw, double vh, {bool roof = false}) {
      final base = pos.length ~/ 3;
      for (final (a, c) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]) {
        final p = o + u * (a * uw) + v * (c * vh);
        pos.addAll([p.x, p.y, p.z]);
        nor.addAll([n.x, n.y, n.z]);
        uv.addAll(roof ? [0.004, 0.004] : [ou + a * uw / cw, ov + (1 - c) * vh / ch]);
      }
      if (u.cross(v).dot(n) > 0) {
        idx.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
      } else {
        idx.addAll([base, base + 2, base + 1, base, base + 3, base + 2]);
      }
    }

    final x0 = -w / 2, z0 = -d / 2;
    final ux = vm.Vector3(1, 0, 0), uy = vm.Vector3(0, 1, 0), uz = vm.Vector3(0, 0, 1);
    quad(vm.Vector3(x0, 0, z0), ux, uy, vm.Vector3(0, 0, -1), w, h);
    quad(vm.Vector3(-x0, 0, -z0), -ux, uy, vm.Vector3(0, 0, 1), w, h);
    quad(vm.Vector3(x0, 0, -z0), -uz, uy, vm.Vector3(-1, 0, 0), d, h);
    quad(vm.Vector3(-x0, 0, z0), uz, uy, vm.Vector3(1, 0, 0), d, h);
    quad(vm.Vector3(x0, h, z0), ux, uz, vm.Vector3(0, 1, 0), w, d, roof: true);
    return MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), texCoords: Float32List.fromList(uv), indices: idx);
  }

  // ── The countryside ───────────────────────────────────────────────────────

  /// Fields: the plot in four, by region. Round ICU City rice paddies
  /// between low bunds, each planted (green over water), flooded bare
  /// (mirroring the sky), or grown tall; elsewhere wheat, rapeseed,
  /// pasture, a ploughed field, between hedgerows (England) or low grass
  /// strips (Germany).
  void _fields(int i, int j, double x0, double z0, double x1, double z1) {
    final style = _Style.at((x0 + x1) / 2);
    final bund = style == _Style.english ? 0x3A5F35 : 0x5E7A3A;
    final (bundH, bundW) = style == _Style.english ? (1.3, 0.9) : (0.36, 0.6);
    const y = 0.06;
    final mx = (x0 + x1) / 2 + (rnd(i, j, 11) - 0.5) * 8, mz = (z0 + z1) / 2 + (rnd(i, j, 12) - 0.5) * 6;
    for (final (a, b, c, d) in [(x0, z0, mx, mz), (mx, z0, x1, mz), (x0, mz, mx, z1), (mx, mz, x1, z1)]) {
      final k = rnd(a.round(), b.round(), 13);
      final fit = _fit(a, b, c, d);
      if (fit == null) continue;
      final field = _flat(fit.$1 + 0.3, fit.$2 + 0.3, fit.$3 - 0.3, fit.$4 - 0.3, y);
      if (style != _Style.japan) {
        _b.add(_plain, painted(field, v4(hex3(k < 0.3 ? 0xCDAE52 : k < 0.45 ? 0xE2CB35 : k < 0.8 ? 0x6E9A48 : k < 0.9 ? 0x7A5A3E : 0x5E8C3E))));
      } else if (k < 0.6) {
        _b.add(_wet, painted(field, v4(hex3(k < 0.3 ? 0x5C7A48 : 0x4E6E46))));
      } else if (k < 0.8) {
        _b.add(_water, painted(field, vm.Vector4(1, 1, 1, 1)));
      } else {
        _b.add(_plain, painted(field, v4(hex3(k < 0.93 ? 0x7FA344 : 0x9BAE52))));
      }
    }
    // The bunds (or hedgerows): round each field (where it is); now and
    // then a tree in an English hedgerow.
    for (final (n, (a, b, c, d)) in [(x0, mz, mx, mz), (mx, mz, x1, mz), (mx, z0, mx, mz), (mx, mz, mx, z1), (x0, z0, mx, z0), (mx, z0, x1, z0), (x0, z0, x0, mz), (x0, mz, x0, z1)].indexed) {
      final w = math.max(c - a, bundW), d0 = math.max(d - b, bundW);
      final fit = _fit((a + c) / 2 - w / 2, (b + d) / 2 - d0 / 2, (a + c) / 2 + w / 2, (b + d) / 2 + d0 / 2);
      if (fit == null) continue;
      final (f0, g0, f1, g1) = fit;
      _box(_plain, f1 - f0, bundH, g1 - g0, (f0 + f1) / 2, bundH / 2 - 0.12, (g0 + g1) / 2, bund);
      if (style == _Style.english && rnd(i * 31 + n, j, 17) < 0.3) _tree((f0 + f1) / 2, (g0 + g1) / 2, 1.2 + 0.4 * rnd(i, j * 7 + n, 18), i * 211 + j * 13 + n);
    }
  }

  /// A flat rectangle facing up at height [y].
  static MeshData _flat(double x0, double z0, double x1, double z1, double y) => MeshData(
    positions: Float32List.fromList([x0, y, z0, x0, y, z1, x1, y, z1, x1, y, z0]),
    vertexCount: 4,
    normals: Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]),
    texCoords: Float32List(8),
    indices: [0, 1, 2, 0, 2, 3],
  );

  /// A farm hamlet, by region: a few farmhouses (under dark hipped roofs,
  /// in Japan) and a storehouse or a barn, in a ring of trees.
  void _hamlet(int i, int j, double x0, double z0, double x1, double z1) {
    final cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    final style = _Style.at(cx);
    final n = 2 + (rnd(i, j, 14) * 2).floor();
    final (plaster, roof) = switch (style) {
      _Style.japan => (0xD8CFC0, 0x2F3A44),
      _Style.english => (0xF2E8E0, 0x4A4E55),
      _Style.german => (0xF6EEDC, 0xA3452F),
    };
    for (var k = 0; k < n; k++) {
      final seed = i * 37 + j * 11 + k;
      _house(cx - 12 + k * 11 + (rnd(seed, 1) - 0.5) * 3, cz + (rnd(seed, 2) - 0.5) * 8, 9 + 2 * rnd(seed, 3), 8, style == _Style.japan ? 3.2 : 5.7, -1, v4(hex3(plaster)), roof, hip: style == _Style.japan, door: true, style: style);
    }
    _house(cx + 14, cz + 9, style == _Style.japan ? 4.5 : 8, style == _Style.japan ? 4.5 : 6, 4.6, -1, v4(hex3(style == _Style.japan ? 0xF2EFE8 : 0x9A7B5E)), style == _Style.german ? 0x8E3B2A : 0x3A3F47, hip: false, door: false, style: style);
    for (var k = 0; k < 12; k++) {
      final a = k / 12 * math.pi * 2 + rnd(i, j, 20 + k) * 0.4;
      _tree(cx + math.cos(a) * 21, cz + math.sin(a) * 15, 1.3 + 0.5 * rnd(i, j, 40 + k), i * 53 + j * 29 + k);
    }
  }

  /// Woods towards the edge: big trees close together.
  void _woods(int i, int j, double x0, double z0, double x1, double z1) {
    for (var k = 0; k < 8; k++) {
      final seed = i * 977 + j * 131 + k;
      _tree(x0 + 4 + rnd(seed, 4) * (x1 - x0 - 8), z0 + 4 + rnd(seed, 5) * (z1 - z0 - 8), 2.0 + rnd(seed, 6), seed, far: true);
    }
  }

  void _plantTrees() {
    final leaves = pbr(rgb(1, 1, 1), roughness: 0.9), bark = pbr(v4(hex3(0x5B4E44)), roughness: 0.9);
    final trunk = CylinderGeometry(bottomRadius: 0.14, topRadius: 0.1, height: 1, radialSegments: 6);
    for (final (name, list, crown) in [
      ('near', _near, IcosphereGeometry(radius: 1, subdivisions: 1)),
      ('far', _far, IcosphereGeometry(radius: 1, subdivisions: 0)),
    ]) {
      if (list.isEmpty) continue;
      final crowns = InstancedMesh(geometry: crown, material: leaves), trunks = InstancedMesh(geometry: trunk, material: bark);
      for (final (m, c) in list) {
        crowns
          ..addInstance(m * trs(vm.Vector3(0, 3.6, 0), s: vm.Vector3(2.1, 2.2, 2.1)), color: c)
          ..addInstance(m * trs(vm.Vector3(0.9, 4.6, 0.5), s: vm.Vector3(1.4, 1.5, 1.4)), color: vm.Vector4(c.x * 1.12, c.y * 1.12, c.z * 1.12, 1));
        trunks.addInstance(m * trs(vm.Vector3(0, 1.3, 0), s: vm.Vector3(1, 2.6, 1)));
      }
      for (final (part, mesh) in [('crowns', crowns), ('trunks', trunks)]) {
        scene.add(
          Node(name: 'outskirts $name tree $part')
            ..lightChannelMask = 0x01
            ..castsShadows = false
            ..addComponent(InstancedMeshComponent(mesh)),
        );
      }
    }
  }

  // ── The mountains ─────────────────────────────────────────────────────────

  /// Mountains all round past the fields: a ring of ridges rising out of
  /// the plain, wooded below and slate-blue above (lightened by the haze),
  /// low where Fuji stands behind.
  void _mountains() {
    const steps = 360, centre = (0.0, 20.0);
    const rings = [(680.0, 0.0), (720.0, 0.1), (780.0, 0.35), (830.0, 0.65), (880.0, 1.0), (940.0, 0.8), (1020.0, 0.45)];
    double ridge(double a) {
      var h = 55.0;
      for (final (f, amp, ph) in const [(3.0, 30.0, 0.4), (7.0, 24.0, 1.7), (13.0, 14.0, 2.9), (29.0, 7.0, 0.8)]) {
        h += amp * (0.5 + 0.5 * math.sin(a * f + ph));
      }
      // (Low before Fuji, so it stands clear.)
      final da = math.atan2(math.sin(a - _fujiBearing), math.cos(a - _fujiBearing));
      return h * (1 - 0.7 * math.exp(-(da / 0.3) * (da / 0.3)));
    }

    final pos = <double>[], col = <double>[], idx = <int>[];
    for (var s = 0; s <= steps; s++) {
      final a = s / steps * math.pi * 2, top = ridge(a);
      for (final (r, k) in rings) {
        final y = k == 0 ? -2.0 : top * k + 5 * math.sin(a * 41 + r * 0.05);
        pos.addAll([centre.$1 + math.sin(a) * r, y, centre.$2 + math.cos(a) * r]);
        final c = hex3(y < 35 ? 0x5C7470 : y < 80 ? 0x5A7083 : 0x4F657B);
        col.addAll([c.x, c.y, c.z, 1]);
      }
    }
    final n = rings.length;
    for (var s = 0; s < steps; s++) {
      for (var k = 0; k + 1 < n; k++) {
        final a = s * n + k, b = (s + 1) * n + k;
        idx.addAll([a, a + 1, b + 1, a, b + 1, b]);
      }
    }
    _b.add(_hills, _smooth(pos, col, idx));
  }

  /// Fuji: a cone with concave slopes, snow over its upper third, out
  /// beyond the ring.
  void _fuji() {
    const steps = 96, rings = 14;
    final cx = math.sin(_fujiBearing) * _fujiDist, cz = 20 + math.cos(_fujiBearing) * _fujiDist;
    final pos = <double>[], col = <double>[], idx = <int>[];
    for (var s = 0; s <= steps; s++) {
      final a = s / steps * math.pi * 2;
      for (var k = 0; k <= rings; k++) {
        // From the summit's rim (a little crater, flat-topped) out to the
        // foot.
        final f = k / rings, r = 18 + (_fujiR - 18) * f;
        final y = k == rings ? -2.0 : _fujiH * math.pow(1 - f, 1.8) + 3 * math.sin(a * 23 + f * 9);
        pos.addAll([cx + math.sin(a) * r, y.toDouble(), cz + math.cos(a) * r]);
        // Snow down the upper slopes, in streaks.
        final snow = y > _fujiH * (0.62 + 0.08 * math.sin(a * 11));
        final c = hex3(snow ? 0xEEF2F6 : y < 60 ? 0x667D8C : 0x5B6F84);
        col.addAll([c.x, c.y, c.z, 1]);
      }
    }
    for (var s = 0; s < steps; s++) {
      for (var k = 0; k < rings; k++) {
        final a = s * (rings + 1) + k, b = (s + 1) * (rings + 1) + k;
        idx.addAll([a, a + 1, b + 1, a, b + 1, b]);
      }
    }
    _b.add(_hills, _smooth(pos, col, idx));
  }

  /// Mesh data from [pos], [col] and [idx], its normals averaged from the
  /// faces round each vertex, each face wound to face up and out.
  static MeshData _smooth(List<double> pos, List<double> col, List<int> idx) {
    final nor = Float32List(pos.length);
    for (var t = 0; t < idx.length; t += 3) {
      final a = idx[t], b = idx[t + 1], c = idx[t + 2];
      final pa = vm.Vector3(pos[a * 3], pos[a * 3 + 1], pos[a * 3 + 2]);
      final fn = (vm.Vector3(pos[b * 3], pos[b * 3 + 1], pos[b * 3 + 2]) - pa).cross(vm.Vector3(pos[c * 3], pos[c * 3 + 1], pos[c * 3 + 2]) - pa);
      // (Up, whichever way the face was listed.)
      if (fn.y < 0) fn.negate();
      for (final v in [a, b, c]) {
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
    return _woundOut(MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: nor, texCoords: Float32List(pos.length ~/ 3 * 2), colors: Float32List.fromList(col), indices: idx));
  }

  // ── Paintings ─────────────────────────────────────────────────────────────

  /// The houses' walls, a 512 px square each, a third across for the front
  /// (with its door), the back and a side, a third down for each region's
  /// (two storeys a wall, a single storey taking the lower half): Japan's
  /// near-white plaster with aluminium windows and a balcony; England's
  /// red brick, white sash windows under stone lintels, a black door with
  /// a fanlight; Germany's half-timbering, dark beams over white plaster,
  /// windows with green shutters and flower boxes. (The house's colour
  /// tints it.)
  static void _paintWalls(Canvas c, Size s) {
    final cell = s.width / 3;
    for (var row = 0; row < 3; row++) {
      for (var k = 0; k < 3; k++) {
        final r = Rect.fromLTWH(k * cell, row * cell, cell, cell);
        c
          ..save()
          ..clipRect(r);
        switch (row) {
          case 0:
            paintJapanWall(c, r, k);
          case 1:
            paintBrickWall(c, r, k);
          default:
            paintTimberWall(c, r, k);
        }
        c.restore();
      }
    }
  }
}
