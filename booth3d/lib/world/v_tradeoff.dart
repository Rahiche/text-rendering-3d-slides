import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'city_plan.dart';
import 'grove.dart';
import 'kit.dart';
import 'lamps.dart';
import 'shops.dart';
import 'shot.dart';
import 'trim.dart';
import 'v_package.dart' show PackageTown;
import 'vignette.dart';

/// Trade-off Town, where talk 05 is told: south of Flutter City, a street
/// down its middle (on from the avenue, out into the country) between two
/// sides. The west side is what Flutter doesn't have: Chrome's page set by
/// Flutter (v_engines.dart), the ruby cable car (v_ruby.dart), the
/// hyphenation sawmill (v_hyphen.dart), the web's table (v_phones.dart's
/// last turn). The east side is what it has: the same-everywhere table
/// (v_phones.dart's second turn), the weight gym (v_gym.dart), every glyph
/// a box ("Flutter" in 3D, v_word.dart). They all face the street, so the
/// camera goes up one side over the street, across it, and down the other.
/// Those scenes place themselves here ([at]); this is the town round them:
/// the sides, the street (its crossings, its lamps on the way in), the
/// sides' signs, trees, the tables' canopies, the page's billboard, a
/// terrace of shops behind each side (the town's a town, the scenes stand
/// in a street, not out in a field), and the camera's view over it all
/// from the south.
class TradeoffTown extends Vignette {
  TradeoffTown(super.kit);

  @override
  String get name => 'tradeoff';
  @override
  String get kick => "FLUTTER'S TRADE-OFF";
  @override
  String get line => 'What Flutter has, and what it doesn’t';
  @override
  String get note => 'a street between the two';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 30;
  @override
  double get visit => 12;

  /// The town's middle (world), the frame's origin, unturned (x east, z
  /// north).
  static final o = vm.Vector3(75, 0, -190);
  @override
  final frame = vm.Matrix4.translation(o);

  /// The street's half width; the sides' width and height (a kerb's); where
  /// the town starts and ends along it (z); the road's height; the
  /// crossing at the north end (z).
  static const _canal = 5.0, _bankW = 20.0, bank = 0.15, _z0 = -48.0, _z1 = 28.0, _road = -0.06, _bridgeZ = 23.0;

  /// A scene's frame on a side: its front's middle at (x, z) of the town on
  /// the pavement, facing the street ([west]: a west-side scene, facing
  /// east), scaled [s].
  static vm.Matrix4 at(double x, double z, {required bool west, double s = 1}) =>
      trs(o + vm.Vector3(x, bank, z), rotY: west ? -math.pi / 2 : math.pi / 2, s: vm.Vector3.all(s));

  /// The scenes' places: west, from the south, what Flutter doesn't have;
  /// east, from the north, what it has.
  static final engines = at(-7.5, -34, west: true), ruby = at(-7.5, -18, west: true), hyphen = at(-7.5, -2, west: true);
  static final web = at(-8.6, 14, west: true), same = at(8.6, 14, west: false);
  static final gym = at(7.5, -2, west: false), word = at(7.5, -20, west: false, s: 0.6);

  /// Where a side's place is in the world (x, z of the town, at [y] over the
  /// pavement): for the talk's pins.
  static vm.Vector3 pin(double x, double z, double y) => o + vm.Vector3(x, bank + y, z);

  /// The terraces behind the sides, facing the street over the sides'
  /// trees: an English high street's houses (the town's in England's part
  /// of the country, outskirts.dart), from the south: each one's side (−1
  /// west, 1 east), its middle along the street, its width and height.
  static final _houses = () {
    final out = <(double, double, double, double)>[];
    var seed = 300;
    for (final s in [-1.0, 1.0]) {
      var z = _z0 - 2.0;
      while (true) {
        seed++;
        final w = 7.0 + 3.0 * rnd(seed, 1);
        if (z + w > _z1 + 2.0) break;
        out.add((s, z + w / 2, w, 8.6 + 3.4 * rnd(seed, 2)));
        z += w + 0.15;
      }
    }
    return out;
  }();

  /// How far out their fronts are from the street's middle; their depth.
  static const _houseFront = 25.6, _houseD = 8.0;

  /// A house's frame: its front's middle on the pavement, facing the street.
  static vm.Matrix4 _houseAt(double s, double zc) => trs(vm.Vector3(s * _houseFront, bank, zc), rotY: s * math.pi / 2);

  /// The terraces, for the talk's flights to go over.
  @override
  late final volumes = [for (final (s, zc, w, h) in _houses) building(w, _houseD, h + 1.2, on: _houseAt(s, zc))];

