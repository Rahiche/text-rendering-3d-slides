import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';

/// Landmarks from elsewhere in the world, in the background (the talk is
/// about every language, not one country's): a London clock tower over
/// ICU City's blocks, its four faces telling the real time; a classical
/// sandstone gate (Berlin's kind) over the avenue on the way to Engine
/// Town; red pillar boxes and German advertising columns here and there.
/// All of them old, out-of-copyright forms, made from boxes and cylinders.
class Landmarks {
  Landmarks(this.scene);

  final Scene scene;

  /// What the cameras keep out of (centre, half extents), and the land
  /// round the towns keeps clear of.
  final solids = <(vm.Vector3, vm.Vector3)>[];

  final _b = Batch();
  late final PhysicallyBasedMaterial _stone, _paint;
  final _hands = <(Node, bool, vm.Matrix4)>[]; // (hand, the hour hand?, where it turns)

  /// The clock tower's place (world), facing south.
  static final clockAt = vm.Vector3(-340, 0, 150);

  /// The gate's place on the avenue (x), on the way to Engine Town.
  static const gateX = 172.0;

  Future<void> init() async {
    _stone = pbr(rgb(1, 1, 1), roughness: 0.8);
    _paint = pbr(rgb(1, 1, 1), roughness: 0.4, metallic: 0.1);
    await _clockTower();
    _gate();
    await _pillarBoxes();
    await _columns();
    _b.build(scene, 'landmarks', castsShadows: false, lightChannelMask: 0x01);
  }

  void _box(Material m, double w, double h, double d, vm.Vector3 at, int rgb, {double rotY = 0}) =>
      _b.add(m, painted(_unit.transformed(trs(at, rotY: rotY, s: vm.Vector3(w, h, d))), v4(hex3(rgb))));

  void _cyl(Material m, double r, double h, vm.Vector3 at, int rgb, {double r2 = -1, int sides = 16}) =>
      _b.add(m, part(CylinderGeometry(bottomRadius: r, topRadius: r2 < 0 ? r : r2, height: h, radialSegments: sides), vm.Matrix4.translation(at), v4(hex3(rgb))));

  static final _unit = CuboidGeometry(vm.Vector3(1, 1, 1)).extractMeshData();

  // ── The clock tower ───────────────────────────────────────────────────────

