import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'city_plan.dart';
import 'kit.dart';
import 'shops.dart';
import 'trim.dart';

/// The skyline: blocks along the side streets (some carrying rooftop
/// signs) and the avenue, and a ring of high-rises far off — flats,
/// offices, old stepped towers — all finished round their facades
/// (trim.dart). All of it stands behind and beside the plaza, never
/// between it and the camera.
///
/// The facades are photographed walls with windows drawn into them
/// (tool/textures/facades.py: curtain-wall glass, dark panels, pale
/// cladding, old stone, concrete tile), laid at a real bay and storey. It is
/// all static, so it is merged: a draw a facade style for the whole skyline.
class CityTowers {
  CityTowers(this.scene);

  final Scene scene;

  /// Flat roofs facing the plaza, for rooftop signs: centre, roof height,
  /// facing (rotY), usable width.
  final roofs = <({vm.Vector3 at, double rotY, double width})>[];

  /// What a camera mustn't go into or look through: each building's box
  /// (centre, half extents).
  final solids = <(vm.Vector3, vm.Vector3)>[];

  final _batch = Batch();

  /// What stands back from the streets the talk walks (the infill, the far
  /// high-rises): no shadows from it. (Its shadows fell where no camera
  /// stays, and drawing them into every cascade cost the GPU about a sixth
  /// of a frame on the drives out of town.)
  final _far = Batch();
  final _styles = <PhysicallyBasedMaterial>[];
  late final _roofMat = pbr(rgb(1, 1, 1), roughness: 0.85), _trimMat = pbr(rgb(1, 1, 1), roughness: 0.62);
  late final ShopMaterials _shops;

  /// Window cell size in metres (a bay × a storey); a facade texture holds
  /// [_cells]×[_cells] of them.
  static const _cellW = 1.7, _cellH = 2.6, _cells = 8;

  /// The facade styles (assets/textures/facade_*).
  static const _styleNames = ['facade_glass', 'facade_panel', 'facade_clad', 'facade_stone', 'facade_tile'];

  // Facades: a style and a tint over it (sRGB; white: as photographed).
  static const _facades = [
    (0, 0xFFFFFF), // glass, neutral
    (1, 0xFFFFFF), // dark panels
    (2, 0xF2F0EC), // pale cladding
    (3, 0xFFFFFF), // old stone
    (4, 0xFFFFFF), // concrete tile
    (0, 0xD6E6E2), // glass, green-tinted
  ];

  Future<void> init() async {
    _styles.addAll(await Future.wait([for (final n in _styleNames) photoPbr(n)]));
    _shops = await ShopMaterials.make();
    _blocks();
    _infill();
    _highRises();
    _batch.build(scene, 'skyline', lightChannelMask: 0x01);
    _far.build(scene, 'skyline far', castsShadows: false, lightChannelMask: 0x01);
  }

  PhysicallyBasedMaterial _facadeMat(int kind) => _styles[_facades[kind % _facades.length].$1];

  vm.Vector4 _facadeColor(int kind) => v4(hex3(_facades[kind % _facades.length].$2));

  // ── Blocks along the side streets ─────────────────────────────────────────