  @override
  Future<void> init() async {
    final b = Batch();
    final paving = await photoPbr('pavement'), stone = pbr(rgb(1, 1, 1), roughness: 0.6);
    final asphalt = await photoPbr('asphalt');
    const len = _z1 - _z0, mid = (_z0 + _z1) / 2;
    // The two sides: paved, a kerb along the street, a kerb down to the
    // lawn at their ends.
    for (final s in [-1.0, 1.0]) {
      final x0 = s * _canal, x1 = s * (_canal + _bankW);
      b.add(paving, _laid(CuboidGeometry(vm.Vector3(_bankW, bank + 0.3, len)).extractMeshData(), vm.Vector3((x0 + x1) / 2, (bank - 0.3) / 2, mid)).transformed(frame));
      box(b, stone, 0.3, bank + 0.12, len, s * (_canal + 0.15), (bank + 0.12) / 2 - 0.06, mid, Vignette.c(0xA9A79F));
      for (final z in [_z0, _z1]) {
        box(b, stone, _bankW, bank + 0.12, 0.3, s * (_canal + _bankW / 2), (bank + 0.12) / 2 - 0.06, z, Vignette.c(0xA9A79F));
      }
    }
    // The street: from the avenue's far pavement, through the town and on
    // south out into the country; a dashed line down its middle, a zebra
    // where the town starts and where it ends.
    final north = Plan.aveZ0 - 2.4 - o.z, south = -640.0 - o.z;
    b.add(asphalt, _laid(CuboidGeometry(vm.Vector3(2 * _canal, 0.3, north - south)).extractMeshData(), vm.Vector3(0, _road - 0.15, (north + south) / 2)).transformed(frame));
    final white = Vignette.c(0xE6E6DE);
    for (var z = south + 4; z < north - 4; z += 7) {
      if ((z - _bridgeZ).abs() < 3 || (z - (_z0 + 4)).abs() < 3) continue;
      box(b, stone, 0.15, 0.012, 3.0, 0, _road + 0.006, z, white);
    }
    for (final z in [_bridgeZ, _z0 + 4]) {
      for (var x = -_canal + 0.7; x < _canal - 0.4; x += 0.9) {
        box(b, stone, 0.45, 0.012, 3.0, x, _road + 0.007, z, white);
      }
    }
    // The tables' canopies (the tables are the store's, v_phones.dart): four
    // posts round each, a roof in its bank's colour.
    for (final (x, red) in [(-8.6, true), (8.6, false)]) {
      for (final dx in [-1.0, 1.0]) {
        for (final dz in [-2.0, 2.0]) {
          box(b, stone, 0.1, 2.8, 0.1, x + dx, bank + 1.4, 14 + dz, Vignette.c(0x2A2E35));
        }
      }
      box(b, stone, 2.6, 0.12, 4.6, x, bank + 2.86, 14, Vignette.c(red ? 0xC8442F : 0x2F8F5B));
    }
    // The page's billboard (v_engines.dart): two masts behind where its
    // board rises.
    for (final dz in [-4.6, 4.6]) {
      box(b, stone, 0.3, 9.6, 0.3, -9.4, bank + 4.8, -34 + dz, Vignette.c(0x5A6470));
    }
    await _terraces(b, paving, stone);
    b.buildInto(shell, 'tradeoff town', castsShadows: false, lightChannelMask: 0x01);
    await Future.wait([_signs(), _trees(), _lamps()]);
  }

  /// Street lights (lamps.dart) along the way in from the avenue, on
  /// either side in turn, their arms out over the street.
  Future<void> _lamps() async {
    final lamps = Lamps();
    await lamps.load(const [LampKind.tokyo]);
    var k = 0;
    for (var z = _z1 + 14; z < Plan.aveZ0 - 8 - o.z; z += 24, k++) {
      final s = k.isEven ? -1.0 : 1.0;
      lamps.place(LampKind.tokyo, place(trs(vm.Vector3(s * (_canal + 1.2), 0, z), rotY: s * math.pi / 2)));
    }
    lamps.addTo(shell.add, 'tradeoff lamps');
  }