  /// A Gothic clock tower: a tall square shaft of honey stone ribbed with
  /// pilasters and banded, the clock stage a little wider with a face on
  /// each side, an open belfry, a steep slate spire with a pinnacle at
  /// each corner, a gilded finial.
  Future<void> _clockTower() async {
    final o = clockAt;
    const honey = 0xC9B48A, honeyDark = 0xA8946C, slate = 0x3A4048, gilt = 0xC9A24A;
    const w = 8.0, shaft = 38.0;
    _box(_stone, w + 1.2, 3.0, w + 1.2, o + vm.Vector3(0, 1.5, 0), honeyDark);
    _box(_stone, w, shaft, w, o + vm.Vector3(0, shaft / 2, 0), honey);
    // Pilasters up every face; a band every few storeys.
    for (var k = 0; k <= 5; k++) {
      final along = -w / 2 + w * k / 5;
      for (final (dx, dz, sx, sz) in [(along, -w / 2, 0.35, 0.25), (along, w / 2, 0.35, 0.25), (-w / 2, along, 0.25, 0.35), (w / 2, along, 0.25, 0.35)]) {
        _box(_stone, sx, shaft, sz, o + vm.Vector3(dx, shaft / 2, dz), honeyDark);
      }
    }
    for (var y = 6.0; y < shaft; y += 8) {
      _box(_stone, w + 0.5, 0.45, w + 0.5, o + vm.Vector3(0, y, 0), honeyDark);
    }
    // Tall dark lancet windows in the bays, two a face, up the shaft.
    for (var y = 9.0; y < shaft - 4; y += 8) {
      for (final f in [-1.0, 1.0]) {
        for (final side in [-1.0, 1.0]) {
          _box(_stone, 0.9, 4.2, 0.1, o + vm.Vector3(f * 2.0, y + 2.4, side * (w / 2 + 0.02)), 0x2E3440);
          _box(_stone, 0.1, 4.2, 0.9, o + vm.Vector3(side * (w / 2 + 0.02), y + 2.4, f * 2.0), 0x2E3440);
        }
      }
    }
    // The clock stage, a face on each side.
    const stage = 9.0, sw = w + 1.6;
    _box(_stone, sw, stage, sw, o + vm.Vector3(0, shaft + stage / 2, 0), honey);
    _box(_stone, sw + 0.6, 0.6, sw + 0.6, o + vm.Vector3(0, shaft + stage, 0), honeyDark);
    final dial = await paintedTexture(512, 512, _paintDial);
    final face = PhysicallyBasedMaterial()
      ..baseColorTexture = dial
      ..emissiveTexture = dial
      ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
      ..emissiveStrength = 0.25
      ..metallicFactor = 0
      ..roughnessFactor = 0.5;
    final handMat = pbr(rgb(0.03, 0.03, 0.035), roughness: 0.4, metallic: 0.3);
    for (var side = 0; side < 4; side++) {
      final a = side * math.pi / 2;
      final out = vm.Vector3(math.sin(a), 0, -math.cos(a));
      final centre = o + vm.Vector3(0, shaft + stage / 2, 0) + out * (sw / 2 + 0.06);
      final at = trs(centre, rotY: -a);
      scene.add(Node(name: 'clock face', mesh: Mesh(boardGeometry(6.4, 6.4, thick: 0.08), face), localTransform: at)..castsShadows = false);
      for (final hour in [true, false]) {
        final len = hour ? 1.9 : 2.8;
        final hand = Node(name: hour ? 'clock hour hand' : 'clock minute hand', mesh: Mesh(CuboidGeometry(vm.Vector3(hour ? 0.22 : 0.14, len, 0.06)), handMat))..castsShadows = false;
        final base = at * vm.Matrix4.translation(vm.Vector3(0, 0, -0.1 - (hour ? 0.0 : 0.08)));
        final pivot = Node(name: 'clock pivot', localTransform: base)..add(hand);
        hand.localTransform = vm.Matrix4.translation(vm.Vector3(0, len / 2 - 0.3, 0));
        scene.add(pivot);
        _hands.add((pivot, hour, base));
      }
    }
    // The belfry: arches open on each side; the spire, its pinnacles, the
    // finial.
    const belfry = 5.0, top = shaft + stage + 0.6;
    _box(_stone, sw - 0.6, belfry, sw - 0.6, o + vm.Vector3(0, top + belfry / 2, 0), honey);
    for (var side = 0; side < 4; side++) {
      final a = side * math.pi / 2;
      for (final f in [-1.0, 0.0, 1.0]) {
        final along = vm.Vector3(math.cos(a), 0, math.sin(a)) * (f * 2.6), out = vm.Vector3(math.sin(a), 0, -math.cos(a)) * ((sw - 0.6) / 2 + 0.02);
        _box(_stone, 1.4, 3.4, 0.12, o + vm.Vector3(0, top + 2.4, 0) + along + out, 0x2E3440, rotY: -a);
      }
    }
    final spire = CylinderGeometry(bottomRadius: (sw - 0.6) / 2 * 1.41, topRadius: 0.15, height: 20, radialSegments: 4);
    _b.add(_stone, part(spire, trs(o + vm.Vector3(0, top + belfry + 10, 0), rotY: math.pi / 4), v4(hex3(slate))));
    for (final (dx, dz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
      final p = o + vm.Vector3(dx * (sw / 2 - 0.4), top + belfry, dz * (sw / 2 - 0.4));
      _cyl(_stone, 0.45, 5.0, p + vm.Vector3(0, 2.5, 0), honeyDark, r2: 0.05, sides: 6);
    }
    _cyl(_paint, 0.12, 4.0, o + vm.Vector3(0, top + belfry + 21.5, 0), gilt, sides: 8);
    final h = top + belfry + 23.5;
    solids.add((o + vm.Vector3(0, h / 2, 0), vm.Vector3(sw / 2 + 0.5, h / 2, sw / 2 + 0.5)));
  }

  /// The dial: opal glass, gilt rings, Roman numerals.
  static void _paintDial(Canvas c, Size s) {
    final m = s.center(Offset.zero), r = s.width / 2;
    c
      ..drawRect(Offset.zero & s, Paint()..color = const Color(0xFF3A3328))
      ..drawCircle(m, r, Paint()..color = const Color(0xFF2B2A2A))
      ..drawCircle(m, r * 0.94, Paint()..color = const Color(0xFFC9A24A))
      ..drawCircle(m, r * 0.88, Paint()..color = const Color(0xFFF2EEDF));
    const numerals = ['XII', 'I', 'II', 'III', 'IIII', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
    for (var k = 0; k < 12; k++) {
      final a = k / 12 * math.pi * 2;
      final p = m + Offset(math.sin(a), -math.cos(a)) * (r * 0.72);
      final tp = TextPainter(
        text: TextSpan(text: numerals[k], style: TextStyle(fontSize: r * 0.13, color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      c
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(a);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
      tp.dispose();
    }
    for (var k = 0; k < 60; k++) {
      final a = k / 60 * math.pi * 2, d = Offset(math.sin(a), -math.cos(a));
      c.drawLine(m + d * (r * 0.85), m + d * (r * (k % 5 == 0 ? 0.79 : 0.82)), Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = k % 5 == 0 ? 4 : 2);
    }
  }

  /// The hands at the time it is now (clockwise seen from the front: a
  /// turn about the face's inward axis).
  void update() {
    final now = DateTime.now();
    final minutes = now.minute + now.second / 60, hours = (now.hour % 12) + minutes / 60;
    for (final (pivot, hour, base) in _hands) {
      pivot.localTransform = base * vm.Matrix4.rotationZ((hour ? hours / 12 : minutes / 60) * math.pi * 2);
    }
  }

  // ── The gate ──────────────────────────────────────────────────────────────

  /// A classical gate over the avenue (Berlin's kind): two rows of six
  /// Doric columns of pale sandstone on a plinth, the wide middle way for
  /// the traffic, the narrow outer ones for people; an entablature with a
  /// frieze, a stepped attic on top; low wings either side.
  void _gate() {
    const sand = 0xD8C8A0, sandDark = 0xBFAE86;
    final x = gateX;
    // The columns' places across the avenue (z): the middle way spans
    // the road, the outer ones the pavements.
    const zs = [-25.4, -22.6, -19.8, -10.2, -7.4, -4.6];
    const height = 12.0;
    for (final dx in [-3.2, 3.2]) {
      for (final z in zs) {
        _box(_stone, 1.6, 0.6, 1.6, vm.Vector3(x + dx, 0.3, z), sandDark);
        _cyl(_stone, 0.55, height, vm.Vector3(x + dx, 0.6 + height / 2, z), sand, r2: 0.48);
        _box(_stone, 1.4, 0.4, 1.4, vm.Vector3(x + dx, 0.6 + height + 0.2, z), sandDark);
      }
    }
    // A wall from each column back to its pair in the other row: the
    // passages between.
    for (final z in zs) {
      _box(_stone, 6.4, height - 1.0, 0.6, vm.Vector3(x, 0.6 + (height - 1.0) / 2, z), sand);
    }
    const top = 0.6 + height + 0.4;
    _box(_stone, 9.0, 1.6, 23.0, vm.Vector3(x, top + 0.8, -15), sand);
    _box(_stone, 9.2, 0.5, 23.2, vm.Vector3(x, top + 1.85, -15), sandDark);
    for (var k = 0; k < 22; k++) {
      _box(_stone, 9.05, 0.7, 0.3, vm.Vector3(x, top + 0.8, -25.5 + k * 1.0), sandDark);
    }
    _box(_stone, 7.0, 2.2, 15.0, vm.Vector3(x, top + 3.2, -15), sand);
    _box(_stone, 5.2, 1.2, 7.0, vm.Vector3(x, top + 4.9, -15), sandDark);
    // The wings: a low pavilion either side.
    for (final z in [-31.5, 1.5]) {
      _box(_stone, 9.0, 8.0, 7.0, vm.Vector3(x, 4.0, z), sand);
      _box(_stone, 9.4, 0.6, 7.4, vm.Vector3(x, 8.3, z), sandDark);
    }
    solids
      ..add((vm.Vector3(x, (top + 5.5) / 2, -15), vm.Vector3(4.6, (top + 5.5) / 2, 11.6)))
      ..add((vm.Vector3(x, 4.3, -31.5), vm.Vector3(4.7, 4.3, 3.7)))
      ..add((vm.Vector3(x, 4.3, 1.5), vm.Vector3(4.7, 4.3, 3.7)));
  }

  // ── Street furniture ──────────────────────────────────────────────────────

  /// Red pillar boxes (London's): on the avenue's pavement by the café, in
  /// ICU City, by Trade-off Town's street, in Package Town.
  Future<void> _pillarBoxes() async {
    const red = 0xC8102E, black = 0x15171B;
    for (final p in [vm.Vector3(-58, 0, -9.0), vm.Vector3(-312.4, 0, 0.5), vm.Vector3(66.5, 0, -150), vm.Vector3(140, 0, -208)]) {
      _cyl(_paint, 0.32, 0.12, p + vm.Vector3(0, 0.06, 0), black);
      _cyl(_paint, 0.28, 1.3, p + vm.Vector3(0, 0.77, 0), red);
      _cyl(_paint, 0.33, 0.1, p + vm.Vector3(0, 1.45, 0), red);
      _b.add(_paint, part(SphereGeometry(radius: 0.3, segments: 14, rings: 8), trs(p + vm.Vector3(0, 1.5, 0), s: vm.Vector3(1, 0.5, 1)), v4(hex3(red))));
      _box(_paint, 0.24, 0.04, 0.05, p + vm.Vector3(0, 1.18, -0.27), black);
      _box(_paint, 0.16, 0.12, 0.02, p + vm.Vector3(0, 0.95, -0.28), 0xF2EEDF);
      solids.add((p + vm.Vector3(0, 0.8, 0), vm.Vector3(0.35, 0.8, 0.35)));
    }
  }

  /// German advertising columns (Litfaßsäulen): posters of letters from
  /// every script round a green column under a domed cap. By the gate, in
  /// ICU City, in Package Town.
  Future<void> _columns() async {
    final posters = await paintedTexture(1024, 256, _paintPosters);
    final mat = PhysicallyBasedMaterial()
      ..baseColorTexture = posters
      ..metallicFactor = 0
      ..roughnessFactor = 0.7;
    const green = 0x2F5A44;
    for (final p in [vm.Vector3(gateX - 9, 0, -23.5), vm.Vector3(-238, 0, 36), vm.Vector3(240, 0, -208)]) {
      _cyl(_paint, 0.7, 0.3, p + vm.Vector3(0, 0.15, 0), green);
      _b.add(mat, painted(CylinderGeometry(bottomRadius: 0.62, topRadius: 0.62, height: 2.4, radialSegments: 24).extractMeshData().transformed(vm.Matrix4.translation(p + vm.Vector3(0, 1.5, 0))), vm.Vector4(1, 1, 1, 1)));
      _cyl(_paint, 0.72, 0.18, p + vm.Vector3(0, 2.8, 0), green);
      _b.add(_paint, part(SphereGeometry(radius: 0.66, segments: 16, rings: 8), trs(p + vm.Vector3(0, 2.9, 0), s: vm.Vector3(1, 0.55, 1)), v4(hex3(green))));
      _cyl(_paint, 0.06, 0.5, p + vm.Vector3(0, 3.4, 0), 0xC9A24A, sides: 8);
      solids.add((p + vm.Vector3(0, 1.6, 0), vm.Vector3(0.75, 1.6, 0.75)));
    }
  }

  /// Posters round a column: a letter from a different script on each.
  static void _paintPosters(Canvas c, Size s) {
    const posters = [
      ('Aa', 0xFFC66D, 0x14203A),
      ('ß', 0x2E6DA8, 0xF4F1EA),
      ('文', 0xC8442F, 0xF4F1EA),
      ('ع', 0x2F8F5B, 0xF4F1EA),
      ('Ж', 0xF4F1EA, 0x14203A),
      ('क', 0x7A5CC0, 0xF4F1EA),
      ('Ω', 0xE8A33D, 0x14203A),
      ('한', 0x3E4E7A, 0xF4F1EA),
    ];
    final w = s.width / posters.length;
    for (final (k, (glyph, ground, ink)) in posters.indexed) {
      final r = Rect.fromLTWH(k * w, 0, w, s.height).deflate(3);
      c.drawRect(r, Paint()..color = Color(0xFF000000 | ground));
      final tp = TextPainter(
        text: TextSpan(text: glyph, style: TextStyle(fontSize: s.height * 0.5, color: Color(0xFF000000 | ink), fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
      tp.dispose();
    }
  }
}
