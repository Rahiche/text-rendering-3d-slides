import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:text_slides/booth/craft/extrude.dart';
import 'package:text_slides/booth/craft/geometry.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'shapes.dart' show bevelBox;
import 'vignette.dart';

/// The engines' mascots for the seesaw (v_seesaw.dart); Flutter's is Dash
/// (dashes.dart). Each is one mesh in vertex colours, standing on its
/// origin, about 0.6 m tall, facing −z:
///
/// * Android's robot: the dome head with its antennae and eyes, the body,
///   arms and legs, in Android green;
/// * Chrome's dinosaur from its offline game, a block for each of its
///   pixels, side on (its head towards −x);
/// * a Happy Mac for macOS (Apple has no mascot; this is the old Mac's
///   smile at start-up): the beige box, the face on its screen, the floppy
///   slot;
/// * Figma's multiplayer cursor: the arrow in Figma's purple, rimmed in
///   white, standing on its tail.
abstract final class Mascots {
  static vm.Vector4 _c(int rgb) => Vignette.c(rgb);

  static MeshData android() {
    const r = 0.15;
    final green = _c(0x3DDC84), white = _c(0xFFFFFF);
    final parts = <MeshData>[
      // The legs, the body, the dome; the arms either side.
      for (final x in [-0.065, 0.065]) part(CapsuleGeometry(radius: 0.042, height: 0.07, radialSegments: 20, capRings: 6), trs(vm.Vector3(x, 0.077, 0)), green),
      part(CylinderGeometry(bottomRadius: r, topRadius: r, height: 0.24, radialSegments: 40), trs(vm.Vector3(0, 0.23, 0)), green),
      painted(_dome(r).transformed(trs(vm.Vector3(0, 0.37, 0))), green),
      for (final x in [-0.205, 0.205]) part(CapsuleGeometry(radius: 0.04, height: 0.12, radialSegments: 20, capRings: 6), trs(vm.Vector3(x, 0.255, 0)), green),
      // The eyes, on the dome's front; the antennae, out from its top.
      for (final x in [-0.055, 0.055]) part(SphereGeometry(radius: 0.017, segments: 16, rings: 8), trs(vm.Vector3(x, 0.445, -0.112)), white),
      for (final s in [-1.0, 1.0]) ...[
        part(CylinderGeometry(bottomRadius: 0.008, topRadius: 0.008, height: 0.07, radialSegments: 10), trs(vm.Vector3(s * 0.113, 0.513, 0), rotZ: -s * 0.55), green),
        part(SphereGeometry(radius: 0.011, segments: 12, rings: 6), trs(vm.Vector3(s * 0.131, 0.542, 0)), green),
      ],
    ];
    return MeshData.merge(parts);
  }

  /// The upper half of a sphere of radius [r], its flat side down at y 0,
  /// closed underneath.
  static MeshData _dome(double r) {
    final s = SphereGeometry(radius: r, segments: 40, rings: 20).extractMeshData();
    final idx = s.indices!, p = s.positions;
    bool up(int v) => p[v * 3 + 1] >= -1e-5;
    final kept = <int>[
      for (var t = 0; t + 2 < idx.length; t += 3)
        if (up(idx[t]) && up(idx[t + 1]) && up(idx[t + 2])) ...[idx[t], idx[t + 1], idx[t + 2]],
    ];
    final top = MeshData(positions: s.positions, vertexCount: s.vertexCount, normals: s.normals, texCoords: s.texCoords, indices: kept);
    final floor = CylinderGeometry(bottomRadius: r, topRadius: r, height: 0.004, radialSegments: 40).extractMeshData().transformed(trs(vm.Vector3(0, 0.002, 0)));
    // (Both to the same attributes, or they won't merge.)
    final white = vm.Vector4(1, 1, 1, 1);
    return MeshData.merge([painted(top, white), painted(floor, white)]);
  }

  /// Chrome's dinosaur, as its offline game draws it standing (head to the
  /// right here; 'o' its eye).
  static const _dinoRows = [
    '...........########.',
    '..........##o#######',
    '..........##########',
    '..........##########',
    '..........##########',
    '..........#####.....',
    '..........########..',
    '#........#####......',
    '#.......######......',
    '##.....########.....',
    '###...#######.#.....',
    '####.#########......',
    '##############......',
    '.############.......',
    '..###########.......',
    '...#########........',
    '....#######.........',
    '.....###.##.........',
    '.....##...#.........',
    '.....#....#.........',
    '.....##...##........',
  ];

  static MeshData dino() {
    const v = 0.032, depth = 0.12;
    final ink = _c(0x535353), eye = _c(0xFFFFFF);
    final w = _dinoRows.first.length, h = _dinoRows.length;
    final parts = <MeshData>[];
    for (var row = 0; row < h; row++) {
      final line = _dinoRows[row];
      final y = (h - row - 0.5) * v;
      var col = 0;
      while (col < w) {
        final ch = line[col];
        if (ch == '.') {
          col++;
          continue;
        }
        // (A run of the row's pixels as one block; the eye its own.)
        var end = col;
        while (ch == '#' && end + 1 < w && line[end + 1] == '#') {
          end++;
        }
        final mid = (col + end) / 2 + 0.5 - w / 2;
        parts.add(part(CuboidGeometry(vm.Vector3((end - col + 1) * v, v, ch == 'o' ? depth + 0.006 : depth)), trs(vm.Vector3(-mid * v, y, 0)), ch == 'o' ? eye : ink));
        col = end + 1;
      }
    }
    return MeshData.merge(parts);
  }