  void _blocks() {
    // Along each side street, a row of blocks facing it (and so the plaza),
    // a taller row behind, and a row along the avenue beyond the corner.
    var seed = 0;
    for (final side in [-1.0, 1.0]) {
      final faceRot = side > 0 ? math.pi / 2 : -math.pi / 2; // face (−Z) towards the street
      var front = 0;
      var z = -8.5;
      while (z < 66) {
        seed++;
        final len = 9 + 6 * rnd(seed, 1);
        final h = 7 + 9 * rnd(seed, 2) + (z > 30 ? 4 : 0);
        final d = 9 + 4 * rnd(seed, 3);
        final x = side * (Plan.walkBlock + 1.2 + d / 2);
        // (A lot of the mini world's: no block.)
        if (!Plan.inLot(x, z + len / 2)) {
          _box(vm.Vector3(x, 0, z + len / 2), len, h, d, rotY: faceRot, seed: seed, kind: _blockKinds[seed % _blockKinds.length], shops: true);
          // Signs on every other front roof (the taller row behind carries
          // the rest, so from the plaza they stack at different heights).
          if ((front++).isEven) roofs.add((at: vm.Vector3(x, h + 0.5, z + len / 2), rotY: math.atan2(x, z + len / 2), width: math.min(len, d) * 0.92));
        }
        z += len + 1.2 + 2 * rnd(seed, 4);
      }
      z = 6.0;
      while (z < 72) {
        seed++;
        final len = 10 + 8 * rnd(seed, 1);
        final h = 15 + 12 * rnd(seed, 2);
        final d = 10 + 4 * rnd(seed, 3);
        final x = side * (Plan.walkBlock + 17 + d / 2 + 2 * rnd(seed, 5));
        _box(vm.Vector3(x, 0, z + len / 2), len, h, d, rotY: faceRot, seed: seed, kind: _blockKinds[(seed + 1) % _blockKinds.length]);
        roofs.add((at: vm.Vector3(x, h + 0.5, z + len / 2), rotY: math.atan2(x, z + len / 2), width: math.min(len, d) * 0.92));
        z += len + 2 + 3 * rnd(seed, 4);
      }
      var x = 46.0;
      while (x < 118) {
        seed++;
        final len = 10 + 6 * rnd(seed, 1);
        final h = 6 + 9 * rnd(seed, 2);
        const d = 10.0;
        // (Shops along the avenue; a café at the west corner nearest the
        // plaza, its terrace out on the pavement.)
        _box(vm.Vector3(side * (x + len / 2), 0, Plan.aveZ1 + 3.2 + d / 2), len, h, d, rotY: 0, seed: seed, kind: _blockKinds[(seed + 2) % _blockKinds.length], shops: true, cafe: side < 0 && x == 46);
        x += len + 1.5;
      }
    }
  }

  static const _blockKinds = [3, 4, 0, 5, 3, 1, 4, 2];

  /// The rest of the city out to its edges (Plan.infill): blocks of offices
  /// and flats, two buildings to a block, their own heights and depths,
  /// round paved courts and lanes (no traffic) — a city, not a lawn.
  void _infill() {
    var seed = 500;
    const bw = 26.0, bd = 28.0, lane = 8.0;
    for (final (x0, z0, x1, z1) in Plan.infill) {
      for (var x = x0 + 2; x + bw <= x1; x += bw + lane) {
        for (var z = z0 + 2; z + bd <= z1; z += bd + lane) {
          for (final half in [0.0, 1.0]) {
            seed++;
            final w = bw / 2 - 0.6, h = 12 + 18 * rnd(seed, 2), d = bd - 6 * rnd(seed, 3);
            _box(vm.Vector3(x + bw / 4 + half * bw / 2, 0, z + bd / 2), w, h, d, rotY: 0, seed: seed, kind: _blockKinds[seed % _blockKinds.length], into: _far);
          }
        }
      }
    }
  }

