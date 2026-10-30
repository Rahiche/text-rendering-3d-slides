import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'dash_colours.dart';
import 'kit.dart';
import 'models.dart';

/// Dash hovering as a hummingbird does (its wings a blur of beats, its feet
/// tucked up), a thread's end in its beak: Package Town's text on a path
/// screen (v_package.dart), Dash pulling the strip the word stands on. The
/// city's Dashes' parts (tool/blender/dash.py: dashes.dart walks them), as
/// a few plain nodes under one. A [rival]'s a ninja's red headband on
/// (dash.py's), its tails flying. Given [colours], it's in those instead of
/// Dash's blues (the rooftop's fighters, each its effect's).
class HoverDash {
  HoverDash(this.parent, {this.rival = false, this.colours});

  final Node parent;
  final bool rival;
  final DashColours? colours;
  late final _root = Node(name: rival ? 'hover dash rival' : 'hover dash');
  late final Node _body, _wingR, _wingL, _footR, _footL;
  late final PhysicallyBasedMaterial _skin;
  Node? _band;
  bool _ready = false;

  /// dash.glb's parts (read once for all of them).
  static Future<Map<String, MeshData>>? _parts;

  /// Its beak's tip in its own frame (size 1: dash.py's BEAK_B, less the
  /// beak's round end).
  static final beakTip = vm.Vector3(0, 0.367, -0.385);

  Future<void> build() async {
    final parts = await (_parts ??= modelParts('assets/models/dash.glb'));
    final c = colours;
    _skin = pbr(rgb(1, 1, 1), roughness: c?.roughness ?? 0.4, emissive: c?.glow == null ? null : v4(lin3(c!.glow!)), emissiveStrength: c?.glowStrength ?? 0);
    Node part(String name, MeshData data) => Node(name: 'hover dash $name', mesh: Mesh(MeshGeometry.fromMeshData(data), _skin))..castsShadows = false;
    // (Its blues into [colours]; its eyes and beak as they are.)
    MeshData skin(String n) => c == null ? parts[n]! : _recoloured(parts[n]!, c);
    _body = part('body', MeshData.merge([skin('dash_body'), for (final n in ['dash_eyes', 'dash_pupils', 'dash_glints']) parts[n]!]));
    _wingR = part('wing r', skin('dash_wing_r'));
    _wingL = part('wing l', skin('dash_wing_l'));
    _footR = part('foot r', skin('dash_foot'));
    _footL = part('foot l', skin('dash_foot'));
    if (rival) _band = part('band', parts['acc_ninja_band']!);
    for (final n in [_body, _wingR, _wingL, _footR, _footL, ?_band]) {
      _root.add(n);
    }
    _root.visible = false;
    parent.add(_root);
    _ready = true;
  }

  set visible(bool v) {
    if (_ready) _root.visible = v;
  }

  /// How strongly it glows (0..: times its [colours]' own glow).
  set glow(double k) {
    final c = colours;
    if (_ready && c != null) _skin.emissiveStrength = c.glowStrength * k;
  }

  /// [d] with its blues (dash.py's: the body's, the belly's pale blue, the
  /// tuft's, tail's and feet's dark) into [c]'s body, belly and dark, by
  /// how light each vertex is; what's darker still (the beak) kept.
  static MeshData _recoloured(MeshData d, DashColours c) {
    final from = d.colors!, out = Float32List.fromList(from), k = from.length ~/ d.vertexCount;
    final body = lin3(c.body), belly = lin3(c.belly), dark = lin3(c.dark);
    for (var i = 0; i < d.vertexCount; i++) {
      final r = from[i * k], g = from[i * k + 1], b = from[i * k + 2];
      final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (l < 0.03) continue;
      final m = l < 0.18 ? _mix(dark, body, (l - 0.1) / 0.08) : _mix(body, belly, (l - 0.18) / 0.62);
      out[i * k] = m.x;
      out[i * k + 1] = m.y;
      out[i * k + 2] = m.z;
    }
    return MeshData(
      positions: d.positions,
      vertexCount: d.vertexCount,
      normals: d.normals,
      texCoords: d.texCoords,
      texCoords1: d.texCoords1,
      colors: out,
      tangents: d.tangents,
      indices: d.indices,
    );
  }

  static vm.Vector3 _mix(vm.Vector3 a, vm.Vector3 b, double t) {
    final s = t.clamp(0.0, 1.0);
    return a + (b - a) * s;
  }

  /// Posed in [frame] (its own frame in the world: where it is, which way
  /// it faces, how big); [t] the clock (its wings' beat); [effort] how hard
  /// it's pulling (0..1: its wings beat wider).
  void pose(vm.Matrix4 frame, double t, double effort) {
    if (!_ready) return;
    _body.localTransform = frame;
    _band?.localTransform = frame;
    // Its wings: out from the shoulders, beating up and down, swept to and
    // fro with each beat.
    final beat = 2 * math.pi * 9 * t;
    final spread = 1.62 + (0.55 + 0.25 * effort) * math.sin(beat), sweep = 0.4 * math.cos(beat);
    vm.Matrix4 wing(double side) => frame.clone()
      ..translateByDouble(side * 0.215, 0.385, 0.02, 1)
      ..rotateZ(side * spread)
      ..rotateX(sweep);
    _wingR.localTransform = wing(1);
    _wingL.localTransform = wing(-1);
    // Its feet tucked up under it, back.
    vm.Matrix4 foot(double side) => frame.clone()
      ..translateByDouble(side * 0.07, 0.2, 0.05, 1)
      ..rotateX(-0.9);
    _footR.localTransform = foot(1);
    _footL.localTransform = foot(-1);
  }
}