  static MeshData mac() {
    final beige = _c(0xE6DFCB), bezel = _c(0x8E8A80), glass = _c(0xE9EEE6), ink = _c(0x1C1C1C), slot = _c(0x3A372F);
    const front = -0.19;
    MeshData block(double w, double h, double d, double x, double y, double z, vm.Vector4 c, {double rotZ = 0}) => part(CuboidGeometry(vm.Vector3(w, h, d)), trs(vm.Vector3(x, y, z), rotZ: rotZ), c);
    final parts = <MeshData>[
      // The box; its screen in a darker frame; the floppy slot under it.
      painted(bevelBox(0.38, 0.48, 0.38).transformed(trs(vm.Vector3(0, 0.24, 0))), beige),
      block(0.27, 0.21, 0.01, 0, 0.31, front - 0.001, bezel),
      block(0.24, 0.18, 0.01, 0, 0.31, front - 0.004, glass),
      block(0.1, 0.012, 0.01, 0.07, 0.12, front - 0.001, slot),
      // The face: eyes, the nose's hook, the smile.
      for (final x in [-0.04, 0.04]) block(0.012, 0.04, 0.006, x, 0.338, front - 0.009, ink),
      block(0.012, 0.045, 0.006, 0.008, 0.31, front - 0.009, ink),
      block(0.028, 0.01, 0.006, -0.002, 0.291, front - 0.009, ink),
      for (var k = 0; k < 9; k++) () {
        final x = -0.056 + 0.014 * k, f = x / 0.06;
        return block(0.016, 0.01, 0.006, x, 0.262 + 0.014 * f * f, front - 0.009, ink, rotZ: math.atan(2 * 0.014 * f / 0.06));
      }(),
    ];
    return MeshData.merge(parts);
  }

  /// The arrow (px, y down: the tip at the top left), as Figma draws a
  /// collaborator's cursor.
  static const _arrow = [(0.0, 0.0), (0.0, 17.0), (4.2, 13.3), (7.3, 20.2), (10.2, 19.0), (7.2, 12.2), (12.4, 12.2)];

  static MeshData cursor() {
    const unit = 0.03;
    final rim = _offset(_arrow, 1.3);
    final xs = [for (final p in rim) p.$1], ys = [for (final p in rim) p.$2];
    final box = (xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
    MeshData solid(List<(double, double)> pts, double depth, double z, vm.Vector4 c) {
      final flat = Float64List.fromList([for (final p in pts) ...[p.$1, p.$2]]);
      var area = 0.0;
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        area += a.$1 * b.$2 - b.$1 * a.$2;
      }
      // (Both laid out round the rim's box, so they line up.)
      final g = GlyphGeometry(
        w: (box.$3 - box.$1).ceil() + 2,
        h: (box.$4 - box.$2).ceil() + 2,
        contours: [Contour(flat, hole: false, area: area.abs() / 2)],
        strokes: const [],
        spans: const [],
        inkLeft: box.$1,
        inkTop: box.$2,
        inkRight: box.$3,
        inkBottom: box.$4,
      );
      final m = extrudeGlyph(g, unitsPerPx: unit, depth: depth, simplify: 0);
      return painted(MeshData(positions: m.positions, vertexCount: m.vertexCount, normals: m.normals, texCoords: m.uvs, indices: m.indices).transformed(trs(vm.Vector3(0, 0, z))), c);
    }

    final both = MeshData.merge([solid(_arrow, 0.05, 0, _c(0xA259FF)), solid(rim, 0.03, 0.016, _c(0xFFFFFF))]);
    // Stood on its tail: turned until its lowest corners are level, then
    // set down on the ground.
    final turned = both.transformed(trs(vm.Vector3.zero(), rotZ: 0.29));
    var low = double.infinity;
    for (var i = 0; i < turned.vertexCount; i++) {
      low = math.min(low, turned.positions[i * 3 + 1]);
    }
    return turned.transformed(trs(vm.Vector3(0, -low, 0)));
  }

  /// [pts] (a closed outline) pushed out by [d] along each corner's mitre.
  static List<(double, double)> _offset(List<(double, double)> pts, double d) {
    final n = pts.length;
    var area = 0.0;
    for (var i = 0; i < n; i++) {
      area += pts[i].$1 * pts[(i + 1) % n].$2 - pts[(i + 1) % n].$1 * pts[i].$2;
    }
    final out = area > 0 ? 1.0 : -1.0;
    (double, double) normal((double, double) a, (double, double) b) {
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2, l = math.sqrt(dx * dx + dy * dy);
      return (out * dy / l, -out * dx / l);
    }

    return [
      for (var i = 0; i < n; i++)
        () {
          final p = pts[i], a = normal(pts[(i - 1 + n) % n], p), b = normal(p, pts[(i + 1) % n]);
          final mx = a.$1 + b.$1, my = a.$2 + b.$2, ml = math.sqrt(mx * mx + my * my);
          final k = d / math.max(0.35, (mx * a.$1 + my * a.$2) / ml);
          return (p.$1 + mx / ml * k, p.$2 + my / ml * k);
        }(),
    ];
  }
}
