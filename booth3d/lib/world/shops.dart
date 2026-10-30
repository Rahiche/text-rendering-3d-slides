import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'shapes.dart' show bevelBox;
import 'walls.dart';

/// What a shop sells: what its window shows (its back wall, painted in the
/// shops' atlas), its names, its awning's colour.
enum ShopKind {
  books(['BOOKS & PAPER', 'MAPS & GUIDES'], 0xC8442F),
  cafe(['COFFEE', 'TEA HOUSE'], 0x2F5D46),
  prints(['TYPE & PRINT', 'POSTERS'], 0x2E6DA8),
  flowers(['FLOWERS', 'GARDEN'], 0xD86A8E),
  bakery(['BAKERY', 'BREAD'], 0xB07A34),
  pens(['INK & PENS', 'STATIONERY'], 0x3E4E7A);

  const ShopKind(this.names, this.awning);
  final List<String> names;
  final int awning;

  /// Its back wall's picture in the atlas (u0, v0, u1, v1).
  (double, double, double, double) get inside {
    final col = index % 2, row = index ~/ 2;
    return (col * 0.5, row * 0.25, col * 0.5 + 0.5, row * 0.25 + 0.25);
  }

  /// Its [k]th name's place in the atlas.
  (double, double, double, double) name(int k) {
    final j = index * 2 + k % 2, cx = j % 4, cy = j ~/ 4;
    return (cx * 0.25, 0.75 + cy * 0.0625, cx * 0.25 + 0.25, 0.75 + cy * 0.0625 + 0.0625);
  }
}

/// The shops' materials, made once: the atlas (each shop's name over its
/// door; what each window shows, lit), the glass, the ceiling lights.
class ShopMaterials {
  ShopMaterials._(this.atlas, this.glass, this.light, this.brick, this.timber);
  final PhysicallyBasedMaterial atlas, glass, light;

  /// Facings that repeat up a block's front, two storeys and four bays a
  /// tile (7 × 5.6 m): London's brick and sash windows, Germany's
  /// half-timbering (walls.dart).
  final PhysicallyBasedMaterial brick, timber;

  /// In the atlas: the pub's name on its fascia; the bakery's pretzel sign.
  static const pubName = (0.0, 0.9375, 0.25, 1.0), pretzel = (0.25, 0.9375, 0.3125, 1.0);

  static Future<ShopMaterials>? _made;
  static Future<ShopMaterials> make() => _made ??= _make();

  static Future<ShopMaterials> _make() async {
    final tex = await paintedTexture(2048, 2048, _paintAtlas);
    final atlas = PhysicallyBasedMaterial()
      ..baseColorTexture = tex
      ..emissiveTexture = tex
      ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
      ..emissiveStrength = 0.8
      ..metallicFactor = 0
      ..roughnessFactor = 0.7;
    final glass = pbr(rgb(0.74, 0.82, 0.88, 0.1), roughness: 0.02)..alphaMode = AlphaMode.blend;
    final light = pbr(rgb(1, 1, 1), emissive: rgb(1, 0.93, 0.8), emissiveStrength: 3);
    Future<PhysicallyBasedMaterial> facing(void Function(Canvas, Rect, int) paint) async => PhysicallyBasedMaterial()
      ..baseColorTexture = await paintedTexture(512, 512, (c, s) => paint(c, Offset.zero & s, 1))
      ..metallicFactor = 0
      ..roughnessFactor = 0.85;
    return ShopMaterials._(atlas, glass, light, await facing(paintBrickWall), await facing(paintTimberWall));
  }
}

// ── Shops in a block's ground floor ───────────────────────────────────────

/// The ground floor's height (the floors above start here).
const shopFloor = 3.2;

