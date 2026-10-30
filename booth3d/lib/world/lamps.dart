import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'models.dart';

/// The city's kinds of street lamp (tool/blender/lamps.py), one kind to a
/// place: Tokyo street lights along the streets, their arms out over the
/// road (local −z) and a banner over the pavement; cast-iron lanterns in
/// the park and round the plaza; suzuran lamps in ICU City. Each with
/// where its light is (local) and how wide its foot is (for the crowd).
enum LampKind {
  tokyo('tokyo', 6.14, -1.64, 0.17),
  suzuran('suzuran', 4.0, 0, 0.16),
  lantern('lantern', 3.92, 0, 0.26);

  const LampKind(this.file, this.lightY, this.lightZ, this.foot);
  final String file;
  final double lightY, lightZ, foot;

  /// Where its light is, in its own frame.
  vm.Vector3 get light => vm.Vector3(0, lightY, lightZ);
}

/// Street lamps of some kinds, placed where a place wants them and drawn
/// a kind and a part at a time (instanced): painted metal, the banner's
/// cloth, and what lights up at night ([glow], one material for every
/// lamp in the world: the city sets how bright it is).
class Lamps {
  final _meshes = <(LampKind, String), InstancedMesh>{};

  static final _parts = <LampKind, Future<Map<String, MeshData>>>{};
  static final _body = pbr(rgb(1, 1, 1), metallic: 0.55, roughness: 0.42);
  static final _banner = pbr(rgb(1, 1, 1), roughness: 0.85);

  /// What lights at night: the LED lenses, the bells, the lanterns' glass.
  static final glow = pbr(rgb(1, 1, 1), roughness: 0.3, emissive: lin(const Color(0xFFFFD9A0)), emissiveStrength: 0);

  /// Ready to place [kinds].
  Future<void> load(Iterable<LampKind> kinds) async {
    for (final k in kinds.toSet()) {
      final parts = await (_parts[k] ??= modelParts('assets/models/lamp_${k.file}.glb'));
      for (final MapEntry(key: part, value: data) in parts.entries) {
        final mat = switch (part) {
          'glow' => glow,
          'banner' => _banner,
          _ => _body,
        };
        _meshes[(k, part)] = InstancedMesh(geometry: MeshGeometry.fromMeshData(data), material: mat);
      }
    }
  }

  /// A lamp of [kind] standing at [at]'s origin.
  void place(LampKind kind, vm.Matrix4 at) {
    for (final MapEntry(key: (k, _), value: m) in _meshes.entries) {
      if (k == kind) m.addInstance(at);
    }
  }

  /// Its nodes, to [add] (a scene's, a node's).
  void addTo(void Function(Node n) add, String name, {int lightChannelMask = 0x01}) {
    for (final MapEntry(key: (k, part), value: m) in _meshes.entries) {
      if (m.instanceCount == 0) continue;
      add(
        Node(name: '$name ${k.file} $part')
          ..lightChannelMask = lightChannelMask
          ..addComponent(InstancedMeshComponent(m)),
      );
    }
  }
}
