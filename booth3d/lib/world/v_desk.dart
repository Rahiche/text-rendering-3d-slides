import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../talk/intro_slides.dart';
import '../talk/title_slide.dart';
import 'devices.dart' show Laptop3D;
import 'kit.dart';
import 'models.dart';
import 'shapes.dart' show bevelBox;
import 'shot.dart';
import 'vignette.dart';

/// The presenter's desk, where the talk opens: a laptop on a table on a
/// roof terrace over the plaza (the corner block east of it, on the
/// avenue, beside its テキスト sign), the talk's first slide on its
/// screen. The talk starts square on that screen, the slide filling the
/// picture (drawn crisp over it too: talk_overlay.dart); the next press
/// pulls back from it, slowly, then faster and faster, up and away (the
/// same share farther each moment: a zoom out by powers of ten), turning
/// to the whole city.
class DeskScene extends Vignette {
  DeskScene(super.kit);

  @override
  String get name => 'desk';
  @override
  String get kick => 'THE TALK';
  @override
  String get line => TitleSlide.title;
  @override
  String get note => 'from code points to pixels';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 30;
  @override
  double get visit => reveal;

  /// The terrace, on the corner block's roof (its top 14.3 m up) short of
  /// its south-west corner: the table in the middle of it.
  @override
  final frame = trs(vm.Vector3(30.2, 14.3, -6.3));

  /// How long the camera takes to pull back (seconds).
  static const reveal = 8.5;

  /// The laptop's screen (m): the slide's 16:9. The deck's top, the
  /// table's.
  static const _w = 0.32, _h = 0.18, _floor = 0.05, _top = 0.8;

  /// The camera on the slide (the screen fills its view), and where it
  /// ends up: high over the avenue, the plaza, the park and the skyline
  /// ahead of it.
  static const _fov0 = 30.0, _fov1 = 46.0;
  static final _eye1 = vm.Vector3(36, 31, -54), _target1 = vm.Vector3(4, 5, 22);

  /// The roof's edges (its top's), in the frame.
  static const _west = -1.89, _east = 8.73, _south = -2.075, _north = 10.3;

  late final Laptop3D _laptop;

  /// Its screen's pictures: the talk's title slide, and the last of its
  /// opening's slides (all drawn); the one up now.
  Texture2D? _title, _last, _up;

  /// Shows the opening's slide [page] on the laptop: the last one shown
  /// full (the talk's: the camera pulls back from it), or the title (the
  /// first, and when the talk's off).
  set shown(int page) {
    final t = page <= 0 ? _title : _last;
    if (t == null || identical(t, _up)) return;
    _laptop.page = t;
    _up = t;
  }

  /// The screen's corners in the world (top left first, then clockwise as
  /// it's seen), its middle and which way it faces.
  late final List<vm.Vector3> corners;
  late final vm.Vector3 _mid, _facing;