/// Shops along the ground floor of a block [w] wide and [d] deep (local x
/// along its front, the front at z = −d/2, its bottom middle at [at]'s
/// origin), instead of trim.dart's stone base: stone round the sides and
/// back, a ledge over it all; at the front, a shop every 6 to 8 m — a
/// stall riser, big windows into the shop (a floor, a ceiling with lights,
/// its back wall's picture, a table or a counter), a glazed door, its name
/// over it on a fascia, a striped awning (where [awning] allows, given
/// its stretch of the front: none under a street tree). [cafe]: the last
/// shop is a café, its tables out on the pavement. Into [b], the solid
/// parts painted onto [mat].
void addShops(Batch b, Material mat, ShopMaterials sm, vm.Matrix4 at, double w, double d, {required int seed, bool cafe = false, bool Function(double x0, double x1)? awning}) {
  const floor = shopFloor;
  final z0 = -d / 2, room = math.min(4.5, d - 1.0);
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb, {double rotX = 0, Material? m}) =>
      b.add(m ?? mat, painted(bevelBox(sx, sy, sz).transformed(at * trs(vm.Vector3(x, y, z), rotX: rotX)), v4(hex3(rgb))));
  void quad(Material m, double sx, double sy, double x, double y, double z, (double, double, double, double) uv) =>
      b.add(m, painted(_quad(sx, sy, uv).transformed(at * vm.Matrix4.translation(vm.Vector3(x, y, z))), vm.Vector4(1, 1, 1, 1)));

  // The stone round the sides and the back; the ledge over the shops; the
  // floor and the ceiling right through.
  const stone = 0x55585D;
  box(w + 0.24, floor, 0.12, 0, floor / 2, d / 2 + 0.06, stone);
  for (final s in [-1.0, 1.0]) {
    box(0.12, floor, d + 0.24, s * (w / 2 + 0.06), floor / 2, 0, stone);
  }
  box(w + 0.34, 0.2, d + 0.34, 0, floor + 0.1, 0, 0xB3AC9F);
  box(w, 0.04, d, 0, 0.11, 0, 0x8A6A4A);
  box(w, 0.06, d, 0, floor - 0.03, 0, 0xEDE8DF);

  // The shops: as many as fit 6–8 m each, piers of stone between them.
  final n = math.max(1, (w / 7).round());
  const pier = 0.3;
  final sw = (w - pier * (n + 1)) / n;
  for (var k = 0; k < n; k++) {
    final a = -w / 2 + pier + k * (sw + pier), xm = a + sw / 2;
    final isCafe = cafe && k == n - 1;
    final kind = isCafe ? ShopKind.cafe : ShopKind.values[(seed * 7 + k * 3) % ShopKind.values.length];
    final door = a + sw - 0.85;
    // Inside: its back wall's picture, the party walls, ceiling lights.
    quad(sm.atlas, sw - 0.1, floor - 0.1, xm, floor / 2, z0 + room, kind.inside);
    for (final s in [-1.0, 1.0]) {
      box(0.12, floor, room, xm + s * (sw / 2 + 0.06), floor / 2, z0 + room / 2, 0xD9CFC0);
    }
    for (final f in [0.3, 0.7]) {
      box(0.5, 0.03, 0.5, a + sw * f, floor - 0.07, z0 + room * 0.45, 0xFFFFFF, m: sm.light);
    }
    _inside(box, kind, a, sw, z0, room, seed + k);
    // The front: a stall riser, the glass, the frame round it, mullions.
    box(door - 0.5 - a, 0.32, 0.2, (a + door - 0.5) / 2, 0.16, z0 - 0.02, 0x6B6862);
    b.add(sm.glass, painted(bevelBox(door - 0.55 - a - 0.12, 2.4, 0.02).transformed(at * trs(vm.Vector3((a + 0.12 + door - 0.55) / 2, 0.32 + 1.2, z0))), vm.Vector4(1, 1, 1, 1)));
    for (final x in [a + 0.06, a + sw - 0.06]) {
      box(0.12, floor - 0.42, 0.2, x, (floor - 0.42) / 2, z0, 0x23272D);
    }
    box(sw, 0.14, 0.2, xm, floor - 0.42, z0, 0x23272D);
    for (final f in [1 / 3, 2 / 3]) {
      box(0.06, 2.4, 0.12, a + 0.12 + (door - 0.55 - a - 0.12) * f, 1.52, z0, 0x23272D);
    }
    // The door: its frame, its glass, a bar to push.
    for (final s in [-1.0, 1.0]) {
      box(0.08, 2.6, 0.12, door + s * 0.5, 1.3, z0, 0x23272D);
    }
    box(1.08, 0.2, 0.12, door, 0.1, z0, 0x23272D);
    box(1.08, 0.08, 0.12, door, 2.6, z0, 0x23272D);
    b.add(sm.glass, painted(bevelBox(0.92, 2.4, 0.02).transformed(at * trs(vm.Vector3(door, 1.4, z0 + 0.01))), vm.Vector4(1, 1, 1, 1)));
    box(0.04, 0.9, 0.06, door - 0.36, 1.1, z0 - 0.07, 0xC9A36B);
    // Its name over it, on a fascia.
    box(sw, 0.42, 0.16, xm, floor - 0.13, z0 - 0.08, 0x1E2433);
    quad(sm.atlas, sw - 0.12, 0.36, xm, floor - 0.13, z0 - 0.165, kind.name(seed + k));
    // The awning: stripes falling out from under the fascia, a valance.
    // (A café has umbrellas out instead.)
    if (!isCafe && (awning == null || awning(a, a + sw))) {
      final stripes = math.max(2, (sw / 0.5).round());
      final st = sw / stripes;
      const out = 1.38, pitch = 0.3;
      for (var s = 0; s < stripes; s++) {
        final c = s.isEven ? kind.awning : 0xF4F1EA;
        final x = a + st * (s + 0.5);
        box(st, 0.03, out / math.cos(pitch), x, floor - 0.62, z0 - out / 2, c, rotX: -pitch);
        box(st, 0.22, 0.02, x, floor - 0.62 - out / 2 * math.tan(pitch) - 0.11, z0 - out, c);
      }
    }
    if (isCafe) _terrace(b, mat, at, a, sw, z0);
  }
  // The piers.
  for (var k = 0; k <= n; k++) {
    final x = -w / 2 + pier / 2 + k * (sw + pier);
    box(pier, floor, 0.3, x, floor / 2, z0 + 0.1, 0x6B6862);
  }
}

