import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'dashes.dart';
import 'kit.dart';
import 'mascots.dart';
import 'shapes.dart' show geometryOf;
import 'shot.dart';
import 'vignette.dart';

/// The trade-off, a playground beyond the park (north of the pixel farm):
/// the engines' mascots on a long seesaw (mascots.dart), each where the
/// talk's card puts its engine between owning the stack and using the
/// platform's — Figma's cursor and Flutter's Dash at one end, Android's
/// robot in the middle, Chrome's dinosaur and a Happy Mac for macOS at the
/// other — rocking it up and down until it settles nearly level, a little
/// down on Flutter's side. A slide, swings, a bench and a fence round it.
class SeesawPlayground extends Vignette {
  SeesawPlayground(super.kit);

  @override
  String get name => 'seesaw';
  @override
  String get kick => 'THE TRADE-OFF';
  @override
  String get line => 'Owning the stack, or using the platform';
  @override
  String get note => 'a seesaw: Figma and Flutter at one end, Chrome and macOS at the other, each its mascot';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 16;
  @override
  double get visit => 12;

  @override
  final frame = trs(vm.Vector3(-6, 0, 95));

  /// Who rides it: name, where along it (the card's scale, −1 owning the
  /// stack … 1 using the platform), its mascot (null: Dash, Flutter's) and
  /// which way it faces (a yaw: 0 the camera; Dash faces along the plank),
  /// the accent's.
  static final _riders = <(String, double, MeshData Function()?, double, bool)>[
    ('Figma', -0.9, Mascots.cursor, -0.25, false),
    ('Flutter', -0.72, null, 0, true),
    ('Android', 0.04, Mascots.android, 0, false),
    ('Chrome', 0.62, Mascots.dino, 0, false),
    ('macOS', 0.88, Mascots.mac, 0.35, false),
  ];

  /// The plank's half length (where a rider at ±1 would sit), its axle's
  /// height, and how it settles: nearly level, its owning end down a
  /// little (the riders' weights almost balance).
  static const _reach = 3.2, _axle = 0.95, _settled = 0.045;

  /// The signs at its ends (x, what they say).
  static const _ends = [(-4.35, 'OWNS THE\nSTACK'), (4.0, 'USES THE\nPLATFORM')];

  late final Dashes _dashes = Dashes(scene);
  late final Node _plank;
  final _tags = <Node>[];

  /// Each rider's mascot (none for Dash).
  final _mascots = <Node?>[];
  bool _ready = false;