  @override
  Future<void> init() async {
    final title = await paintedTexture(1600, 900, TitleSlide.paint);
    final last = await paintedTexture(1600, 900, (c, s) => IntroSlides.paint(c, s, IntroSlides.count - 1, double.infinity));
    // (Turned a little towards where the camera ends up.)
    _laptop = Laptop3D(detail, w: _w, h: _h, page: title, name: 'desk laptop')..place(place(trs(vm.Vector3(0, _top, -0.12), rotY: -0.12)));
    _title = _up = title;
    _last = last;
    // (Turned up: as white as the slide drawn over it, as that fades.)
    _laptop.pageMat.emissiveStrength = 1.7;
    corners = _laptop.corners;
    _mid = (corners[0] + corners[2]) * 0.5;
    _facing = (corners[1] - corners[0]).cross(corners[3] - corners[0])..normalize();
    if (_facing.dot(vm.Vector3(0, 0, -1)) < 0) _facing.negate();

    final b = Batch();
    final wood = pbr(rgb(1, 1, 1), roughness: 0.62);
    final steel = pbr(rgb(1, 1, 1), metallic: 0.7, roughness: 0.42);
    final shiny = pbr(rgb(1, 1, 1), roughness: 0.22);
    final matte = pbr(rgb(1, 1, 1), roughness: 0.85);
    void at(Material m, double w, double h, double d, vm.Matrix4 xf, int color) => b.add(m, painted(bevelBox(w, h, d).transformed(place(xf)), Vignette.c(color)));

    // The deck: teak boards along the roof, a little gap between them.
    const decks = [0x8A5B3C, 0x93623F, 0x7F5437, 0x9A6B47, 0x865838];
    var k = 0;
    for (var z = -1.85; z < 1.6; z += 0.152) {
      box(b, wood, 3.8, _floor, 0.14, 0.45, _floor / 2, z + 0.07, Vignette.c(decks[k++ % decks.length]));
    }
    // The table: a teak top on black steel legs.
    box(b, wood, 1.2, 0.04, 0.7, 0, _top - 0.02, 0, Vignette.c(0x77502F));
    for (final (x, z) in [(-0.52, -0.27), (0.52, -0.27), (-0.52, 0.27), (0.52, 0.27)]) {
      box(b, steel, 0.045, _top - 0.04 - _floor, 0.045, x, _floor + (_top - 0.04 - _floor) / 2, z, Vignette.c(0x1E2126));
    }
    box(b, steel, 1.0, 0.04, 0.04, 0, _top - 0.06, -0.27, Vignette.c(0x1E2126));
    box(b, steel, 1.0, 0.04, 0.04, 0, _top - 0.06, 0.27, Vignette.c(0x1E2126));
    // Its chair, pushed back and turned (the presenter's just stood up).
    final chair = trs(vm.Vector3(0.95, _floor, -0.75), rotY: 0.75);
    vm.Matrix4 onChair(double x, double y, double z) => chair * trs(vm.Vector3(x, y, z));
    at(wood, 0.46, 0.04, 0.44, onChair(0, 0.45, 0), 0x8B5E3C);
    for (final (x, z) in [(-0.2, -0.19), (0.2, -0.19), (-0.2, 0.19), (0.2, 0.19)]) {
      at(steel, 0.03, 0.43, 0.03, onChair(x, 0.215, z), 0x1E2126);
    }
    for (final x in [-0.2, 0.2]) {
      at(steel, 0.03, 0.46, 0.03, onChair(x, 0.68, 0.2), 0x1E2126);
    }
    at(wood, 0.46, 0.2, 0.03, onChair(0, 0.8, 0.21), 0x8B5E3C);
    // On the table: a cup of coffee, a notebook and its pen, the clicker.
    cylinder(b, shiny, 0.042, 0.095, 0.36, _top + 0.0475, 0.02, Vignette.c(0xF2F0EC), sides: 20);
    cylinder(b, matte, 0.037, 0.004, 0.36, _top + 0.086, 0.02, Vignette.c(0x3A2416), sides: 20);
    b.add(shiny, part(TorusGeometry(radius: 0.026, tubeRadius: 0.007, radialSegments: 16, tubularSegments: 8), place(trs(vm.Vector3(0.41, _top + 0.05, 0.02), rotX: math.pi / 2)), Vignette.c(0xF2F0EC)));
    box(b, matte, 0.15, 0.012, 0.21, -0.39, _top + 0.006, 0.03, Vignette.c(0x1F3A5F), yaw: 0.18);
    cylinder(b, shiny, 0.0045, 0.14, -0.37, _top + 0.017, 0.03, Vignette.c(0x2A2D33), sides: 8, rotX: math.pi / 2);
    box(b, shiny, 0.036, 0.014, 0.1, 0.27, _top + 0.007, -0.22, Vignette.c(0x1A1C20), yaw: -0.3);
    // A planter at the deck's corner, an olive in it.
    box(b, matte, 0.55, 0.42, 0.55, -1.05, _floor + 0.21, 1.2, Vignette.c(0x3A3F45));
    // The roof's edges along the avenue and the plaza: a steel railing.
    void rail(double x0, double z0, double x1, double z1) {
      final len = math.sqrt((x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0)), yaw = math.atan2(z1 - z0, x1 - x0);
      final n = (len / 1.5).ceil();
      for (var i = 0; i <= n; i++) {
        final f = i / n;
        box(b, steel, 0.045, 1.05, 0.045, x0 + (x1 - x0) * f, 0.525, z0 + (z1 - z0) * f, Vignette.c(0x2A2E35));
      }
      for (final (y, t) in [(1.05, 0.055), (0.62, 0.02), (0.2, 0.02)]) {
        box(b, steel, len, t, t, (x0 + x1) / 2, y, (z0 + z1) / 2, Vignette.c(0x2A2E35), yaw: -yaw);
      }
    }

    rail(_west + 0.05, _south + 0.05, _east - 0.05, _south + 0.05);
    rail(_west + 0.05, _south + 0.05, _west + 0.05, _north - 0.05);
    b.buildInto(detail, 'desk');

    // (The city's own olive: its trunk and crown, small.)
    final tree = await modelParts('assets/models/tree_round.glb');
    final olive = place(trs(vm.Vector3(-1.05, _floor + 0.42, 1.2), rotY: 2.1, s: vm.Vector3.all(0.24)));
    detail
      ..add(Node(name: 'desk olive trunk', mesh: Mesh(MeshGeometry.fromMeshData(tree['trunk']!), pbr(v4(hex3(0x6A5442)), roughness: 0.92)), localTransform: olive))
      ..add(Node(name: 'desk olive crown', mesh: Mesh(MeshGeometry.fromMeshData(tree['crown']!), pbr(v4(hex3(0x5E7F4E)), roughness: 0.82)), localTransform: olive));
  }

  @override
  void pose(double u, double t, double night) {}

  /// The camera [u] seconds into the pull back: square on the screen, the
  /// slide filling the picture; then back and up, the same share farther
  /// each moment, turning from the screen to the city.
  @override
  Shot shot(double u) {
    final k = c01(u / reveal), e = k * k * (3 - 2 * k);
    final d0 = _h / 2 / math.tan(_fov0 * math.pi / 360);
    final away = _eye1 - _mid, far = away.length;
    // Square to the screen at first, then towards where it ends up.
    final w = smooth(0.15, 0.9, e);
    final dir = (_facing * (1 - w) + away / far * w)..normalize();
    final eye = _mid + dir * (d0 * math.pow(far / d0, e));
    // Looking at the screen till the terrace is in view, then at the city.
    final target = _mid + (_target1 - _mid) * smooth(0.4, 1, e);
    return Shot(
      local(eye, vm.Vector3.zero()),
      local(target, vm.Vector3.zero()),
      fov: lerp(_fov0, _fov1, smooth(0.3, 1, e)),
      settle: 1.0,
      drift: 0.6 * smooth(0.6, 1, e),
    );
  }
}
