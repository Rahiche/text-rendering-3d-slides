import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'models.dart';

/// The city's kinds of tree (tool/blender/forest.py), one kind to a place so
/// that each reads as its own: sakura and keyaki in the park, ginkgo along
/// the side streets, clumped greens beyond the park, cloud-pruned pines in
/// ICU City, keyaki down Package Town's streets, leafy trees in Engine Town
/// and along Trade-off Town's street. Each with where its crown is: its middle's height
/// and its radius (m, at size 1), for the talk's flights and the lights.
enum TreeKind {
  clumpRound('clump_round', 4.1, 1.9),
  clumpTall('clump_tall', 4.8, 2.1),
  clumpWide('clump_wide', 3.7, 2.3),
  sakuraRound('sakura_round', 3.7, 1.8),
  sakuraWide('sakura_wide', 3.3, 2.4),
  zelkova('zelkova', 4.6, 2.4),
  zelkovaB('zelkova_b', 4.6, 2.4),
  ginkgo('ginkgo', 4.6, 2.0),
  ginkgoB('ginkgo_b', 5.0, 2.3),
  pine('pine', 3.6, 2.2),
  pineB('pine_b', 3.6, 2.2),
  leafyRound('leafy_round', 4.2, 2.2),
  leafyWide('leafy_wide', 3.7, 2.5);

  const TreeKind(this.file, this.crownY, this.crownR);
  final String file;
  final double crownY, crownR;

  /// Crowns of leaf sprites (the leaf texture, alpha-tested), not clumps.
  bool get leafy => this == leafyRound || this == leafyWide;

  /// Its crown's top (m, at size 1).
  double get top => crownY + crownR;
}

/// Trees of some kinds, planted where a place wants them and drawn a kind
/// at a time (instanced): its trunk with the bark's colours, its crown with
/// the leaves' (baked in the vertices, times a near-white shade a tree).
class Grove {
  final _trunks = <TreeKind, InstancedMesh>{}, _crowns = <TreeKind, InstancedMesh>{};

  /// Each kind's parts, loaded once for every grove.
  static final _parts = <TreeKind, Future<Map<String, MeshData>>>{};
  static PhysicallyBasedMaterial? _bark, _leaves;
  static Future<PhysicallyBasedMaterial>? _sprites;

  /// Ready to plant [kinds].
  Future<void> load(Iterable<TreeKind> kinds) async {
    _bark ??= pbr(rgb(1, 1, 1), roughness: 0.92);
    _leaves ??= pbr(rgb(1, 1, 1), roughness: 0.82);
    for (final k in kinds.toSet()) {
      final parts = await (_parts[k] ??= modelParts('assets/models/tree_${k.file}.glb'));
      final crown = k.leafy ? await (_sprites ??= _leafMaterial()) : _leaves!;
      _trunks[k] = InstancedMesh(geometry: MeshGeometry.fromMeshData(parts['trunk']!), material: _bark!);
      _crowns[k] = InstancedMesh(geometry: MeshGeometry.fromMeshData(parts['crown']!), material: crown);
    }
  }

  /// A tree of [kind] standing at [at]'s origin, its colours times [shade].
  void plant(TreeKind kind, vm.Matrix4 at, {double shade = 1}) {
    _trunks[kind]!.addInstance(at);
    _crowns[kind]!.addInstance(at, color: vm.Vector4(shade, shade, shade, 1));
  }

  /// Its nodes, to [add] (a scene's, a node's).
  void addTo(void Function(Node n) add, String name) {
    for (final k in _trunks.keys) {
      for (final (part, m) in [('trunks', _trunks[k]!), ('crowns', _crowns[k]!)]) {
        if (m.instanceCount == 0) continue;
        add(
          Node(name: '$name ${k.file} $part')
            ..lightChannelMask = 0x01
            ..addComponent(InstancedMeshComponent(m)),
        );
      }
    }
  }

  /// The leaf sprites' material: a cluster of leaves painted on a clear
  /// ground, near white (the crown's colours give the green), alpha-tested,
  /// seen from both sides.
  static Future<PhysicallyBasedMaterial> _leafMaterial() async {
    final tex = await paintedTexture(256, 256, (c, s) {
      final rnd = math.Random(7);
      final o = Offset(s.width / 2, s.height / 2);
      for (var i = 0; i < 30; i++) {
        final a = rnd.nextDouble() * math.pi * 2, d = rnd.nextDouble() * s.width * 0.3;
        final at = o + Offset(math.cos(a) * d, math.sin(a) * d);
        final len = s.width * (0.16 + 0.1 * rnd.nextDouble()), w = len * 0.42;
        final v = 0.8 + 0.2 * rnd.nextDouble();
        final leaf = Path()
          ..moveTo(-len / 2, 0)
          ..quadraticBezierTo(0, -w, len / 2, 0)
          ..quadraticBezierTo(0, w, -len / 2, 0);
        c
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(rnd.nextDouble() * math.pi * 2)
          ..drawPath(leaf, Paint()..color = Color.fromARGB(255, (232 * v).round(), (242 * v).round(), (222 * v).round()))
          ..drawLine(Offset(-len / 2, 0), Offset(len / 2, 0), Paint()
            ..color = Color.fromARGB(255, (200 * v).round(), (214 * v).round(), (190 * v).round())
            ..strokeWidth = 1.4)
          ..restore();
      }
    });
    return PhysicallyBasedMaterial()
      ..baseColorTexture = tex
      ..alphaMode = AlphaMode.mask
      ..alphaCutoff = 0.4
      ..doubleSided = true
      ..metallicFactor = 0
      ..roughnessFactor = 0.75;
  }
}
