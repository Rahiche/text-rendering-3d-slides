import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show Image, ImageByteFormat, Paint, PaintingStyle, Path, PictureRecorder;
import 'dart:ui' show Color, Rect;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/painting.dart' show Canvas, Offset, Size, TextBaseline, TextDirection, TextPainter, TextSpan, TextStyle;
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/booth/craft/extrude.dart';
import 'package:text_slides/booth/craft/geometry.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'ease.dart';

export 'ease.dart';

/// Shared helpers for the 3D city: colours, materials, meshes, maths.

/// An sRGB colour as a linear RGBA factor (PBR materials work in linear).
vm.Vector4 lin(Color c, [double? alpha]) {
  double f(double v) => math.pow(v, 2.2).toDouble();
  return vm.Vector4(f(c.r), f(c.g), f(c.b), alpha ?? c.a);
}

vm.Vector4 rgb(double r, double g, double b, [double a = 1]) => vm.Vector4(r, g, b, a);

PhysicallyBasedMaterial pbr(
  vm.Vector4 color, {
  double metallic = 0,
  double roughness = 0.7,
  vm.Vector4? emissive,
  double emissiveStrength = 1,
}) {
  final m = PhysicallyBasedMaterial()
    ..baseColorFactor = color
    ..metallicFactor = metallic
    ..roughnessFactor = roughness;
  if (emissive != null) {
    m
      ..emissiveFactor = emissive
      ..emissiveStrength = emissiveStrength;
  }
  return m;
}

/// A photographed surface from [dir] (assets/textures, or assets/models for
/// a scanned prop's; Poly Haven, CC0: see CREDITS.md there):
/// `[name]_albedo.jpg` (colour), `_normal.jpg` (OpenGL) and
/// `_arm.jpg` (ambient occlusion, roughness, metal, as glTF reads them),
/// [tint] multiplied over its colour. Laid by the geometry's UVs: a tile per
/// unit, so lay them in world space at the surface's real size. (Each
/// surface's textures are loaded once: materials made from it share them.)
Future<PhysicallyBasedMaterial> photoPbr(String name, {String dir = 'assets/textures', vm.Vector4? tint, double normalScale = 1, double occlusion = 1, double roughness = 1}) async {
  final (albedo, normal, arm) = await (_photoTextures['$dir/$name'] ??= (
    Texture2D.fromAsset('$dir/${name}_albedo.jpg'),
    Texture2D.fromAsset('$dir/${name}_normal.jpg', content: TextureContent.normal),
    Texture2D.fromAsset('$dir/${name}_arm.jpg', content: TextureContent.data),
  ).wait);
  return PhysicallyBasedMaterial()
    ..baseColorTexture = albedo
    ..baseColorFactor = tint ?? vm.Vector4(1, 1, 1, 1)
    ..normalTexture = normal
    ..normalScale = normalScale
    ..metallicRoughnessTexture = arm
    ..metallicFactor = 1
    ..roughnessFactor = roughness
    ..occlusionTexture = arm
    ..occlusionStrength = occlusion;
}

final _photoTextures = <String, Future<(Texture2D, Texture2D, Texture2D)>>{};

/// A glyph mesh (from the booth's extruder) as engine geometry.
MeshGeometry glyphGeometry(GlyphMesh m) => MeshGeometry.fromArrays(
  positions: m.positions,
  normals: m.normals,
  texCoords: m.uvs,
  indices: m.indices,
);

vm.Matrix4 trs(vm.Vector3 t, {double rotY = 0, double rotX = 0, double rotZ = 0, vm.Vector3? s}) {
  final q = vm.Quaternion.euler(rotY, rotX, rotZ);
  return vm.Matrix4.compose(t, q, s ?? vm.Vector3.all(1));
}

vm.Matrix4 trsQ(vm.Vector3 t, vm.Quaternion q, vm.Vector3 s) => vm.Matrix4.compose(t, q, s);

/// A zero-size transform (hidden instance).
final hidden = vm.Matrix4.compose(vm.Vector3(0, -1000, 0), vm.Quaternion.identity(), vm.Vector3.zero());

// ── Colour ─────────────────────────────────────────────────────────────────

/// An sRGB colour as a linear RGB vector (for skies, fog, lights).
vm.Vector3 lin3(Color c, [double k = 1]) {
  double f(double v) => math.pow(v, 2.2).toDouble() * k;
  return vm.Vector3(f(c.r), f(c.g), f(c.b));
}

