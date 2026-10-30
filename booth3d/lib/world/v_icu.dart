import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'grove.dart';
import 'kit.dart';
import 'lamps.dart';
import 'shapes.dart' show bevelBox;
import 'shops.dart';
import 'shot.dart';
import 'v_town.dart' show DrivePath;
import 'trim.dart';
import 'vignette.dart';

/// ICU City (International Components for Unicode), where talk 02 is told:
/// out of Flutter City west along the avenue (past its signs, as Engine
/// Town is east), round a square. The Unicode tower stands over it and the
/// archive's stair goes down beside it (v_tower.dart, v_archive.dart);
/// Script Alley's stalls line a lane off its east side (script_alley.dart);
/// the locale office faces it from the west (v_locale.dart); the mixed
/// paragraph hangs over it (v_mix.dart). Those scenes are placed here
/// themselves; this is the town round them: its paving and its square,
/// blocks, trees, the road's signs, and the camera's drive in.
class IcuCity extends Vignette {
  IcuCity(super.kit);

  @override
  String get name => 'icu';
  @override
  String get kick => 'EVERY SCRIPT ADDS RULES';
  @override
  String get line => 'ICU City: Unicode, scripts, locales';
  @override
  String get note => 'International Components for Unicode';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 30;
  @override
  double get visit => 14;

  /// The middle of the town's square (world), the frame's origin, unturned.
  static final o = vm.Vector3(-270, 0, 8);
  @override
  final frame = vm.Matrix4.translation(o);

  /// The square's radius; the stair's opening (the archive's: Plan's
  /// archiveHole, in the frame), kept clear of paving.
  static const _r = 24.0, _hole = (-12.0, 24.5, -7.8, 27.5);

  /// The avenue's north kerb (Plan.aveZ0, in the frame): the square's south
  /// edge runs under the road, so nothing stands south of this.
  static const _kerb = -19.0;

  /// The blocks round the square: bearing (degrees, clockwise from north:
  /// their fronts face it), distance to their fronts, width, height.
  static const _blocks = [
    (-100.0, 46.0, 16.0, 14.0),
    (-70.0, 50.0, 18.0, 18.0),
    (-45.0, 52.0, 18.0, 20.0),
    (45.0, 50.0, 18.0, 16.0),
    (70.0, 50.0, 16.0, 14.0),
    (105.0, 46.0, 16.0, 12.0),
    (-20.0, 70.0, 22.0, 26.0),
    (20.0, 72.0, 20.0, 22.0),
    (-80.0, 72.0, 22.0, 20.0),
    (80.0, 70.0, 20.0, 18.0),
  ];

  /// A block's depth.
  static const _depth = 12.0;

  /// The road's signs over the westbound lane (the frame's x; the lane's
  /// middle).
  static const _signX = [118.0, 70.0];
  static const _signZ = -25.0;

  /// A point on block [i]'s roof (its gravel), [x] along its front and
  /// [back] behind its parapet, in the world; and the way that faces the
  /// square (a yaw: trs's rotY).
  static (vm.Vector3, double) onRoof(int i, double x, double back) {
    final (bearing, r, _, h) = _blocks[i];
    final a = bearing * math.pi / 180, c = math.cos(a), s = math.sin(a);
    return (vm.Vector3(o.x + r * s + x * c + back * s, h + 0.5, o.z + r * c - x * s + back * c), a);
  }

  static vm.Matrix4 _at(double bearing, double r) {
    final a = bearing * math.pi / 180;
    return trs(vm.Vector3(r * math.sin(a), 0, r * math.cos(a)), rotY: a);
  }

  @override
  late final volumes = [
    for (final (bearing, r, w, h) in _blocks) building(w, _depth, h, on: _at(bearing, r)),
  ];