/// A shop's own things inside: what [kind] keeps on its floor.
void _inside(void Function(double, double, double, double, double, double, int, {double rotX, Material? m}) box, ShopKind kind, double a, double sw, double z0, double room, int seed) {
  final rnd = math.Random(seed);
  final mid = a + sw * 0.42, depth = z0 + room * 0.45;
  switch (kind) {
    case ShopKind.cafe:
      // The counter along one side, its machine; two small tables.
      box(sw * 0.45, 1.0, 0.7, a + sw * 0.7, 0.5, z0 + room - 1.3, 0x3A2A22);
      box(sw * 0.47, 0.05, 0.76, a + sw * 0.7, 1.02, z0 + room - 1.3, 0xEDEAE4);
      box(0.7, 0.45, 0.45, a + sw * 0.8, 1.27, z0 + room - 1.35, 0xC9CCD0);
      for (final f in [0.18, 0.4]) {
        box(0.7, 0.04, 0.7, a + sw * f, 0.75, z0 + 1.4, 0xF2F0EA);
        box(0.06, 0.73, 0.06, a + sw * f, 0.37, z0 + 1.4, 0x2B2F36);
      }
    case ShopKind.books || ShopKind.pens:
      // A table of books (or notebooks) in stacks.
      box(1.8, 0.76, 0.9, mid, 0.38, depth, 0x5A3E2A);
      for (var k = 0; k < 4; k++) {
        final h = 0.06 + 0.05 * rnd.nextDouble();
        box(0.3, h, 0.22, mid - 0.6 + 0.4 * k, 0.76 + h / 2, depth, const [0x8E2B2B, 0x2E4E7A, 0xD9C9A3, 0x3E6B4A][k]);
      }
    case ShopKind.prints:
      // A big table with sheets on it, a plan chest.
      box(2.4, 0.85, 1.0, mid, 0.42, depth, 0x6B6862);
      for (var k = 0; k < 5; k++) {
        box(0.42, 0.006, 0.3, mid - 0.9 + 0.45 * k, 0.856, depth + 0.1 * (k % 2), 0xF6F3EC);
      }
      box(1.3, 0.9, 0.7, a + sw * 0.82, 0.45, z0 + room - 0.6, 0x8E9399);
    case ShopKind.flowers:
      // Buckets of flowers on the floor by the window.
      for (var k = 0; k < 7; k++) {
        final x = a + 0.5 + k * (sw - 1.6) / 7;
        box(0.3, 0.34, 0.3, x, 0.17, z0 + 0.7, 0x8E9399);
        for (var j = 0; j < 3; j++) {
          box(0.13, 0.13, 0.13, x + (rnd.nextDouble() - 0.5) * 0.18, 0.45 + 0.12 * rnd.nextDouble(), z0 + 0.7 + (rnd.nextDouble() - 0.5) * 0.18, const [0xE84A6F, 0xF4E04D, 0xF4F1EA, 0xD86A8E][rnd.nextInt(4)]);
        }
      }
    case ShopKind.bakery:
      // A glass-fronted counter of loaves.
      box(sw * 0.6, 0.95, 0.75, mid, 0.475, z0 + room - 1.4, 0x6E4A2E);
      for (var k = 0; k < 6; k++) {
        box(0.32, 0.14, 0.2, mid - sw * 0.25 + k * sw * 0.1, 1.02, z0 + room - 1.4, 0xC08A3E);
      }
  }
}