/// 0xRRGGBB (sRGB) as a linear RGB vector.
vm.Vector3 hex3(int rgb, [double k = 1]) => lin3(Color(0xFF000000 | rgb), k);

vm.Vector3 mix3(vm.Vector3 a, vm.Vector3 b, double t) =>
    vm.Vector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);

vm.Vector4 v4(vm.Vector3 c, [double a = 1]) => vm.Vector4(c.x, c.y, c.z, a);

// ── Transforms written in place (per-frame instance updates, no garbage) ──

/// [m] = translate(x, y, z) · rotateY(rotY) · scale(s).
void setTrsY(vm.Matrix4 m, double x, double y, double z, double rotY, [double s = 1]) {
  final c = math.cos(rotY) * s, n = math.sin(rotY) * s;
  m.storage
    ..[0] = c
    ..[1] = 0
    ..[2] = -n
    ..[3] = 0
    ..[4] = 0
    ..[5] = s
    ..[6] = 0
    ..[7] = 0
    ..[8] = n
    ..[9] = 0
    ..[10] = c
    ..[11] = 0
    ..[12] = x
    ..[13] = y
    ..[14] = z
    ..[15] = 1;
}

/// [m] = translate · rotateY(rotY) · rotateZ(rotZ) · scale(s): a part that
/// swings about its owner's sideways axis (legs, arms).
void setTrsYZ(vm.Matrix4 m, double x, double y, double z, double rotY, double rotZ, [double s = 1]) {
  final c = math.cos(rotY), n = math.sin(rotY), cz = math.cos(rotZ), sz = math.sin(rotZ);
  m.storage
    ..[0] = c * cz * s
    ..[1] = sz * s
    ..[2] = -n * cz * s
    ..[3] = 0
    ..[4] = -c * sz * s
    ..[5] = cz * s
    ..[6] = n * sz * s
    ..[7] = 0
    ..[8] = n * s
    ..[9] = 0
    ..[10] = c * s
    ..[11] = 0
    ..[12] = x
    ..[13] = y
    ..[14] = z
    ..[15] = 1;
}

/// [m] = translate · rotateY(rotY) · rotateX(rotX) · scale(s): a part that
/// rolls about its owner's forward (+X) axis (wings).
void setTrsYX(vm.Matrix4 m, double x, double y, double z, double rotY, double rotX, [double s = 1]) {
  final c = math.cos(rotY), n = math.sin(rotY), cx = math.cos(rotX), sx = math.sin(rotX);
  m.storage
    ..[0] = c * s
    ..[1] = 0
    ..[2] = -n * s
    ..[3] = 0
    ..[4] = n * sx * s
    ..[5] = cx * s
    ..[6] = c * sx * s
    ..[7] = 0
    ..[8] = n * cx * s
    ..[9] = -sx * s
    ..[10] = c * cx * s
    ..[11] = 0
    ..[12] = x
    ..[13] = y
    ..[14] = z
    ..[15] = 1;
}

/// Heading (rotY) that turns local +X towards the direction (dx, dz).
double headingTo(double dx, double dz) => math.atan2(-dz, dx);

// ── Meshes ────────────────────────────────────────────────────────────────

/// [g]'s triangles moved by [xf] and painted [color] (vertex colours), ready
/// to merge with other parts into one geometry.
MeshData part(MeshGeometry g, vm.Matrix4 xf, [vm.Vector4? color]) {
  final d = g.extractMeshData().transformed(xf);
  final c = color ?? vm.Vector4(1, 1, 1, 1);
  final colors = Float32List(d.vertexCount * 4);
  for (var i = 0; i < d.vertexCount; i++) {
    colors
      ..[i * 4] = c.x
      ..[i * 4 + 1] = c.y
      ..[i * 4 + 2] = c.z
      ..[i * 4 + 3] = c.w;
  }
  return MeshData(
    positions: d.positions,
    vertexCount: d.vertexCount,
    normals: d.normals,
    texCoords: d.texCoords ?? Float32List(d.vertexCount * 2),
    colors: colors,
    indices: d.indices,
  );
}

/// Several [part]s as one geometry (one draw).
MeshGeometry merged(List<MeshData> parts) => MeshGeometry.fromMeshData(MeshData.merge(parts));

// ── Text → outlines → solid 3D text ───────────────────────────────────────