  /// A block of [len] (along its face) × [h] × [d], its face (local −Z)
  /// turned by [rotY]; windows in world scale, a plain roof with a parapet.
  /// With [shops] its ground floor is shops (shops.dart: the facade starts
  /// over them), [cafe] the last of them a café.
  void _box(vm.Vector3 at, double len, double h, double d, {required double rotY, required int seed, required int kind, bool shops = false, bool cafe = false, Batch? into}) {
    final b = into ?? _batch;
    final xf = trs(at, rotY: rotY);
    final across = rotY == 0 ? len : d, along = rotY == 0 ? d : len;
    solids.add((vm.Vector3(at.x, h / 2 + 0.5, at.z), vm.Vector3(across / 2, h / 2 + 0.5, along / 2)));
    final ou = (rnd(seed, 1) * _cells).floorToDouble() / _cells, ov = (rnd(seed, 2) * _cells).floorToDouble() / _cells;
    final up = shops ? shopFloor : 0.0;
    b.add(_facadeMat(kind), painted(_boxData(len, h - up, d, ou, ov).transformed(xf * vm.Matrix4.translation(vm.Vector3(0, up, 0))), _facadeColor(kind)));
    // Its finish: base (or shops), corners, cornice, parapet, rooftop
    // machinery.
    addTrim(b, _trimMat, xf, len, h, d, seed: seed, glass: _facades[kind % _facades.length].$1 == 0, base: !shops);
    if (shops) {
      addShops(b, _trimMat, _shops, xf, len, d, seed: seed, cafe: cafe, awning: (x0, x1) {
        final a = xf.transform3(vm.Vector3(x0, 0, -d / 2)), b = xf.transform3(vm.Vector3(x1, 0, -d / 2));
        return !Plan.streetTreeOver(a.x, a.z, b.x, b.z);
      });
    }
  }

  /// A box whose UVs count window cells (so every block shares one texture
  /// scale); the roof maps to a frame-coloured corner.
  MeshData _boxData(double w, double h, double d, double ou, double ov) {
    final pos = <double>[], nor = <double>[], uv = <double>[];
    final idx = <int>[];
    void quad(vm.Vector3 o, vm.Vector3 u, vm.Vector3 v, vm.Vector3 n, double uw, double vh, {bool roof = false}) {
      final base = pos.length ~/ 3;
      for (final (a, b) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]) {
        final p = o + u * (a * uw) + v * (b * vh);
        pos.addAll([p.x, p.y, p.z]);
        nor.addAll([n.x, n.y, n.z]);
        if (roof) {
          uv.addAll([0.004, 0.004]);
        } else {
          uv.addAll([ou + a * uw / (_cellW * _cells), ov + (1 - b) * vh / (_cellH * _cells)]);
        }
      }
      // Counter-clockwise seen from n.
      if (u.cross(v).dot(n) > 0) {
        idx.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
      } else {
        idx.addAll([base, base + 2, base + 1, base, base + 3, base + 2]);
      }
    }