/// A café's terrace on the pavement in front of it: tables, chairs,
/// umbrellas.
void _terrace(Batch b, Material mat, vm.Matrix4 at, double a, double sw, double z0) {
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb) =>
      b.add(mat, painted(bevelBox(sx, sy, sz).transformed(at * vm.Matrix4.translation(vm.Vector3(x, y, z))), v4(hex3(rgb))));
  const dark = 0x2B2F36;
  for (var k = 0; k < 3; k++) {
    final x = a + sw * (k + 0.5) / 3, z = z0 - 1.25;
    box(0.7, 0.04, 0.7, x, 0.76, z, 0xF2F0EA);
    box(0.06, 0.74, 0.06, x, 0.37, z, dark);
    for (final s in [-1.0, 1.0]) {
      box(0.42, 0.05, 0.42, x + s * 0.62, 0.46, z, dark);
      box(0.04, 0.42, 0.42, x + s * 0.82, 0.7, z, dark);
      for (final dx in [-0.17, 0.17]) {
        for (final dz in [-0.17, 0.17]) {
          box(0.03, 0.44, 0.03, x + s * 0.62 + dx, 0.22, z + dz, dark);
        }
      }
    }
    box(0.04, 2.3, 0.04, x, 1.15, z, dark);
    b.add(mat, part(_umbrella, at * vm.Matrix4.translation(vm.Vector3(x, 2.25, z)), v4(hex3(k.isOdd ? 0xF2EEE4 : 0x2F5D46))));
  }
}

final _umbrella = CylinderGeometry(bottomRadius: 1.05, topRadius: 0.05, height: 0.36, radialSegments: 8);

/// A flat panel [w]×[h] facing −z, its middle at the origin, showing the
/// atlas's [uv] rectangle upright.
MeshData _quad(double w, double h, (double, double, double, double) uv) {
  final (u0, v0, u1, v1) = uv;
  return MeshData(
    positions: Float32List.fromList([-w / 2, -h / 2, 0, w / 2, -h / 2, 0, w / 2, h / 2, 0, -w / 2, h / 2, 0]),
    vertexCount: 4,
    normals: Float32List.fromList([0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1]),
    texCoords: Float32List.fromList([u0, v1, u1, v1, u1, v0, u0, v0]),
    indices: [0, 2, 1, 0, 3, 2],
  );
}

// ── Machiya fronts ────────────────────────────────────────────────────────

/// Machiya fronts on a block's ground floor, over trim.dart's stone base
/// (a block [w] wide, its front at z = −d/2, its bottom middle at [at]'s
/// origin): a dark timber frame, wooden lattice (koshi) over lit paper, a
/// doorway with noren in each, a paper lantern by it, a deep tiled eave
/// over the whole front. Into [b] on [mat]; the paper on [glow].
void addMachiya(Batch b, Material mat, Material glow, vm.Matrix4 at, double w, double d, {required int seed}) {
  final z0 = -d / 2 - 0.12;
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb, {double rotX = 0, Material? m}) =>
      b.add(m ?? mat, painted(bevelBox(sx, sy, sz).transformed(at * trs(vm.Vector3(x, y, z), rotX: rotX)), v4(hex3(rgb))));
  const timber = 0x2B211B, lattice = 0x4E3828;
  box(w + 0.24, 3.4, 0.1, 0, 1.7, z0 - 0.05, timber);
  final n = math.max(1, (w / 6.5).round());
  final uw = w / n;
  const noren = [0x23315E, 0x7A1E1E, 0x2F4F3A, 0x5A3A1E];
  for (var k = 0; k < n; k++) {
    final a = -w / 2 + k * uw;
    final latW = uw - 2.4;
    // The lattice over lit paper.
    box(latW, 2.45, 0.04, a + 0.15 + latW / 2, 1.4, z0 - 0.12, 0xF2E6CC, m: glow);
    for (var x = a + 0.22; x < a + 0.15 + latW - 0.05; x += 0.11) {
      box(0.045, 2.4, 0.06, x, 1.4, z0 - 0.17, lattice);
    }
    for (final y in [0.2, 2.6]) {
      box(latW + 0.2, 0.1, 0.08, a + 0.15 + latW / 2, y, z0 - 0.18, timber);
    }
    for (final x in [a + 0.08, a + uw - 2.2, a + uw - 0.08]) {
      box(0.16, 2.8, 0.18, x, 1.4, z0 - 0.18, timber);
    }
    // The doorway, its noren, a lantern.
    final dx = a + uw - 1.15;
    box(1.9, 2.45, 0.04, dx, 1.3, z0 - 0.11, 0x1E1914);
    for (var s = 0; s < 3; s++) {
      box(0.6, 1.05, 0.015, dx - 0.63 + 0.63 * s, 2.05, z0 - 0.28, noren[(seed + k) % noren.length]);
    }
    box(2.0, 0.05, 0.05, dx, 2.6, z0 - 0.28, timber);
    final lx = a + uw - 2.45;
    b.add(glow, painted(_lantern.transformed(at * trs(vm.Vector3(lx, 2.3, z0 - 0.5), s: vm.Vector3(1, 1.4, 1))), v4(hex3(0xF4EEDF))));
    box(0.2, 0.05, 0.2, lx, 2.62, z0 - 0.5, timber);
    box(0.2, 0.05, 0.2, lx, 1.98, z0 - 0.5, timber);
    box(0.015, 0.7, 0.015, lx, 2.98, z0 - 0.5, timber);
  }
  // The eave: tiles over the whole front, a round tile down each joint.
  const tile = 0x3A3F47, pitch = 0.32, out = 1.45;
  final tiles = (w / 0.5).round();
  for (var s = 0; s < tiles; s++) {
    final x = -w / 2 + (s + 0.5) * w / tiles;
    box(w / tiles, 0.05, out / math.cos(pitch), x, 3.36, z0 - out / 2 + 0.1, tile, rotX: -pitch);
    box(0.12, 0.1, out / math.cos(pitch), x + w / tiles / 2, 3.42, z0 - out / 2 + 0.1, tile, rotX: -pitch);
  }
  box(w + 0.1, 0.12, 0.12, 0, 3.36 - out / 2 * math.tan(pitch) - 0.04, z0 - out + 0.1, tile);
}