/// What to extrude: [text] in [style] (rendered at the style's size),
/// [height] world units tall (ink), [depth] thick.
class TextSolid {
  const TextSolid(this.text, this.style, {required this.height, required this.depth, this.simplify = 0.8});
  final String text;
  final TextStyle style;
  final double height;
  final double depth;
  final double simplify;
}

class _SolidJob {
  _SolidJob(this.input, this.height, this.depth, this.simplify);
  final VectorizeInput input;
  final double height, depth, simplify;
}

/// Each [TextSolid] rendered whole with the real text stack (so scripts are
/// shaped: Arabic joins, Devanagari conjuncts…), traced to outlines and
/// extruded to a solid on a background isolate. Empty text gives an empty
/// mesh.
Future<List<GlyphMesh>> extrudeTexts(List<TextSolid> specs) async {
  final jobs = <_SolidJob>[];
  for (final s in specs) {
    final tp = TextPainter(
      text: TextSpan(text: s.text, style: s.style.copyWith(color: const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
    )..layout();
    final (px, py) = _inkRoom(s.style);
    final w = tp.width.ceil() + 2 * px, h = tp.height.ceil() + 2 * py;
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), Offset(px.toDouble(), py.toDouble()));
    tp.dispose();
    final image = await rec.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final rgba = data!.buffer.asUint8List();
    final alpha = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    jobs.add(_SolidJob(VectorizeInput(w, h, alpha), s.height, s.depth, s.simplify));
  }
  return compute(_solids, jobs);
}

/// Room round a line of [style] for ink that leaves its box (px across,
/// px up and down): a mark over a letter, as ि's hook rises over कि's
/// headstroke, or a tail under it, may reach well past the line's height,
/// and anything off the image would be cut off flat.
(int, int) _inkRoom(TextStyle style) {
  final size = style.fontSize ?? 14;
  return (6 + (0.25 * size).ceil(), 6 + (0.6 * size).ceil());
}

List<GlyphMesh> _solids(List<_SolidJob> jobs) => [
  for (final j in jobs)
    () {
      final g = _outline(j.input);
      if (g.isEmpty) return extrudeGlyph(g);
      return extrudeGlyph(g, unitsPerPx: j.height / g.inkHeight, depth: j.depth, simplify: j.simplify);
    }(),
];

/// A text extruded at a fixed scale, and where its pen starts: put the mesh
/// at ([ox], [oy]) for the text's origin (its start, on the baseline) to be
/// at 0. [advance]: how far the pen moves over it. (World units.)
class PlacedSolid {
  const PlacedSolid(this.mesh, this.ox, this.oy, this.advance);
  final GlyphMesh mesh;
  final double ox, oy, advance;
}

/// Each of [texts] (in its style, rendered at the style's size) shaped,
/// traced and extruded [depth] thick at [unitsPerPx] world units per pixel:
/// pieces keep their sizes relative to each other and can be set on a
/// common baseline (letters alone and the word they make, a mark and its
/// base…).
Future<List<PlacedSolid>> extrudeTextsAt(List<(String, TextStyle)> texts, {required double unitsPerPx, double depth = 0.1, double simplify = 0.7}) async {
  final jobs = <_SolidJob>[];
  final pens = <(double, double, int)>[];
  for (final (text, style) in texts) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
    )..layout();
    final (px, py) = _inkRoom(style);
    final w = tp.width.ceil() + 2 * px, h = tp.height.ceil() + 2 * py;
    pens.add((tp.width, py + tp.computeDistanceToActualBaseline(TextBaseline.alphabetic), px));
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), Offset(px.toDouble(), py.toDouble()));
    tp.dispose();
    final image = await rec.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final rgba = data!.buffer.asUint8List();
    final alpha = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    jobs.add(_SolidJob(VectorizeInput(w, h, alpha), unitsPerPx, depth, simplify));
  }
  final solids = await compute(_solidsAt, jobs);
  return [
    for (var i = 0; i < solids.length; i++)
      () {
        final (mesh, inkCx, inkBottom) = solids[i];
        final (advance, baseline, px) = pens[i];
        return PlacedSolid(mesh, (inkCx - px) * unitsPerPx, (baseline - inkBottom) * unitsPerPx, advance * unitsPerPx);
      }(),
  ];
}

/// [_solids] at a fixed scale (the jobs' height is the units per pixel),
/// with each ink's middle and bottom (pixels).
List<(GlyphMesh, double, double)> _solidsAt(List<_SolidJob> jobs) => [
  for (final j in jobs)
    () {
      final g = _outline(j.input);
      if (g.isEmpty) return (extrudeGlyph(g), 0.0, 0.0);
      return (extrudeGlyph(g, unitsPerPx: j.height, depth: j.depth, simplify: j.simplify), g.inkLeft + g.inkWidth / 2, g.inkBottom);
    }(),
];