  @override
  Future<void> init() async {
    await _dashes.build();
    final b = Batch(), m = pbr(rgb(1, 1, 1), roughness: 0.7), metal = pbr(rgb(1, 1, 1), roughness: 0.35, metallic: 0.6);
    // The ground: a soft red mat under the seesaw, blue round it; a low
    // fence with a gap at the front.
    box(b, m, 12, 0.04, 8.5, 0, 0.02, 0.25, Vignette.c(0x3E7FB8));
    box(b, m, 8.4, 0.045, 2.6, 0, 0.025, 0, Vignette.c(0xC85A44));
    for (final (x0, z0, x1, z1) in const [(-6.0, 4.5, 6.0, 4.5), (-6.0, -4.0, -6.0, 4.5), (6.0, -4.0, 6.0, 4.5), (-6.0, -4.0, -1.2, -4.0), (1.2, -4.0, 6.0, -4.0)]) {
      final len = math.max((x1 - x0).abs(), (z1 - z0).abs()), along = (x1 - x0).abs() > 0.1;
      final n = (len / 1.5).ceil();
      for (var k = 0; k <= n; k++) {
        box(b, m, 0.08, 0.9, 0.08, x0 + (x1 - x0) * k / n, 0.45, z0 + (z1 - z0) * k / n, Vignette.c(0x2F6B4A));
      }
      for (final y in [0.4, 0.82]) {
        box(b, m, along ? len : 0.05, 0.05, along ? 0.05 : len, (x0 + x1) / 2, y, (z0 + z1) / 2, Vignette.c(0x3C8A5E));
      }
    }
    // The seesaw's stand: an A-frame either side of the plank, the axle.
    for (final z in [-0.36, 0.36]) {
      for (final s in [-1.0, 1.0]) {
        b.add(metal, part(CuboidGeometry(vm.Vector3(0.08, 1.05, 0.08)), place(trs(vm.Vector3(s * 0.22, 0.48, z), rotZ: s * 0.45)), Vignette.c(0x2F3A4A)));
      }
    }
    b.add(metal, part(CylinderGeometry(bottomRadius: 0.06, topRadius: 0.06, height: 0.9, radialSegments: 12), place(trs(vm.Vector3(0, _axle, 0), rotX: math.pi / 2)), Vignette.c(0x9AA3AD)));
    // Swings at the back on the left; a slide at the back on the right; a
    // bench by the gap.
    for (final s in [-1.0, 1.0]) {
      for (final dz in [-0.6, 0.6]) {
        b.add(metal, part(CuboidGeometry(vm.Vector3(0.08, 2.6, 0.08)), place(trs(vm.Vector3(-4.0 + s * 1.3, 1.25, 2.9 + dz), rotX: -dz * 0.38)), Vignette.c(0xE0B53C)));
      }
    }
    b.add(metal, part(CylinderGeometry(bottomRadius: 0.05, topRadius: 0.05, height: 2.8, radialSegments: 10), place(trs(vm.Vector3(-4.0, 2.45, 2.9), rotZ: math.pi / 2)), Vignette.c(0xE0B53C)));
    for (final x in [-4.55, -3.45]) {
      for (final dx in [-0.18, 0.18]) {
        box(b, m, 0.02, 1.85, 0.02, x + dx, 1.5, 2.9, Vignette.c(0x6E6A62));
      }
      box(b, m, 0.5, 0.05, 0.22, x, 0.56, 2.9, Vignette.c(0x2F3A4A));
    }
    for (final dx in [-0.5, 0.5]) {
      for (final dz in [-0.5, 0.5]) {
        box(b, m, 0.1, 1.5, 0.1, 3.6 + dx, 0.75, 2.8 + dz, Vignette.c(0xC85A44));
      }
    }
    box(b, m, 1.2, 0.1, 1.2, 3.6, 1.5, 2.8, Vignette.c(0xC85A44));
    box(b, m, 1.3, 0.05, 1.2, 3.6, 2.4, 2.8, Vignette.c(0x3E7FB8));
    box(b, m, 0.75, 0.05, 2.9, 3.6, 0.8, 1.05, Vignette.c(0xF2C94C), rotX: 0.52);
    for (final s in [-1.0, 1.0]) {
      box(b, m, 0.06, 0.18, 2.9, 3.6 + s * 0.38, 0.88, 1.05, Vignette.c(0xF2C94C), rotX: 0.52);
      box(b, m, 0.06, 1.6, 0.06, 3.6 + s * 0.3, 0.75, 3.75, Vignette.c(0x2F3A4A));
    }
    for (var k = 0; k < 4; k++) {
      box(b, m, 0.6, 0.05, 0.05, 3.6, 0.3 + 0.36 * k, 3.75, Vignette.c(0x2F3A4A));
    }
    box(b, m, 1.6, 0.06, 0.42, 3.2, 0.45, -3.4, Vignette.c(0xA9784A));
    box(b, m, 1.6, 0.4, 0.05, 3.2, 0.72, -3.2, Vignette.c(0xA9784A));
    for (final dx in [-0.65, 0.65]) {
      box(b, m, 0.06, 0.45, 0.4, 3.2 + dx, 0.22, -3.4, Vignette.c(0x2F3A4A));
    }
    b.buildInto(shell, 'seesaw playground', castsShadows: true, lightChannelMask: 0x01);

    // The plank (its own node: it rocks round the axle), a seat and a
    // handle in front of each rider.
    final parts = <MeshData>[part(CuboidGeometry(vm.Vector3(2 * _reach + 0.8, 0.08, 0.42)), trs(vm.Vector3(0, 0.04, 0)), Vignette.c(0xF2C94C))];
    for (final (_, at, _, _, accent) in _riders) {
      final x = at * _reach, toward = x < 0 ? 1.0 : -1.0;
      parts
        ..add(part(CuboidGeometry(vm.Vector3(0.42, 0.04, 0.44)), trs(vm.Vector3(x, 0.1, 0)), Vignette.c(accent ? 0xFFC66D : 0x2F6BBF)))
        ..add(part(CuboidGeometry(vm.Vector3(0.05, 0.42, 0.05)), trs(vm.Vector3(x + toward * 0.38, 0.29, 0)), Vignette.c(0x2F3A4A)))
        ..add(part(CuboidGeometry(vm.Vector3(0.05, 0.05, 0.36)), trs(vm.Vector3(x + toward * 0.38, 0.5, 0)), Vignette.c(0x2F3A4A)));
    }
    _plank = Node(name: 'seesaw plank', mesh: Mesh(merged(parts), m));
    detail.add(_plank);
    final skin = pbr(rgb(1, 1, 1), roughness: 0.45);
    for (final (name, _, mascot, _, _) in _riders) {
      final n = mascot == null ? null : (Node(name: 'seesaw ${name.toLowerCase()}', mesh: Mesh(geometryOf(mascot()), skin))..visible = false);
      if (n != null) detail.add(n);
      _mascots.add(n);
    }
    // The ends' signs, on the ground (the left one a little further out:
    // seen from the left of the playground, it would hide Figma's name).
    for (final (x, label) in _ends) {
      await sign(1.55, 0.8, trs(vm.Vector3(x, 1.6, -0.6)), (c, s) {
        c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height * 0.1)), Paint()..color = const Color(0xFF14203A));
        Vignette.text(c, label, Rect.fromLTWH(0, 0, s.width, s.height), s.height * 0.32, BP.ink, weight: FontWeight.w700);
      }, glow: 0.3);
    }
    final posts = Batch();
    for (final (x, _) in _ends) {
      for (final dx in [-0.6, 0.6]) {
        box(posts, m, 0.07, 1.3, 0.07, x + dx, 0.65, -0.6, Vignette.c(0x2F3A4A));
      }
    }
    posts.buildInto(shell, 'seesaw sign posts', lightChannelMask: 0x01);
    // Each rider's name over them, on the plank (moving with it); every
    // other one higher, clear of its neighbour's.
    for (final (name, _, _, _, accent) in _riders) {
      _tags.add(
        await sign(0.95, 0.3, vm.Matrix4.identity(), (c, s) {
          c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height * 0.25)), Paint()..color = accent ? BP.amber : const Color(0xFFF4F6F8));
          Vignette.text(c, name, Rect.fromLTWH(0, 0, s.width, s.height), s.height * 0.62, const Color(0xFF14203A), weight: FontWeight.w700);
        }, px: 360, glow: 0.35, thick: 0.02),
      );
    }
    _ready = true;
  }

  /// The plank's tilt [u] seconds in (positive: its owning end down):
  /// rocked hard at first, then settling.
  static double _tilt(double u) => _settled + 0.22 * math.exp(-u / 2.8) * math.cos(2 * math.pi * u / 2.2) + 0.008 * math.sin(u * 0.9);

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    final a = _tilt(u), rate = (_tilt(u + 0.02) - a) / 0.02;
    final pivot = place(trs(vm.Vector3(0, _axle, 0), rotZ: a));
    _plank.localTransform = pivot;
    _dashes.begin();
    for (final (i, (_, at, _, facing, _)) in _riders.indexed) {
      final x = at * _reach;
      final seat = pivot.transformed3(vm.Vector3(x, 0.12, 0));
      // Up off the seat a little as its end comes up fast (Dash's wings
      // out).
      final rising = (x < 0 ? -rate : rate) * x.abs() / _reach;
      final hop = (0.6 * rising).clamp(0.0, 0.45), flap = (0.5 * rising).clamp(0.0, 0.6);
      final mascot = _mascots[i];
      if (mascot == null) {
        final yaw = (x.abs() < 0.5 ? 0.0 : (x < 0 ? -math.pi / 2 : math.pi / 2)) + kit.yawOf(frame);
        _dashes.place(30 + i, DashKind.sightseer, seat.x, seat.z, yaw, 0.95, step: 0, walking: 0, t: t, hop: hop, flap: flap, y: seat.y);
      } else {
        mascot
          ..visible = true
          ..localTransform = trs(seat..y += 0.4 * hop, rotY: facing + kit.yawOf(frame));
      }
      _tags[i].localTransform = pivot * trs(vm.Vector3(x, i.isOdd ? 1.55 : 1.12, 0.05));
    }
    _dashes.end();
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    final k = smooth(0, 10, u);
    // (Head on, wide enough for both ends' signs beside the talk's card;
    // from over the pixel farm's back fence, just behind the eye.)
    return Shot(vm.Vector3(0.2, lerp(2.85, 2.75, k), lerp(-10.9, -10.3, k)), vm.Vector3(0.2, 1.35, 0.4), fov: 56, settle: 1.0, drift: 0.5);
  }
}
