import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'figure.dart' show rgbHex;
import 'kit.dart';
import 'models.dart';

/// What a Dash is up to: on holiday (a sun hat, sunglasses, pulling a
/// suitcase), sightseeing (sunglasses, a camera round its neck), on the way
/// to work (a tie, a briefcase, a coffee), or to the office with a laptop
/// backpack (and a coffee); or a ninja (a hood, a headband, a katana on
/// its back), keeping out of sight on the roofs.
enum DashKind {
  holiday,
  sightseer,
  commuter,
  backpacker,
  ninja;

  /// The kinds out walking with everyone else.
  static const walking = [holiday, sightseer, commuter, backpacker];
}

/// Dash, Flutter's mascot, among the city's people (an easter egg): round
/// blue hummingbirds waddling the sidewalks with everyone else. Sculpted in
/// Blender (tool/blender/dash.py, its parts' frames there); each part one
/// instanced mesh for all of them, posed here a frame at a time: [begin],
/// a [place] for each Dash in sight, [end].
class Dashes {
  Dashes(this.scene);

  final Scene scene;

  /// How many there can be (what each kind carries is made for as many
  /// of that kind as that allows: the kinds take turns).
  static const max = 12;
  static const _perKind = (max + 3) ~/ 4;

  late final InstancedMesh _body, _wingR, _wingL, _feet, _glasses, _hat, _camera, _tie, _backpack, _suitcase, _briefcase, _cup, _hood, _band, _katana;

  /// How many ninjas there can be.
  static const _ninjas = 6;
  final _cap = <InstancedMesh, int>{};
  final _used = <InstancedMesh, int>{};
  bool _ready = false;

  /// The suitcases' and the backpacks' colours (sRGB).
  static const _cases = [0x2BB3A3, 0xF2735A, 0xF2C94C, 0xA88FC9, 0x4F8FE6];
  static const _packs = [0x2B3A55, 0x5B6A48, 0x3A3F48, 0x7A2E3A];

  Future<void> build() async {
    final parts = await modelParts('assets/models/dash.glb');
    final white = pbr(rgb(1, 1, 1), roughness: 0.42);
    InstancedMesh mesh(List<String> names, {int count = max, double roughness = 0.42}) {
      final m = InstancedMesh(
        geometry: MeshGeometry.fromMeshData(names.length == 1 ? parts[names.first]! : MeshData.merge([for (final n in names) parts[n]!])),
        material: roughness == 0.42 ? white : pbr(rgb(1, 1, 1), roughness: roughness),
      );
      for (var i = 0; i < count; i++) {
        m.addInstance(_hidden, color: rgb(1, 1, 1));
      }
      _cap[m] = count;
      scene.add(Node(name: 'dash ${names.first}')..addComponent(InstancedMeshComponent(m)));
      return m;
    }

    _body = mesh(['dash_body', 'dash_eyes', 'dash_pupils', 'dash_glints'], roughness: 0.38);
    _wingR = mesh(['dash_wing_r']);
    _wingL = mesh(['dash_wing_l']);
    _feet = mesh(['dash_foot'], count: 2 * max);
    _glasses = mesh(['acc_glasses'], count: 2 * _perKind, roughness: 0.2);
    _hat = mesh(['acc_hat'], count: _perKind, roughness: 0.8);
    _camera = mesh(['acc_camera'], count: _perKind, roughness: 0.3);
    _tie = mesh(['acc_tie'], count: _perKind, roughness: 0.6);
    _backpack = mesh(['acc_backpack'], count: _perKind, roughness: 0.7);
    _suitcase = mesh(['acc_suitcase'], count: _perKind, roughness: 0.35);
    _briefcase = mesh(['acc_briefcase'], count: _perKind, roughness: 0.5);
    _cup = mesh(['acc_cup'], count: 2 * _perKind, roughness: 0.5);
    _hood = mesh(['acc_ninja_hood'], count: _ninjas, roughness: 0.6);
    _band = mesh(['acc_ninja_band'], count: _ninjas, roughness: 0.7);
    _katana = mesh(['acc_katana'], count: _ninjas, roughness: 0.35);
    _ready = true;
  }

  static final _hidden = vm.Matrix4.diagonal3Values(0, 0, 0);

  void begin() => _used.clear();

  void end() {
    if (!_ready) return;
    for (final MapEntry(key: m, value: n) in _cap.entries) {
      for (var i = _used[m] ?? 0; i < n; i++) {
        m.setInstanceTransform(i, _hidden);
      }
    }
  }

  void _put(InstancedMesh m, vm.Matrix4 xf, [vm.Vector4? color]) {
    final i = _used[m] ?? 0;
    if (i >= _cap[m]!) return;
    _used[m] = i + 1;
    m.setInstanceTransform(i, xf);
    if (color != null) m.setInstanceColor(i, color);
  }

  final _root = vm.Matrix4.identity(), _base = vm.Matrix4.identity(), _m = vm.Matrix4.identity(), _w = vm.Matrix4.identity();
  final _v = vm.Vector3.zero();