GlyphGeometry _outline(VectorizeInput input) {
  final w = input.w, h = input.h, a = input.alpha;
  var l = w, t = h, r = -1, b = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (a[y * w + x] >= 128) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  final empty = r < 0;
  return GlyphGeometry(
    w: w,
    h: h,
    contours: empty ? const [] : traceContours(w, h, a),
    strokes: const [],
    spans: const [],
    inkLeft: empty ? 0 : l.toDouble(),
    inkTop: empty ? 0 : t.toDouble(),
    inkRight: empty ? 0 : r + 1.0,
    inkBottom: empty ? 0 : b + 1.0,
  );
}

/// A thin board [w]×[h] whose front (−Z, the side the camera sees) shows a
/// whole texture upright; its edges and back take the colour at the middle
/// of the texture's top edge (the board's own: corners may be rounded off
/// and see-through).
MeshGeometry boardGeometry(double w, double h, {double thick = 0.05}) {
  final d = CuboidGeometry(vm.Vector3(w, h, thick)).extractMeshData();
  final uv = d.texCoords!, n = d.normals!, p = d.positions;
  for (var i = 0; i < d.vertexCount; i++) {
    if (n[i * 3 + 2] < -0.5) {
      uv[i * 2] = p[i * 3] / w + 0.5;
      uv[i * 2 + 1] = 0.5 - p[i * 3 + 1] / h;
    } else {
      uv[i * 2] = 0.5;
      uv[i * 2 + 1] = 0.006;
    }
  }
  return MeshGeometry.fromMeshData(d);
}

/// A texture painted with a Flutter canvas ([w]×[h] px).
Future<Texture2D> paintedTexture(int w, int h, void Function(Canvas c, Size s) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final ui.Image image = await rec.endRecording().toImage(w, h);
  try {
    return await Texture2D.fromImage(image);
  } finally {
    image.dispose();
  }
}

/// Oak boards, as a table top's run: a warm pale ground, each board its
/// own shade and figure — fine grain wandering along u (in whole waves, so
/// the tile meets itself), cathedral arches on some boards, the pores'
/// short dark dashes, the odd pale ray — and a joint between the boards
/// across v. Laid 2 m along u and 0.5 m across v (so a piece's UVs are its
/// size in those units: [laidAlong]), 2 px to the mm: sharp close up.
Future<Texture2D> oakTexture() => _oak ??= paintedTexture(4096, 1024, _paintOak);
Future<Texture2D>? _oak;