  /// Each side's sign at its south end, to the way in.
  Future<void> _signs() async {
    Future<void> board(double x, Color ground, String top, String big) => sign(16.0, 4.0, trs(vm.Vector3(x, bank + 4.0, _z0 + 2.0)), (c, s) {
      final r = Offset.zero & s;
      c
        ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s.height * 0.08)), Paint()..color = ground)
        ..drawRRect(
          RRect.fromRectAndRadius(r.deflate(s.height * 0.05), Radius.circular(s.height * 0.06)),
          Paint()
            ..color = const Color(0xFFF4F6F8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.height * 0.025,
        );
      Vignette.text(c, top, Rect.fromLTWH(0, s.height * 0.14, s.width, s.height * 0.24), s.height * 0.16, const Color(0xFFF4F6F8), weight: FontWeight.w600);
      Vignette.text(c, big, Rect.fromLTWH(0, s.height * 0.4, s.width, s.height * 0.46), s.height * 0.36, const Color(0xFFFFFFFF), weight: FontWeight.w800);
    }, px: 1600, glow: 0.35, thick: 0.1, shell: true);
    final post = pbr(v4(hex3(0x5A6470)), roughness: 0.5);
    for (final x in [-(_canal + _bankW / 2), _canal + _bankW / 2]) {
      for (final dx in [-6.8, 6.8]) {
        shell.add(
          Node(name: 'tradeoff sign post', mesh: Mesh(CuboidGeometry(vm.Vector3(0.26, 4.0, 0.26)), post), localTransform: place(trs(vm.Vector3(x + dx, bank + 2.0, _z0 + 2.12))))
            ..castsShadows = false,
        );
      }
    }
    await Future.wait([
      board(-(_canal + _bankW / 2), const Color(0xFF9A2F2A), 'WHAT FLUTTER', "DOESN'T HAVE"),
      board(_canal + _bankW / 2, const Color(0xFF1F7A4C), 'WHAT FLUTTER', 'HAS'),
    ]);
  }

  /// Trees along the sides' outer edges: leafy ones (grove.dart).
  /// The terraces ([_houses]) on a pavement of their own along each side:
  /// shops on the ground floor (shops.dart, no awnings: the trees are in
  /// front), brick with sash windows over most of them, the odd one
  /// rendered; finished round their roofs (trim.dart).
  Future<void> _terraces(Batch b, Material paving, Material stone) async {
    final faces = await Future.wait([photoPbr('facade_stone'), photoPbr('facade_tile'), photoPbr('facade_clad')]);
    final shops = await ShopMaterials.make();
    const z0 = _z0 - 2.2, z1 = _z1 + 2.2, x0 = _canal + _bankW, x1 = _houseFront + _houseD + 0.6;
    for (final s in [-1.0, 1.0]) {
      b.add(paving, _laid(CuboidGeometry(vm.Vector3(x1 - x0, bank + 0.3, z1 - z0)).extractMeshData(), vm.Vector3(s * (x0 + x1) / 2, (bank - 0.3) / 2, (z0 + z1) / 2)).transformed(frame));
    }
    for (final (i, (s, zc, w, h)) in _houses.indexed) {
      final xf = frame * _houseAt(s, zc) * vm.Matrix4.translation(vm.Vector3(0, 0, _houseD / 2));
      b.add(faces[i % 3], painted(PackageTown.facadeBox(w, h - shopFloor, _houseD, ou: 0.25 * i, ov: 0.375 * i).transformed(xf * vm.Matrix4.translation(vm.Vector3(0, shopFloor, 0))), vm.Vector4(1, 1, 1, 1)));
      addTrim(b, stone, xf, w, h, _houseD, seed: 300 + i, base: false);
      addShops(b, stone, shops, xf, w, _houseD, seed: 300 + i, awning: (_, _) => false);
      if (i % 3 != 2) addBrickFront(b, shops, xf, w, h, _houseD);
    }
  }

  Future<void> _trees() async {
    final grove = Grove();
    await grove.load(const [TreeKind.leafyRound, TreeKind.leafyWide]);
    var i = 0;
    for (final s in [-1.0, 1.0]) {
      for (var z = _z0 + 5; z <= _z1 - 3; z += 9) {
        grove.plant(
          i.isEven ? TreeKind.leafyWide : TreeKind.leafyRound,
          frame * trs(vm.Vector3(s * (_canal + _bankW - 2.2), bank, z), rotY: rnd(i, 3) * 6, s: vm.Vector3.all(0.8 + 0.3 * rnd(i, 1))),
          shade: 0.92 + 0.14 * rnd(i, 4),
        );
        i++;
      }
    }
    grove.addTo(shell.add, 'tradeoff trees');
  }

  @override
  void pose(double u, double t, double night) {}

  // ── The camera ────────────────────────────────────────────────────────────

  /// From the south, high over the street: both sides, their signs, the
  /// city beyond; easing in a little.
  @override
  Shot shot(double u) {
    final k = eio(seg(u, 0, 10));
    return Shot(vm.Vector3(lerp(-2, 0, k), lerp(64, 56, k), lerp(-92, -86, k)), vm.Vector3(0, 0, lerp(-20, -17, k)), fov: 46, settle: 1.0, drift: 0.6);
  }

  /// [d] (a slab: paving) moved to [at] in the town's frame, its texture
  /// laid at 3 m a tile where it is in the world.
  static MeshData _laid(MeshData d, vm.Vector3 at) {
    final m = d.transformed(vm.Matrix4.translation(at));
    final uv = Float32List(m.vertexCount * 2);
    for (var i = 0; i < m.vertexCount; i++) {
      uv
        ..[i * 2] = (o.x + m.positions[i * 3]) / 3
        ..[i * 2 + 1] = (o.z + m.positions[i * 3 + 2]) / 3;
    }
    return painted(m, vm.Vector4(1, 1, 1, 1), uvs: uv);
  }
}