/// A block's front in London's way: its storeys over the ground floor
/// faced in red brick and white sash windows, and on the ground floor a
/// pub, its paintwork dark green, its name in gold on the fascia, three
/// small-paned windows between cream pilasters, a black door, hanging
/// baskets of flowers, a lamp. (A block [w] wide, [h] high, its front at
/// z = −d/2, over trim.dart's stone base; its bottom middle at [at]'s
/// origin.)
void addLondonFront(Batch b, Material mat, ShopMaterials sm, vm.Matrix4 at, double w, double h, double d) {
  final z0 = -d / 2 - 0.12;
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb) =>
      b.add(mat, painted(bevelBox(sx, sy, sz).transformed(at * trs(vm.Vector3(x, y, z))), v4(hex3(rgb))));
  _facing(b, sm.brick, at, w, 3.45, h, -d / 2 - 0.03);
  const green = 0x1E4D3A, cream = 0xE8E0CE;
  box(w + 0.24, 3.4, 0.12, 0, 1.7, z0 - 0.06, green);
  b.add(sm.atlas, painted(_quad(math.min(w - 1, 9.0), 0.6, ShopMaterials.pubName).transformed(at * vm.Matrix4.translation(vm.Vector3(0, 2.95, z0 - 0.13))), vm.Vector4(1, 1, 1, 1)));
  final bays = math.max(3, (w / 4.2).floor());
  for (var k = 0; k < bays; k++) {
    final x = -w / 2 + (k + 0.5) * w / bays;
    if (k == bays ~/ 2) {
      box(1.1, 2.3, 0.06, x, 1.15, z0 - 0.14, 0x15171B);
      box(1.2, 0.3, 0.08, x, 2.4, z0 - 0.15, 0xD9B45A);
    } else {
      box(w / bays - 1.0, 1.7, 0.04, x, 1.45, z0 - 0.13, 0x2C3846);
      for (var f = 1; f < 4; f++) {
        box(0.04, 1.7, 0.06, x - (w / bays - 1.0) / 2 + (w / bays - 1.0) * f / 4, 1.45, z0 - 0.15, cream);
      }
      box(w / bays - 1.0, 0.04, 0.06, x, 1.45, z0 - 0.15, cream);
      // A basket of flowers on a bracket over it.
      box(0.05, 0.05, 0.5, x, 2.62, z0 - 0.38, 0x15171B);
      b.add(mat, painted(_lantern.transformed(at * trs(vm.Vector3(x, 2.35, z0 - 0.62), s: vm.Vector3(1.3, 0.9, 1.3))), v4(hex3(0x4B7F3E))));
      for (final (dx, dy, c) in const [(-0.18, 0.12, 0xD9344A), (0.15, 0.1, 0xF06A8A), (0.0, 0.2, 0xF4E04D), (0.22, -0.05, 0xF4F1EA)]) {
        box(0.1, 0.1, 0.1, x + dx, 2.35 + dy, z0 - 0.82, c);
      }
    }
    box(0.3, 3.0, 0.16, -w / 2 + k * w / bays + (k == 0 ? 0.15 : 0), 1.5, z0 - 0.14, cream);
  }
}

/// A terrace house's front on an English high street: brick with sash
/// windows from over its shop up ([addLondonFront]'s upper floors), the
/// shop itself [addShops]'.
void addBrickFront(Batch b, ShopMaterials sm, vm.Matrix4 at, double w, double h, double d) => _facing(b, sm.brick, at, w, 3.45, h, -d / 2 - 0.03);