void _paintOak(Canvas c, Size s) {
  final r = math.Random(11);
  final w = s.width, tau = 2 * math.pi;
  const boards = 3;
  final bh = s.height / boards;
  ui.Paint ink(double alpha, double width, [int rgb = 0x784E2A]) => ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..color = Color((alpha.clamp(0, 1) * 255).round() << 24 | rgb);
  for (var b = 0; b < boards; b++) {
    final top = b * bh, shade = 0.93 + 0.12 * r.nextDouble();
    int tone(int v) => (v * shade).round().clamp(0, 255);
    c.drawRect(Rect.fromLTWH(0, top, w, bh), ui.Paint()..color = Color.fromARGB(255, tone(206), tone(168), tone(124)));
    c.save();
    c.clipRect(Rect.fromLTWH(0, top, w, bh));
    // Broad streaks of lighter and darker wood along the board (whole
    // waves across the tile).
    for (var k = 0; k < 7; k++) {
      final y0 = top + r.nextDouble() * bh, n = 1 + r.nextInt(3), ph = r.nextDouble() * tau, dark = r.nextBool();
      final path = ui.Path()..moveTo(0, y0 + 10 * math.sin(ph));
      for (var x = 0.0; x <= w; x += 32) {
        path.lineTo(x, y0 + 10 * math.sin(tau * n * x / w + ph));
      }
      c.drawPath(path, ink(0.05 + 0.05 * r.nextDouble(), 18 + 40 * r.nextDouble(), dark ? 0x6E4524 : 0xF4DDB8));
    }
    // The grain: fine lines along the board, each wandering in a few whole
    // waves of its own.
    final waves = [for (var k = 0; k < 3; k++) (1 + r.nextInt(4), r.nextDouble() * tau)];
    for (var k = 0; k < 170; k++) {
      final y0 = top + r.nextDouble() * bh, a1 = 2 + 9 * r.nextDouble(), a2 = 0.6 + 2.4 * r.nextDouble();
      final (n1, p1) = waves[k % 3];
      final n2 = 3 + r.nextInt(9), p2 = r.nextDouble() * tau;
      final path = ui.Path();
      for (var x = 0.0; x <= w; x += 12) {
        final y = y0 + a1 * math.sin(tau * n1 * x / w + p1) + a2 * math.sin(tau * n2 * x / w + p2);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final late = r.nextDouble();
      c.drawPath(path, ink(0.07 + 0.22 * late * late, 0.6 + 2.2 * r.nextDouble()));
    }
    // Flat-sawn boards: nested cathedral arches, opening along u.
    if (b != 1) {
      final xc = w * (0.08 + 0.4 * r.nextDouble()), yc = top + bh * (0.38 + 0.24 * r.nextDouble());
      for (var j = 0; j < 13; j++) {
        final tip = xc + 46.0 * j, reach = 1100.0 + 70 * j, spread = bh * (0.05 + 0.034 * j);
        final path = ui.Path();
        for (var i = -40; i <= 40; i++) {
          final f = i.abs() / 40, x = tip + reach * f;
          final y = yc + i.sign * spread * math.sqrt(f) + 3 * math.sin(tau * 5 * x / w + j);
          i == -40 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        c.drawPath(path, ink(0.12 + 0.14 * r.nextDouble(), 1.2 + 2.0 * r.nextDouble()));
      }
    }
    // Pores: short dark dashes along the grain; the odd pale ray.
    final pore = ui.Paint();
    for (var k = 0; k < 2600; k++) {
      final x = r.nextDouble() * w, y = top + r.nextDouble() * bh;
      pore.color = Color((0x10 + r.nextInt(0x26)) << 24 | 0x5A3418);
      c.drawRect(Rect.fromLTWH(x, y, 3 + 9 * r.nextDouble(), 0.9 + 0.6 * r.nextDouble()), pore);
    }
    for (var k = 0; k < 50; k++) {
      final x = r.nextDouble() * w, y = top + r.nextDouble() * bh;
      c.drawRect(Rect.fromLTWH(x, y, 10 + 30 * r.nextDouble(), 1.6 + r.nextDouble()), ui.Paint()..color = const Color(0x24FFF1DC));
    }
    c.restore();
    // The joint between this board and the one before (the first's with
    // the last, across the tile's edge).
    final joint = ui.Paint()..color = const Color(0x66583820);
    if (b > 0) {
      c.drawRect(Rect.fromLTWH(0, top - 1.5, w, 3), joint);
    } else {
      c
        ..drawRect(Rect.fromLTWH(0, 0, w, 1.5), joint)
        ..drawRect(Rect.fromLTWH(0, s.height - 1.5, w, 1.5), joint);
    }
  }
}

/// A painted block wall, as inside a workshop: blocks 40 × 20 cm laid in a
/// running bond, the mortar joints a little grey under the paint, each
/// block its own faint shade, the paint's fine speckle. A tile is 4 m
/// across (u) and 2 m up (v).
Future<Texture2D> blockWallTexture() => _blocks ??= paintedTexture(1024, 512, _paintBlocks);
Future<Texture2D>? _blocks;

void _paintBlocks(Canvas c, Size s) {
  final r = math.Random(5);
  const cols = 10, rows = 10;
  final bw = s.width / cols, bh = s.height / rows;
  c.drawRect(Offset.zero & s, ui.Paint()..color = const Color(0xFFD8D3C8));
  for (var row = 0; row < rows; row++) {
    final shift = row.isOdd ? bw / 2 : 0.0;
    for (var k = -1; k < cols; k++) {
      final x = k * bw + shift, y = row * bh;
      final t = 0.97 + 0.05 * r.nextDouble();
      c.drawRect(
        Rect.fromLTWH(x + 1.4, y + 1.4, bw - 2.8, bh - 2.8),
        ui.Paint()..color = Color.fromARGB(255, (236 * t).round().clamp(0, 255), (232 * t).round().clamp(0, 255), (223 * t).round().clamp(0, 255)),
      );
    }
  }
  // The paint's speckle.
  for (var k = 0; k < 2600; k++) {
    final a = r.nextDouble() < 0.5 ? 0x0C000000 : 0x0CFFFFFF;
    c.drawRect(Rect.fromLTWH(r.nextDouble() * s.width, r.nextDouble() * s.height, 1.5, 1.5), ui.Paint()..color = Color(a));
  }
}

/// [d] (made round its own origin) with UVs that lay a texture [along]
/// metres to a tile in x and [across] in z, from its own coordinates
/// (before it's placed): the grain runs along x, whatever the piece's
/// size; the faces up the sides take the same, stretched.
MeshData laidAlong(MeshData d, {double along = 2.0, double across = 0.5}) {
  final uv = Float32List(d.vertexCount * 2);
  for (var i = 0; i < d.vertexCount; i++) {
    uv
      ..[i * 2] = d.positions[i * 3] / along
      ..[i * 2 + 1] = (d.positions[i * 3 + 2] + d.positions[i * 3 + 1] * 0.3) / across;
  }
  return painted(d, vm.Vector4(1, 1, 1, 1), uvs: uv);
}

// ── Batching static geometry ───────────────────────────────────────────────

/// [d] painted [color] (vertex colours) with texture coordinates present, so
/// it merges with any other part.
MeshData painted(MeshData d, vm.Vector4 color, {Float32List? uvs}) {
  final colors = Float32List(d.vertexCount * 4);
  for (var i = 0; i < d.vertexCount; i++) {
    colors
      ..[i * 4] = color.x
      ..[i * 4 + 1] = color.y
      ..[i * 4 + 2] = color.z
      ..[i * 4 + 3] = color.w;
  }
  return MeshData(
    positions: d.positions,
    vertexCount: d.vertexCount,
    normals: d.normals,
    texCoords: uvs ?? d.texCoords ?? Float32List(d.vertexCount * 2),
    colors: colors,
    indices: d.indices,
  );
}

/// A glyph mesh's triangles [indices] as mesh data with [uvs].
MeshData glyphData(GlyphMesh m, List<int> indices, Float32List uvs) => MeshData(
  positions: m.positions,
  vertexCount: m.vertexCount,
  normals: m.normals,
  texCoords: uvs,
  indices: indices,
);

/// Static parts gathered per material and merged, so a whole district is a
/// handful of draws (the engine encodes every draw in every pass: colour,
/// depth, each shadow cascade).
class Batch {
  final _parts = <Material, List<MeshData>>{};

  void add(Material m, MeshData d) => (_parts[m] ??= []).add(d);

  /// Adds one merged node per material to [scene].
  void build(Scene scene, String name, {bool castsShadows = true, int lightChannelMask = 0xFF}) => _build(scene.add, name, castsShadows, lightChannelMask);

  /// Adds one merged node per material under [parent].
  void buildInto(Node parent, String name, {bool castsShadows = true, int lightChannelMask = 0xFF}) => _build(parent.add, name, castsShadows, lightChannelMask);

  void _build(void Function(Node n) add, String name, bool castsShadows, int lightChannelMask) {
    for (final e in _parts.entries) {
      add(
        Node(name: name, mesh: Mesh(merged(e.value), e.key))
          ..castsShadows = castsShadows
          ..lightChannelMask = lightChannelMask,
      );
    }
    _parts.clear();
  }
}

/// A strip of flat colours as a texture ([px] px per colour, [rows] tall,
/// each row scaled by [profile]), so differently coloured parts can share
/// one material: point a part's u at its colour with [swatchU].
Texture2D swatchTexture(List<vm.Vector3> colors, {int px = 8, int rows = 4, double Function(double v)? profile}) {
  final w = colors.length * px;
  final out = Uint8List(w * rows * 4);
  for (var y = 0; y < rows; y++) {
    final k = profile?.call((y + 0.5) / rows) ?? 1.0;
    for (var x = 0; x < w; x++) {
      final c = colors[x ~/ px];
      final i = (y * w + x) * 4;
      // Linear colour stored as sRGB (the sampler linearises it).
      int enc(double v) => (math.pow(c01(v * k), 1 / 2.2) * 255).round();
      out
        ..[i] = enc(c.x)
        ..[i + 1] = enc(c.y)
        ..[i + 2] = enc(c.z)
        ..[i + 3] = 255;
    }
  }
  return Texture2D.fromPixels(out, w, rows, sampling: const TextureSampling(maxMipmapLevels: 4));
}

/// The u of colour [i] of [n] in a [swatchTexture].
double swatchU(int i, int n) => (i + 0.5) / n;