  @override
  Future<void> init() async {
    final b = Batch();
    final facades = await Future.wait([photoPbr('facade_stone'), photoPbr('facade_tile'), photoPbr('facade_panel'), photoPbr('facade_clad')]);
    final paving = await photoPbr('pavement'), tiles = await photoPbr('plaza_tiles');
    final stone = pbr(rgb(1, 1, 1), roughness: 0.6);
    // The town's ground paved, from the avenue to its back streets (round
    // the stair's opening); the square in tiles.
    final (hx0, hz0, hx1, hz1) = _hole;
    for (final (x0, z0, x1, z1) in [(-66.0, -19.0, hx0, 70.0), (hx1, -19.0, 36.0, 70.0), (hx0, -19.0, hx1, hz0), (hx0, hz1, hx1, 70.0)]) {
      b.add(paving, _laid(CuboidGeometry(vm.Vector3(x1 - x0, 0.3, z1 - z0)).extractMeshData(), vm.Vector3((x0 + x1) / 2, -0.25, (z0 + z1) / 2)).transformed(frame));
    }
    b.add(tiles, _laid(CylinderGeometry(bottomRadius: _r, topRadius: _r, height: 0.3, radialSegments: 72).extractMeshData(), vm.Vector3(0, -0.23, 0)).transformed(frame));
    // The blocks round it, in their photographs; the ones facing the square
    // fronted from round the world (shops.dart): London's brick and a pub,
    // Germany's half-timbering and a bakery, Japan's machiya.
    final paper = pbr(rgb(1, 1, 1), roughness: 0.6, emissive: rgb(1, 0.92, 0.78), emissiveStrength: 0.5);
    final shops = await ShopMaterials.make();
    for (final (i, (bearing, r, w, h)) in _blocks.indexed) {
      final m = frame * _at(bearing, r);
      b
        .add(facades[i % facades.length], painted(_facade(w, h, _depth, ou: 0.25 * i, ov: 0.375 * i).transformed(m * trs(vm.Vector3(0, 0, _depth / 2))), vm.Vector4(1, 1, 1, 1)));
      addTrim(b, stone, m * trs(vm.Vector3(0, 0, _depth / 2)), w, h, _depth, seed: 120 + i);
      final front = m * trs(vm.Vector3(0, 0, _depth / 2));
      switch (i) {
        case 0 || 3:
          addLondonFront(b, stone, shops, front, w, h, _depth);
        case 1 || 5:
          addGermanFront(b, stone, shops, front, w, h, _depth);
        case 2 || 4:
          addMachiya(b, stone, paper, front, w, _depth, seed: i);
      }
    }
    // The road signs' posts (their boards: [_signs]).
    for (final x in _signX) {
      for (final s in [-1.0, 1.0]) {
        b.add(stone, painted(bevelBox(0.2, 9.0, 0.2).transformed(frame * vm.Matrix4.translation(vm.Vector3(x - 0.14, 4.5, _signZ + s * 3.9))), v4(hex3(0x7C8288))));
      }
    }
    b.buildInto(shell, 'icu city', castsShadows: false, lightChannelMask: 0x01);
    await Future.wait([_signs(), _trees(), _lamps()]);
  }