/// A block's front in Germany's way: half-timbered right down to the
/// pavement, and on the ground floor a bakery: its window and door, its
/// name over them, a gilt pretzel hanging from an iron bracket. (As
/// [addLondonFront].)
void addGermanFront(Batch b, Material mat, ShopMaterials sm, vm.Matrix4 at, double w, double h, double d) {
  final z0 = -d / 2 - 0.12;
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb) =>
      b.add(mat, painted(bevelBox(sx, sy, sz).transformed(at * trs(vm.Vector3(x, y, z))), v4(hex3(rgb))));
  _facing(b, sm.timber, at, w, 0.1, h, z0 - 0.03);
  // The bakery: its window, its door, its name, the sign on its bracket.
  box(4.4, 1.6, 0.05, -1.2, 1.4, z0 - 0.06, 0x2C3846);
  box(4.6, 0.12, 0.08, -1.2, 2.25, z0 - 0.08, 0xF4F2EC);
  box(4.6, 0.12, 0.08, -1.2, 0.55, z0 - 0.08, 0xF4F2EC);
  box(1.1, 2.3, 0.06, 2.0, 1.15, z0 - 0.07, 0x6B4A33);
  b.add(sm.atlas, painted(_quad(4.2, 0.5, ShopKind.bakery.name(0)).transformed(at * vm.Matrix4.translation(vm.Vector3(-1.2, 2.75, z0 - 0.08))), vm.Vector4(1, 1, 1, 1)));
  box(0.06, 0.06, 1.3, 3.4, 3.1, z0 - 0.65, 0x15171B);
  box(0.04, 0.5, 0.04, 3.4, 2.85, z0 - 1.2, 0x15171B);
  b.add(sm.atlas, painted(_quad(0.8, 0.8, ShopMaterials.pretzel).transformed(at * trs(vm.Vector3(3.4, 2.25, z0 - 1.2), rotY: math.pi / 2)), vm.Vector4(1, 1, 1, 1)));
  b.add(sm.atlas, painted(_quad(0.8, 0.8, ShopMaterials.pretzel).transformed(at * trs(vm.Vector3(3.4, 2.25, z0 - 1.2), rotY: -math.pi / 2)), vm.Vector4(1, 1, 1, 1)));
}

/// A facing over a block's front from [y0] up to [h], [w] across, at
/// [z]: [m]'s tile repeated, its top row of windows at the top.
void _facing(Batch b, Material m, vm.Matrix4 at, double w, double y0, double h, double z) {
  const tw = 7.0, th = 5.6;
  final u1 = w / tw, v1 = (h - y0) / th;
  b.add(
    m,
    painted(
      MeshData(
        positions: Float32List.fromList([-w / 2, y0, z, w / 2, y0, z, w / 2, h, z, -w / 2, h, z]),
        vertexCount: 4,
        normals: Float32List.fromList([0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1]),
        texCoords: Float32List.fromList([0, v1, u1, v1, u1, 0, 0, 0]),
        indices: [0, 2, 1, 0, 3, 2],
      ).transformed(at),
      vm.Vector4(1, 1, 1, 1),
    ),
  );
}

/// A paper lantern's (chōchin) round body.
final _lantern = SphereGeometry(radius: 0.22, segments: 12, rings: 8).extractMeshData();

// ── The atlas ─────────────────────────────────────────────────────────────

const _bookColours = [
  Color(0xFF8E2B2B), Color(0xFF2E4E7A), Color(0xFFD9C9A3), Color(0xFF3E6B4A), Color(0xFF1F2A3A), //
  Color(0xFFC08A3E), Color(0xFF6B3F6E), Color(0xFFE6E0D2), Color(0xFF9C5B3B),
];