  /// Dash number [no] ([kind]) at (x, z) facing [yaw] (0 towards −z),
  /// [size]; [step] its walk's phase (π a step), [walking] 0 standing … 1
  /// on its way; [hop] how far up a happy bounce has it (0..1) and [flap]
  /// its wings' flutter (radians); [t] for its breathing; [y] what it
  /// stands on (a roof).
  void place(int no, DashKind kind, double x, double z, double yaw, double size, {required double step, required double walking, required double t, double hop = 0, double flap = 0, double y = 0}) {
    if (!_ready) return;
    final s = math.sin(step);
    final bob = walking * 0.022 * s.abs() + 0.005 * math.sin(t * 2.1 + no) + 0.14 * hop;
    final roll = walking * 0.085 * s;
    final lean = walking * 0.07;
    // Where it stands (no waddle: its feet stay down), and its body.
    _base
      ..setIdentity()
      ..translateByDouble(x, y, z, 1)
      ..rotateY(yaw);
    _root
      ..setFrom(_base)
      ..translateByDouble(0, bob, 0, 1)
      ..rotateX(-lean)
      ..rotateZ(roll)
      ..scaleByDouble(size, size, size, 1);
    _put(_body, _root);
    // Its feet: each up and forward in turn as it goes (the hips under
    // its middle).
    for (var k = 0; k < 2; k++) {
      final ph = step + k * math.pi, lift = walking * 0.035 * math.max(0.0, math.sin(ph)) + 0.14 * hop;
      _m
        ..setFrom(_base)
        ..scaleByDouble(size, size, size, 1)
        ..translateByDouble(k == 0 ? -0.07 : 0.07, 0.11 + lift, -walking * 0.045 * math.cos(ph), 1);
      _put(_feet, _m);
    }
    // Its wings: from the shoulders, swinging as it goes; what it holds
    // held out.
    final swing = walking * 0.28 * s;
    double wingR, wingL;
    switch (kind) {
      case DashKind.holiday:
        wingR = -1.3; // back, to the suitcase's handle
        wingL = -swing;
      case DashKind.commuter || DashKind.backpacker:
        wingR = 0.95; // forward, the coffee
        wingL = kind == DashKind.commuter ? 0.08 * s : -swing;
      case DashKind.sightseer:
        wingR = swing;
        wingL = -swing;
      case DashKind.ninja:
        // Back, out of the way: further back the faster it goes.
        wingR = -0.35 - 0.6 * walking;
        wingL = -0.35 - 0.6 * walking;
    }
    vm.Matrix4 wing(vm.Matrix4 out, double side, double pitch) => out
      ..setFrom(_root)
      ..translateByDouble(side * 0.215, 0.385, 0.02, 1)
      ..rotateZ(side * (0.14 + flap))
      ..rotateX(pitch);
    _put(_wingR, wing(_w, 1, wingR));
    _put(_wingL, wing(_m, -1, wingL));
    // What it wears.
    switch (kind) {
      case DashKind.holiday:
        _put(_hat, _root);
        _put(_glasses, _root);
      case DashKind.sightseer:
        _put(_glasses, _root);
        _put(_camera, _root);
      case DashKind.commuter:
        _put(_tie, _root);
      case DashKind.backpacker:
        _put(_backpack, _root, _tint(_packs, no));
      case DashKind.ninja:
        _put(_hood, _root);
        _put(_band, _root);
        _put(_katana, _root);
    }
    // What it carries.
    switch (kind) {
      case DashKind.holiday:
        // Pulled along behind, leaning on its wheels.
        _m
          ..setFrom(_base)
          ..scaleByDouble(size, size, size, 1)
          ..translateByDouble(0.27, 0.0, 0.72, 1)
          ..rotateX(-0.95 + 0.04 * walking * math.sin(2 * step));
        _put(_suitcase, _m, _tint(_cases, no));
      case DashKind.commuter || DashKind.backpacker:
        // The coffee at the right wing's tip, upright.
        _cup2(_w, size, yaw);
        if (kind == DashKind.commuter) {
          // The briefcase hanging from the left's, swinging a little.
          _tip(_m, 0.0, -0.205, 0.035);
          _m
            ..setIdentity()
            ..translateByDouble(_v.x, _v.y, _v.z, 1)
            ..rotateY(yaw)
            ..rotateX(0.12 * walking * math.sin(step))
            ..scaleByDouble(size, size, size, 1);
          _put(_briefcase, _m);
        }
      case DashKind.sightseer || DashKind.ninja:
        break;
    }
  }

  /// The tip of the wing whose matrix is [wing] (its frame's point), into
  /// [_v].
  void _tip(vm.Matrix4 wing, double x, double y, double z) {
    _v.setValues(x, y, z);
    wing.transform3(_v);
  }

  final _c = vm.Matrix4.identity();

  void _cup2(vm.Matrix4 wing, double size, double yaw) {
    _tip(wing, 0.03, -0.2, 0.04);
    _c
      ..setIdentity()
      ..translateByDouble(_v.x, _v.y + 0.02 * size, _v.z, 1)
      ..rotateY(yaw)
      ..scaleByDouble(size, size, size, 1);
    _put(_cup, _c);
  }

  static vm.Vector4 _tint(List<int> from, int no) {
    final c = from[no % from.length];
    return rgbHex(c);
  }
}