  /// The road's signs (facing the drive in from Flutter City, east), and
  /// the town's own at the square's edge on the avenue.
  Future<void> _signs() async {
    Future<void> board(vm.Matrix4 at, double w, double h, Color ground, String top, String big, String under) => sign(w, h, at, (c, s) {
      final r = Offset.zero & s;
      c
        ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s.height * 0.08)), Paint()..color = ground)
        ..drawRRect(
          RRect.fromRectAndRadius(r.deflate(s.height * 0.05), Radius.circular(s.height * 0.06)),
          Paint()
            ..color = const Color(0xFFF4F6F8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.height * 0.025,
        );
      Vignette.text(c, top, Rect.fromLTWH(0, s.height * 0.12, s.width, s.height * 0.2), s.height * 0.13, const Color(0xFFF4F6F8), weight: FontWeight.w600);
      Vignette.text(c, big, Rect.fromLTWH(0, s.height * 0.32, s.width, s.height * 0.36), s.height * 0.3, const Color(0xFFFFFFFF), weight: FontWeight.w800);
      Vignette.text(c, under, Rect.fromLTWH(0, s.height * 0.7, s.width, s.height * 0.18), s.height * 0.11, const Color(0xFFDDE6EE), weight: FontWeight.w500);
    }, px: 1500, glow: 0.3, thick: 0.08, shell: true);

    await Future.wait([
      board(trs(vm.Vector3(_signX[0], 7.4, _signZ), rotY: -math.pi / 2), 9.0, 3.4, const Color(0xFF0E6B3B), 'YOU ARE NOW LEAVING', 'FLUTTER CITY', 'Come back soon'),
      board(trs(vm.Vector3(_signX[1], 7.4, _signZ), rotY: -math.pi / 2), 9.0, 3.4, const Color(0xFF6B2A86), 'WELCOME TO', 'ICU CITY', 'International Components for Unicode'),
      board(trs(vm.Vector3(0, 1.5, _kerb + 1.8)), 8.0, 2.2, const Color(0xFF1B2A44), 'INTERNATIONAL COMPONENTS FOR UNICODE', 'ICU CITY', 'Unicode · scripts · locales'),
    ]);
  }

  /// Trees round the square (none before the scenes on it, nor across the
  /// way in from the avenue): cloud-pruned black pines (grove.dart).
  Future<void> _trees() async {
    final grove = Grove();
    await grove.load(const [TreeKind.pine, TreeKind.pineB]);
    // (None at 98°: where the talk's camera stands at Script Alley's gate;
    // none further south than ±126°, 3 m short of the avenue's kerb; one in
    // the south-west, clear of the locale office's corner.)
    const bearings = [-121.0, -60.0, -46.0, 30.0, 44.0, 113.0, 126.0];
    for (final (i, bearing) in bearings.indexed) {
      final a = bearing * math.pi / 180, r = _r + 3.0;
      grove.plant(
        i.isEven ? TreeKind.pine : TreeKind.pineB,
        frame * trs(vm.Vector3(r * math.sin(a), 0, r * math.cos(a)), rotY: rnd(i, 3) * 6, s: vm.Vector3.all(0.85 + 0.3 * rnd(i, 1))),
        shade: 0.92 + 0.14 * rnd(i, 4),
      );
    }
    grove.addTo(shell.add, 'icu trees');
  }

  /// Lamps round the square, one between each pair of pines (in the
  /// south-west, by the kerb past its pine): Japanese suzuran lamps and
  /// London's cast-iron lanterns in turn (lamps.dart).
  Future<void> _lamps() async {
    final lamps = Lamps();
    await lamps.load(const [LampKind.suzuran, LampKind.lantern]);
    for (final (k, bearing) in const [-130.0, -53.0, 37.0, 120.0].indexed) {
      final a = bearing * math.pi / 180, r = _r + 2.6;
      lamps.place(k.isEven ? LampKind.suzuran : LampKind.lantern, frame * trs(vm.Vector3(r * math.sin(a), 0, r * math.cos(a))));
    }
    lamps.addTo(shell.add, 'icu lamps');
  }

  @override
  void pose(double u, double t, double night) {}

  // ── The camera ────────────────────────────────────────────────────────────

  /// The drive: out of the city along the avenue's westbound lane (world),
  /// past the signs, then up and round to take in the town from its
  /// south-east; how long it takes; where the camera looks at the end.
  static final _drive = DrivePath([
    vm.Vector3(-36, 4.6, -17),
    vm.Vector3(-95, 4.6, -17),
    vm.Vector3(-150, 4.6, -17),
    // (Veering off the avenue's end, clear of the square's south-east
    // block: it used to fill half the picture going by.)
    vm.Vector3(-192, 5.4, -21),
    vm.Vector3(-214, 10, -31),
    vm.Vector3(-232, 17, -41),
    vm.Vector3(-240, 21, -46),
  ]);
  static const _driveT = 10.5;
  static final _townAim = vm.Vector3(-266, 9, 18);

  @override
  Shot shot(double u) {
    final f = DrivePath.pace(u / _driveT);
    final p = _drive.at(f * _drive.length, vm.Vector3.zero());
    final ahead = p + vm.Vector3(-40, -3.2, 0);
    final k = smooth(0.6, 1.0, f);
    final target = ahead + (_townAim - ahead) * k;
    return Shot(p - o, target - o, fov: 50, settle: 1.0, drift: lerp(0.1, 0.6, k));
  }

  // ── Building ──────────────────────────────────────────────────────────────

  /// A block [w]×[h]×[d] (its bottom middle at the origin) faced in a
  /// photographed facade, its windows at their real size: a texture holds
  /// 8×8 cells of 1.7 × 2.6 m (from [ou], [ov] into it); the roof plain.
  static MeshData _facade(double w, double h, double d, {double ou = 0, double ov = 0}) {
    const cw = 1.7 * 8, ch = 2.6 * 8;
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

  /// [d] (a slab: paving) moved to [at] in the town's frame, its texture
  /// laid at 3 m a tile where it is in the world.
  static MeshData _laid(MeshData d, vm.Vector3 at) {
    final m = d.transformed(vm.Matrix4.translation(at));
    final uv = Float32List(m.vertexCount * 2);
    for (var i = 0; i < m.vertexCount; i++) {
      uv
        ..[i * 2] = (o.x + m.positions[i * 3]) / 3
        ..[i * 2 + 1] = (o.z + m.positions[i * 3 + 2]) / 3;
    }
    return painted(m, vm.Vector4(1, 1, 1, 1), uvs: uv);
  }
}