/// The atlas: each kind's back wall (1024 × 512 px, two to a row, three
/// rows), then each name on its fascia (512 × 128, four to a row).
void _paintAtlas(Canvas c, Size s) {
  for (final k in ShopKind.values) {
    final (u0, v0, u1, v1) = k.inside;
    final r = Rect.fromLTRB(u0 * s.width, v0 * s.height, u1 * s.width, v1 * s.height);
    c
      ..save()
      ..clipRect(r);
    final rnd = math.Random(k.index + 11);
    switch (k) {
      case ShopKind.books:
        _shelves(c, r, rnd, const Color(0xFFE9DFCF), (c, box, rnd) {
          var x = box.left;
          while (x < box.right - 8) {
            final bw = 8 + rnd.nextDouble() * 16, bh = box.height * (0.72 + 0.28 * rnd.nextDouble());
            c.drawRect(Rect.fromLTWH(x, box.bottom - bh, bw, bh), Paint()..color = _bookColours[rnd.nextInt(_bookColours.length)]);
            x += bw + 1.5;
          }
        });
      case ShopKind.pens:
        _shelves(c, r, rnd, const Color(0xFFD6DCE4), (c, box, rnd) {
          var x = box.left;
          while (x < box.right - 30) {
            if (rnd.nextDouble() < 0.3) {
              // A cup of pens.
              final cx = x + 18;
              for (var p = 0; p < 5; p++) {
                c.drawLine(Offset(cx - 8 + p * 4, box.bottom - 30), Offset(cx - 12 + p * 6, box.bottom - 30 - 22 - 10 * rnd.nextDouble()), Paint()
                  ..color = _bookColours[rnd.nextInt(_bookColours.length)]
                  ..strokeWidth = 3);
              }
              c.drawRect(Rect.fromLTWH(cx - 14, box.bottom - 32, 28, 32), Paint()..color = const Color(0xFF4A5560));
              x += 40;
            } else {
              final bw = 26 + rnd.nextDouble() * 20, bh = box.height * (0.5 + 0.3 * rnd.nextDouble());
              c.drawRect(Rect.fromLTWH(x, box.bottom - bh, bw, bh), Paint()..color = _bookColours[rnd.nextInt(_bookColours.length)]);
              x += bw + 4;
            }
          }
        });
      case ShopKind.bakery:
        _shelves(c, r, rnd, const Color(0xFFF1E4CC), (c, box, rnd) {
          var x = box.left + 6;
          while (x < box.right - 50) {
            final bw = 44 + rnd.nextDouble() * 26, bh = 22 + rnd.nextDouble() * 12;
            c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, box.bottom - bh, bw, bh), Radius.circular(bh / 2)), Paint()..color = Color.lerp(const Color(0xFFB0702E), const Color(0xFFD9A35A), rnd.nextDouble())!);
            x += bw + 8;
          }
        });
      case ShopKind.cafe:
        // White tiles, a chalkboard menu, shelves of cups and jars.
        c.drawRect(r, Paint()..color = const Color(0xFFEDEBE6));
        final grid = Paint()
          ..color = const Color(0xFFCFCBC4)
          ..strokeWidth = 2;
        for (var y = r.top; y < r.bottom; y += 22) {
          c.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
          final shift = ((y - r.top) / 22).round().isEven ? 0.0 : 22.0;
          for (var x = r.left + shift; x < r.right; x += 44) {
            c.drawLine(Offset(x, y), Offset(x, y + 22), grid);
          }
        }
        final board = Rect.fromLTWH(r.left + 60, r.top + 70, 360, 250);
        c.drawRect(board.inflate(10), Paint()..color = const Color(0xFF6B4A33));
        c.drawRect(board, Paint()..color = const Color(0xFF22282A));
        _label(c, 'MENU', Rect.fromLTWH(board.left, board.top + 14, board.width, 50), 40, const Color(0xFFF2F0EA));
        for (var i = 0; i < 6; i++) {
          final y = board.top + 90 + i * 26;
          c.drawLine(Offset(board.left + 30, y), Offset(board.left + 30 + 160 + 80 * rnd.nextDouble(), y), Paint()
            ..color = const Color(0xCCF2F0EA)
            ..strokeWidth = 4);
        }
        for (final y in [r.top + 150, r.top + 290]) {
          c.drawRect(Rect.fromLTWH(r.left + 480, y, 500, 10), Paint()..color = const Color(0xFF6B4A33));
          for (var x = r.left + 490; x < r.right - 60; x += 46) {
            c.drawRect(Rect.fromLTWH(x, y - 40, 30, 40), Paint()..color = [const Color(0xFFC9A36B), const Color(0xFF6B4A33), const Color(0xFFF2F0EA)][rnd.nextInt(3)]);
          }
        }
      case ShopKind.prints:
        // A white wall of framed prints, a big letter on each.
        c.drawRect(r, Paint()..color = const Color(0xFFF2F0EC));
        const letters = ['A', 'g', '&', 'Q', 'R'];
        const grounds = [Color(0xFFFFC66D), Color(0xFF5FB8FF), Color(0xFFFF8FC8), Color(0xFF6CE5B1), Color(0xFFC39BFF)];
        for (var i = 0; i < 5; i++) {
          final f = Rect.fromLTWH(r.left + 40 + i * 196, r.top + 90, 160, 220);
          c.drawRect(f, Paint()..color = const Color(0xFF2B2F36));
          c.drawRect(f.deflate(10), Paint()..color = grounds[i]);
          _label(c, letters[i], f.deflate(20), 150, const Color(0xFF14203A));
        }
      case ShopKind.flowers:
        // Tiers of buckets, full of flowers.
        c.drawRect(r, Paint()..color = const Color(0xFFDDE8D6));
        for (var tier = 0; tier < 3; tier++) {
          final y = r.top + 200 + tier * 110;
          c.drawRect(Rect.fromLTWH(r.left + 20, y, r.width - 40, 14), Paint()..color = const Color(0xFF6B4A33));
          for (var x = r.left + 40; x < r.right - 60; x += 70) {
            for (var j = 0; j < 7; j++) {
              c.drawCircle(Offset(x + 25 + (rnd.nextDouble() - 0.5) * 50, y - 50 - rnd.nextDouble() * 40), 10 + 6 * rnd.nextDouble(), Paint()
                ..color = [const Color(0xFFE84A6F), const Color(0xFFF4E04D), const Color(0xFFF7F4EE), const Color(0xFFD86A8E), const Color(0xFF9B6BD8), const Color(0xFF4B8C4A)][rnd.nextInt(6)]);
            }
            c.drawRect(Rect.fromLTWH(x + 5, y - 46, 40, 46), Paint()..color = const Color(0xFF8E9399));
          }
        }
    }
    c.restore();
    // The names.
    for (var n = 0; n < k.names.length; n++) {
      final (a0, b0, a1, b1) = k.name(n);
      final nr = Rect.fromLTRB(a0 * s.width, b0 * s.height, a1 * s.width, b1 * s.height);
      c.drawRect(nr, Paint()..color = const Color(0xFF1E2433));
      _label(c, k.names[n], nr.deflate(14), 64, const Color(0xFFF4EEDF));
    }
  }
  _paintExtras(c, s);
}