    final x0 = -w / 2, z0 = -d / 2;
    final ux = vm.Vector3(1, 0, 0), uy = vm.Vector3(0, 1, 0), uz = vm.Vector3(0, 0, 1);
    quad(vm.Vector3(x0, 0, z0), ux, uy, vm.Vector3(0, 0, -1), w, h); // front (−Z)
    quad(vm.Vector3(-x0, 0, -z0), -ux, uy, vm.Vector3(0, 0, 1), w, h); // back
    quad(vm.Vector3(x0, 0, -z0), -uz, uy, vm.Vector3(-1, 0, 0), d, h); // left
    quad(vm.Vector3(-x0, 0, z0), uz, uy, vm.Vector3(1, 0, 0), d, h); // right
    quad(vm.Vector3(x0, h, z0), ux, uz, vm.Vector3(0, 1, 0), w, d, roof: true); // roof
    return MeshData(
      positions: Float32List.fromList(pos),
      vertexCount: pos.length ~/ 3,
      normals: Float32List.fromList(nor),
      texCoords: Float32List.fromList(uv),
      indices: idx,
    );
  }

  // ── High-rises ────────────────────────────────────────────────────────────

  /// The far ring's towers, west to east: their tiers from the ground up
  /// (width, height, depth; each set back over the one below), facade, and
  /// a mast on top (m; 0, none).
  static const _rises = [
    ([(20.0, 50.0, 20.0), (15.0, 4.0, 15.0)], 2, 0.0), // flats, pale cladding
    ([(28.0, 9.0, 22.0), (18.0, 42.0, 16.0)], 0, 9.0), // offices over a podium, glass
    ([(36.0, 33.0, 12.0)], 4, 0.0), // a slab of flats, concrete tile
    ([(22.0, 26.0, 22.0), (17.0, 13.0, 17.0), (11.0, 8.0, 11.0)], 3, 8.0), // stepped, old stone
    ([(20.0, 48.0, 20.0), (14.0, 5.0, 14.0)], 1, 0.0), // dark panels
    ([(30.0, 39.0, 14.0)], 2, 0.0), // a slab, pale cladding
    ([(16.0, 56.0, 16.0)], 5, 10.0), // green glass, the tallest
    ([(24.0, 29.0, 20.0), (16.0, 12.0, 14.0)], 3, 0.0), // stepped, old stone
    ([(34.0, 30.0, 12.0)], 4, 0.0), // a slab of flats
    ([(22.0, 44.0, 18.0)], 1, 6.0), // dark panels
  ];

  /// A ring of high-rises far off behind the city, the skyline (no nearer
  /// ring: it crowded the city): flats, offices, an old stepped tower or
  /// two, each on a paved forecourt among the suburbs' houses.
  void _highRises() {
    var seed = 100 + 18;
    for (final (i, (tiers, kind, mast)) in _rises.indexed) {
      seed++;
      final th = (-1.25 + 2.5 * (i + 0.5) / _rises.length) + (rnd(seed, 1) - 0.5) * 0.1;
      final dist = 165 + 70 * rnd(seed, 2);
      _tower(vm.Vector3(math.sin(th) * dist, 0, math.cos(th) * dist + 20), tiers, seed: seed, kind: kind, mast: mast);
    }
  }

  /// A tower of [tiers] (width, height, depth) round [at]: windows in world
  /// scale, each tier finished (trim.dart), the ground one with a base; a
  /// steel [mast] with a red light on top, if any; a paved forecourt.
  void _tower(vm.Vector3 at, List<(double, double, double)> tiers, {required int seed, required int kind, double mast = 0}) {
    final glass = _facades[kind % _facades.length].$1 == 0;
    var y = 0.0, hw = 0.0, hd = 0.0;
    for (final (i, (w, h, d)) in tiers.indexed) {
      final xf = trs(at + vm.Vector3(0, y, 0));
      final ou = (rnd(seed + i, 1) * _cells).floorToDouble() / _cells, ov = (rnd(seed + i, 2) * _cells).floorToDouble() / _cells;
      _far.add(_facadeMat(kind), painted(_boxData(w, h, d, ou, ov).transformed(xf), _facadeColor(kind)));
      addTrim(_far, _trimMat, xf, w, h, d, seed: seed + i, glass: glass, base: i == 0);
      y += h;
      hw = math.max(hw, w / 2);
      hd = math.max(hd, d / 2);
    }
    if (mast > 0) {
      _far
        ..add(_trimMat, part(CylinderGeometry(bottomRadius: 0.35, topRadius: 0.12, height: mast, radialSegments: 8), vm.Matrix4.translation(at + vm.Vector3(0, y + 0.5 + mast / 2, 0)), v4(hex3(0x8C9096))))
        ..add(_trimMat, part(SphereGeometry(radius: 0.32, segments: 10, rings: 6), vm.Matrix4.translation(at + vm.Vector3(0, y + 0.6 + mast, 0)), v4(hex3(0xC8102E))));
    }
    _far.add(_roofMat, part(CuboidGeometry(vm.Vector3(2 * hw + 12, 0.1, 2 * hd + 12)), vm.Matrix4.translation(at + vm.Vector3(0, 0.05, 0)), v4(hex3(0x9A9893))));
    final top = y + (mast > 0 ? mast + 1.0 : 1.3);
    solids.add((vm.Vector3(at.x, top / 2, at.z), vm.Vector3(hw + 1.5, top / 2 + 0.6, hd + 1.5)));
  }

  /// (Always day: nothing on the skyline lights up.)
  void update(double night, double t) {}
}
