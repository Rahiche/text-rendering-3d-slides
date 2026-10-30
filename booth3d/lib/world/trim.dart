import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'shapes.dart' show bevelBox;

/// The finish round a box building's photographed facade, so it reads as
/// built rather than wallpapered: a stone base round its ground floor and a
/// ledge over it; strips up its corners; a cornice and a parapet round its
/// roof, gravel inside; and on the roof, towards the back, what a real one
/// carries (an air handler, a water tank on legs, the stair's housing).
/// The building is [w] wide (local x), [h] tall and [d] deep (local z), its
/// bottom's middle at [at]'s origin; all of it painted onto [mat] in [b].
/// A glass building ([glass]) gets dark metal where a stone one gets stone;
/// [base] false leaves its ground floor open; [kit] false leaves its roof
/// bare (something else is up there).
void addTrim(Batch b, Material mat, vm.Matrix4 at, double w, double h, double d, {required int seed, bool glass = false, bool base = true, bool kit = true}) {
  void box(double sx, double sy, double sz, double x, double y, double z, int rgb) =>
      b.add(mat, painted(bevelBox(sx, sy, sz).transformed(at * vm.Matrix4.translation(vm.Vector3(x, y, z))), v4(hex3(rgb))));
  final trim = glass ? 0x3A4048 : 0xC2BBAE, ledge = glass ? 0x4A5058 : 0xB3AC9F;
  const floor = 3.2;
  if (base) {
    box(w + 0.24, floor, d + 0.24, 0, floor / 2, 0, glass ? 0x3E4247 : 0x55585D);
    box(w + 0.34, 0.2, d + 0.34, 0, floor + 0.1, 0, ledge);
  }
  // Corner strips, from the ledge (or the ground) to the cornice.
  final y0 = base ? floor + 0.2 : 0.0, up = h - y0;
  if (up > 1) {
    for (final sx in [-1.0, 1.0]) {
      for (final sz in [-1.0, 1.0]) {
        box(0.42, up, 0.42, sx * (w / 2 - 0.05), y0 + up / 2, sz * (d / 2 - 0.05), trim);
      }
    }
  }
  // The cornice; the parapet round the roof (low: rooftop signs stand
  // over it); the gravel inside, up to where the roof always was.
  box(w + 0.44, 0.36, d + 0.44, 0, h + 0.18, 0, ledge);
  for (final s in [-1.0, 1.0]) {
    box(w + 0.44, 0.6, 0.22, 0, h + 0.66, s * (d / 2 + 0.11), trim);
    box(0.22, 0.6, d, s * (w / 2 + 0.11), h + 0.66, 0, trim);
  }
  box(w, 0.14, d, 0, h + 0.43, 0, 0x77746E);
  // On the roof, towards the back (the front's middle stays clear for a
  // sign): a few of these, by the building.
  if (!kit || w < 7 || d < 7) return;
  final top = h + 0.5;
  final k = rnd(seed, 11);
  final bx = (rnd(seed, 12) - 0.5) * (w - 5), bz = d / 2 - 2.2;
  // An air handler: a grey box, its fan's dark ring on top.
  box(2.4, 1.3, 1.6, bx, top + 0.65, bz, 0xA3A5A6);
  box(0.9, 0.12, 0.9, bx + 0.5, top + 1.36, bz, 0x2E3236);
  // In the other back corner: a water tank on four legs, or (a taller
  // building) the stair's housing, its door to the roof.
  final tx = -(bx < 0 ? -1.0 : 1.0) * (w / 2 - 2.0), tz = d / 2 - 2.4;
  if (k > 0.4) {
    for (final lx in [-0.55, 0.55]) {
      for (final lz in [-0.55, 0.55]) {
        box(0.12, 1.2, 0.12, tx + lx, top + 0.6, tz + lz, 0x3A3F45);
      }
    }
    b.add(mat, part(CylinderGeometry(bottomRadius: 0.95, topRadius: 0.95, height: 1.8, radialSegments: 16), at * vm.Matrix4.translation(vm.Vector3(tx, top + 2.1, tz)), v4(hex3(0x8F8A80))));
  } else if (h > 10) {
    box(2.6, 2.6, 2.8, tx, top + 1.3, tz, 0xB9B5AD);
    box(0.9, 1.9, 0.06, tx, top + 0.95, tz - 1.42, 0x4A4F57);
  }
}