/// The pub's name (gold on green) and the bakery's pretzel sign (a gilt
/// disc), in the atlas's last row.
void _paintExtras(Canvas c, Size s) {
  final (a0, b0, a1, b1) = ShopMaterials.pubName;
  final pub = Rect.fromLTRB(a0 * s.width, b0 * s.height, a1 * s.width, b1 * s.height);
  c.drawRect(pub, Paint()..color = const Color(0xFF1E4D3A));
  _label(c, 'THE GLYPH & ANCHOR', pub.deflate(14), 58, const Color(0xFFD9B45A));
  final (p0, q0, p1, q1) = ShopMaterials.pretzel;
  final sign = Rect.fromLTRB(p0 * s.width, q0 * s.height, p1 * s.width, q1 * s.height);
  final m = sign.center, r = sign.width / 2;
  c
    ..drawRect(sign, Paint()..color = const Color(0xFF15171B))
    ..drawCircle(m, r * 0.96, Paint()..color = const Color(0xFFC9A24A))
    ..drawCircle(m, r * 0.84, Paint()..color = const Color(0xFF2B2A2A));
  final dough = Paint()
    ..color = const Color(0xFFB8722E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.16
    ..strokeCap = StrokeCap.round;
  final knot = Path()
    ..moveTo(m.dx - r * 0.5, m.dy + r * 0.35)
    ..cubicTo(m.dx - r * 0.75, m.dy - r * 0.55, m.dx - r * 0.05, m.dy - r * 0.6, m.dx + r * 0.15, m.dy + r * 0.05)
    ..moveTo(m.dx + r * 0.5, m.dy + r * 0.35)
    ..cubicTo(m.dx + r * 0.75, m.dy - r * 0.55, m.dx + r * 0.05, m.dy - r * 0.6, m.dx - r * 0.15, m.dy + r * 0.05)
    ..moveTo(m.dx - r * 0.5, m.dy + r * 0.35)
    ..quadraticBezierTo(m.dx, m.dy + r * 0.6, m.dx + r * 0.5, m.dy + r * 0.35);
  c.drawPath(knot, dough);
}

/// A wall of wooden shelves, [fill]ing each with what's on it.
void _shelves(Canvas c, Rect r, math.Random rnd, Color wall, void Function(Canvas c, Rect box, math.Random rnd) fill) {
  c.drawRect(r, Paint()..color = wall);
  final cs = Rect.fromLTRB(r.left + 20, r.top + 40, r.right - 20, r.bottom);
  c.drawRect(cs, Paint()..color = const Color(0xFF4A3324));
  const rows = 5;
  final rowH = cs.height / rows;
  for (var i = 0; i < rows; i++) {
    final top = cs.top + i * rowH;
    final inner = Rect.fromLTWH(cs.left + 12, top + 8, cs.width - 24, rowH - 22);
    c.drawRect(inner, Paint()..color = const Color(0xFF2E2018));
    fill(c, inner, rnd);
    c.drawRect(Rect.fromLTWH(cs.left, top + rowH - 14, cs.width, 14), Paint()..color = const Color(0xFF6B4A33));
  }
  for (var x = cs.left; x <= cs.right; x += cs.width / 4) {
    c.drawRect(Rect.fromLTWH(x - 6, cs.top, 12, cs.height), Paint()..color = const Color(0xFF6B4A33));
  }
}

/// [text] centred in [box], as big as [size] allows.
void _label(Canvas c, String text, Rect box, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: BP.display, fontSize: size, color: color, fontWeight: FontWeight.w700, fontVariations: const [FontVariation('wght', 700)], letterSpacing: size * 0.06),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  final k = math.min(1.0, math.min(box.width / tp.width, box.height / tp.height));
  c
    ..save()
    ..translate(box.center.dx, box.center.dy)
    ..scale(k);
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  c.restore();
  tp.dispose();
}
