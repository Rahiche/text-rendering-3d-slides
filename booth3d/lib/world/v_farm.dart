import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Curves;
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/font_data.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'figure.dart';
import 'kit.dart';
import 'motion.dart';
import 'shot.dart';
import 'site_geo.dart' show setTqs;
import 'vignette.dart';

/// Rasterization, a field beyond the park (north of the tram): its plots
/// are pixels — white, as a screen's are under black text. First what a
/// font keeps for an "a" (Space Grotesk's own, read from the font file):
/// no pixels at all, its outline — the points on it, and the control
/// points that bend TrueType's curves between them — drawn in light over
/// the field, as a font editor shows them. Then the field is a screen's
/// pixels: every plot works out at once how much of it the outline covers
/// (a sprinkler each, all together: a GPU shades every pixel in parallel,
/// not row by row) and comes up that much. Three ways, a press each, every
/// plot changing together, a marker in the margin saying what each is:
/// aliased (on if half covered, black, or not at all); subpixel (each plot
/// a third at a time, red, green and blue, each as much as it's covered);
/// then grayscale, Flutter's (as grey as it's covered: black where it's all
/// inside, greys on the edges, white outside). From the air: the "a", pixel
/// for pixel as a screen shows it, its outline over it. A press a part (01
/// raster, the outline; then from [pixels], [subpixel] and [grayscale]); on
/// round a build's tour, the field cleared; the farmer watches.
class PixelFarm extends Vignette {
  PixelFarm(super.kit);

  @override
  String get name => 'farm';
  @override
  String get kick => 'RASTERIZATION';
  @override
  String get line => 'Outline → aliased, subpixel, grey';
  @override
  String get note => 'a font stores points and curves; each pixel shaded by how much of it the outline covers';

  @override
  double get loop => 22;
  @override
  double get visit => 16;

  @override
  final frame = trs(vm.Vector3(-9, 0, 79));

  /// The field: plots across and down, each plot's size.
  static const _cols = 24, _rows = 18, _cell = 0.5;
  static double _x(int c) => (c - (_cols - 1) / 2) * _cell;
  static double _z(int r) => ((_rows - 1) / 2 - r) * _cell;

  /// Each plot's coverage (0..1), and each third's of it (left to right:
  /// red, green, blue), from the outline filled 12 × 4 samples a plot; its
  /// middle in the world, and its thirds'.
  final _cover = List.filled(_cols * _rows, 0.0), _thirds = List.filled(_cols * _rows * 3, 0.0);
  late final _at = [
    for (var r = 0; r < _rows; r++)
      for (var c = 0; c < _cols; c++) frame.transform3(vm.Vector3(_x(c), 0, _z(r))),
  ];
  late final _at3 = [
    for (var r = 0; r < _rows; r++)
      for (var c = 0; c < _cols; c++)
        for (var j = 0; j < 3; j++) frame.transform3(vm.Vector3(_x(c) + (j - 1) * _third, 0, _z(r))),
  ];

  /// A crop's width, and a third of it (each plot's crop grows as three,
  /// side by side: one block, but for subpixel's).
  static const _crop = _cell * 0.86, _third = _crop / 3;

  /// The timeline: the outline's points come up, its control points, its
  /// curves traced; from [pixels] (the next press): the points go, every
  /// sprinkler at once, every plot up together, aliased; from [subpixel]
  /// (a press) shaded that way, and from [grayscale] (the last) Flutter's
  /// way, each a moment after its press over [_shift] s; held; then (round
  /// a build's tour) the field cleared.
  static const _onPts = 0.6, _offPts = 1.9, _trace0 = 2.9, _trace1 = 4.6;
  static const pixels = 6.4, subpixel = 11.0, grayscale = 13.5, hold = 16.0;
  static const _spray = 7.4, _grow0 = 7.6, _grow1 = 8.8, _shift = 0.9, _clear0 = 19.0, _clear1 = 21.2;

  /// What each way of shading the plots does, and how it looks, on a marker
  /// in the field's margin (as a crop's name is), sprung up as it comes; the
  /// markers, where they stand.
  static const _says = [
    ('ALIASED', 'black or white, nothing between', 'jagged edges'),
    ('SUBPIXEL', 'a third each: red, green, blue', 'sharper, but colour fringes'),
    ('GRAYSCALE', 'as grey as it is covered', 'smooth: what Flutter does'),
  ];
  final _markers = <Node>[];
  static const _markX = 4.85, _markZ = 2.5;

  /// Where the farmer stands, beside the field; the fence (half its width
  /// and depth).
  static const _standX = _cols * _cell / 2 + 1.0;
  static const _fenceX = _cols * _cell / 2 + 1.45, _fenceZ = _rows * _cell / 2 + 1.05;

  /// The outline, on the field (x across, z up the glyph): its points (on
  /// the curve, or a control point off it; how far through them it is,
  /// 0..1); each control point's handles; its curves as short straight
  /// pieces, each with how far along the outline it starts (0..1).
  final _points = <(double, double, bool, double)>[];
  final _handles = <(double, double, double, double, double)>[];
  final _pieces = <(double, double, double, double, double)>[];
  int _contours = 0;

  late final InstancedMesh _crops, _jets;
  int _farmer = -1;
  final _p = FigurePose();
  bool _ready = false;
  final _m = vm.Matrix4.identity();
  final _q = vm.Quaternion.identity();

  static const _glyph = 'a';
  static const _style = TextStyle(fontFamily: BP.display, fontWeight: FontWeight.w700);

  @override
  List<(String, TextStyle)> get fontRuns => [('$_glyph PIXEL FARM', _style)];

  @override
  Future<void> init() async {
    makePool(boxes: 8, glows: 440, cyls: 2);
    await _outline();
    final b = Batch();
    final m = pbr(rgb(1, 1, 1), roughness: 0.95);
    // The field, white as unlit pixels; the plots' grid in a light grey; a
    // fence round it (room inside it for the boom's towers, and the
    // farmer).
    final w = _fenceX, d = _fenceZ;
    box(b, m, 2 * w - 0.2, 0.06, 2 * d - 0.2, 0, 0.03, 0, Vignette.c(0xEDEDEB));
    for (var c = 0; c <= _cols; c++) {
      box(b, m, 0.03, 0.065, _rows * _cell, (c - _cols / 2) * _cell, 0.035, 0, Vignette.c(0xBDBDBD));
    }
    for (var r = 0; r <= _rows; r++) {
      box(b, m, _cols * _cell, 0.065, 0.03, 0, 0.035, (r - _rows / 2) * _cell, Vignette.c(0xBDBDBD));
    }
    for (final (x0, z0, x1, z1) in [(-w, -d, w, -d), (-w, d, w, d), (-w, -d, -w, d), (w, -d, w, d)]) {
      final len = math.sqrt((x1 - x0) * (x1 - x0) + (z1 - z0) * (z1 - z0));
      box(b, m, x0 == x1 ? 0.06 : len, 0.06, x0 == x1 ? len : 0.06, (x0 + x1) / 2, 0.55, (z0 + z1) / 2, Vignette.c(0xF4F1EA));
      for (var k = 0; k <= len / 1.5; k++) {
        final f = k / (len / 1.5);
        box(b, m, 0.08, 0.7, 0.08, lerp(x0, x1, f), 0.35, lerp(z0, z1, f), Vignette.c(0xF4F1EA));
      }
    }
    b.buildInto(detail, 'pixel farm', castsShadows: false, lightChannelMask: 0x01);
    // The crops: three instances a plot, a third each.
    _crops = InstancedMesh(geometry: CuboidGeometry(vm.Vector3.all(1)), material: pbr(rgb(1, 1, 1), roughness: 0.9));
    for (var i = 0; i < _cols * _rows * 3; i++) {
      _crops.addInstance(hidden, color: rgb(1, 1, 1));
    }
    detail.add(
      Node(name: 'pixel farm crops')
        ..addComponent(InstancedMeshComponent(_crops))
        ..castsShadows = false,
    );
    // The sprinklers' jets, one a plot: every one at once.
    _jets = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3.all(1)),
      material: pbr(rgb(0.55, 0.8, 1.0), roughness: 0.3, emissive: vm.Vector4(0.35, 0.65, 1.0, 1), emissiveStrength: 1.6),
    );
    for (var i = 0; i < _cols * _rows; i++) {
      _jets.addInstance(hidden);
    }
    detail.add(
      Node(name: 'pixel farm jets')
        ..addComponent(InstancedMeshComponent(_jets))
        ..castsShadows = false,
    );
    await sign(4.2, 0.9, vm.Matrix4.translation(vm.Vector3(0, 1.4, -_fenceZ - 0.3)), (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E5E2E));
      Vignette.text(c, 'PIXEL FARM', Rect.fromLTWH(0, 0, s.width, s.height * 0.62), s.height * 0.44, const Color(0xFFF4EBD8), lang: 'ja');
      Vignette.text(c, 'coverage → grey', Rect.fromLTWH(0, s.height * 0.6, s.width, s.height * 0.34), s.height * 0.24, const Color(0xFFF2C94C));
    });
    for (final (title, does, looks) in _says) {
      _markers.add(
        await sign(3.2, 1.6, hidden, (c, s) {
          c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E5E2E));
          Vignette.text(c, title, Rect.fromLTWH(0, s.height * 0.05, s.width, s.height * 0.34), s.height * 0.27, const Color(0xFFF2C94C));
          Vignette.text(c, does, Rect.fromLTWH(s.width * 0.04, s.height * 0.42, s.width * 0.92, s.height * 0.25), s.height * 0.18, const Color(0xFFF4EBD8));
          Vignette.text(c, looks, Rect.fromLTWH(s.width * 0.04, s.height * 0.69, s.width * 0.92, s.height * 0.25), s.height * 0.18, const Color(0xFFF4EBD8));
        }),
      );
    }
    _farmer = person(
      FigureLook()
        ..top = rgbHex(0x3A5A8C)
        ..legs = rgbHex(0x5B4B3A)
        ..shoes = rgbHex(0x3A2E26)
        ..skin = rgbHex(0xC59A7C)
        ..hairColor = rgbHex(0x8F8B86)
        ..cap = rgbHex(0xE9E2D2),
    );
    _ready = true;
  }

  /// The glyph's outline from the font file (its default instance), its
  /// height over 14 rows, in the field's middle; then filled, 4 × 4 samples
  /// a plot, and read back: each plot's share of ink.
  Future<void> _outline() async {
    final font = await FontData.spaceGrotesk();
    final o = font.outline(font.glyphId(_glyph.codeUnitAt(0)));
    final b = o.bounds, s = 14 * _cell / b.height;
    vm.Vector2 at(double x, double y) => vm.Vector2((x - b.center.dx) * s, (y - b.center.dy) * s);
    _contours = o.contours.length;
    final total = math.max(1, o.pointCount - 1);
    final curves = <(vm.Vector2, vm.Vector2?, vm.Vector2)>[];
    var n = 0;
    for (final c in o.contours) {
      final pts = [for (final p in c) (at(p.x, p.y), p.onCurve)];
      for (final (p, on) in pts) {
        _points.add((p.x, p.y, on, n++ / total));
      }
      curves.addAll(_segments(pts));
    }
    // The curves in short straight pieces (8 a curve), how far along each
    // starts; each control point's two handles.
    final raw = <(vm.Vector2, vm.Vector2)>[];
    for (final (p0, ctrl, p1) in curves) {
      if (ctrl == null) {
        if ((p1 - p0).length > 1e-4) raw.add((p0, p1));
        continue;
      }
      vm.Vector2 q(double t) => p0 * ((1 - t) * (1 - t)) + ctrl * (2 * (1 - t) * t) + p1 * (t * t);
      for (var k = 0; k < 8; k++) {
        raw.add((q(k / 8), q((k + 1) / 8)));
      }
      final order = _points.indexWhere((p) => !p.$3 && (vm.Vector2(p.$1, p.$2) - ctrl).length < 1e-4);
      final along = order < 0 ? 0.0 : _points[order].$4;
      _handles
        ..add((ctrl.x, ctrl.y, p0.x, p0.y, along))
        ..add((ctrl.x, ctrl.y, p1.x, p1.y, along));
    }
    final length = raw.fold<double>(0, (a, r) => a + (r.$2 - r.$1).length);
    var walked = 0.0;
    for (final (a, z) in raw) {
      _pieces.add((a.x, a.y, z.x, z.y, walked / length));
      walked += (z - a).length;
    }
    // Filled, as the coverage it gives each plot and each third of it.
    const kx = 12, ky = 4, w = _cols * kx, h = _rows * ky;
    final path = ui.Path();
    ui.Offset px(vm.Vector2 p) => ui.Offset((p.x / _cell + _cols / 2) * kx, (_rows / 2 - p.y / _cell) * ky);
    for (final c in o.contours) {
      final segs = _segments([for (final p in c) (at(p.x, p.y), p.onCurve)]);
      if (segs.isEmpty) continue;
      final s0 = px(segs.first.$1);
      path.moveTo(s0.dx, s0.dy);
      for (final (_, ctrl, p1) in segs) {
        final e = px(p1);
        if (ctrl == null) {
          path.lineTo(e.dx, e.dy);
        } else {
          final cp = px(ctrl);
          path.quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy);
        }
      }
      path.close();
    }
    final rec = ui.PictureRecorder();
    Canvas(rec).drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
    final image = await rec.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) return;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final i = r * _cols + c;
        for (var j = 0; j < 3; j++) {
          var sum = 0;
          for (var y = 0; y < ky; y++) {
            for (var x = j * kx ~/ 3; x < (j + 1) * kx ~/ 3; x++) {
              sum += data.getUint8(((r * ky + y) * w + c * kx + x) * 4 + 3);
            }
          }
          _thirds[i * 3 + j] = sum / (255 * ky * kx / 3);
        }
        _cover[i] = (_thirds[i * 3] + _thirds[i * 3 + 1] + _thirds[i * 3 + 2]) / 3;
      }
    }
    if (const String.fromEnvironment('BOOTH3D_TIMES') != '') {
      final on = _points.where((p) => p.$3).length;
      debugPrint('FARM "$_glyph": $_contours contours, ${_points.length} points ($on on the curve, ${_points.length - on} control points)');
    }
  }

  /// A contour (its points, on the curve or off it) as TrueType draws it:
  /// from an on-curve point, straight lines and quadratic curves (between
  /// two control points, a point on the curve implied half way).
  static List<(vm.Vector2, vm.Vector2?, vm.Vector2)> _segments(List<(vm.Vector2, bool)> pts) {
    if (pts.isEmpty) return const [];
    final first = pts.indexWhere((p) => p.$2);
    final vm.Vector2 start;
    final List<(vm.Vector2, bool)> seq;
    if (first < 0) {
      start = (pts.last.$1 + pts.first.$1) * 0.5;
      seq = pts;
    } else {
      start = pts[first].$1;
      seq = [...pts.sublist(first + 1), ...pts.sublist(0, first)];
    }
    final out = <(vm.Vector2, vm.Vector2?, vm.Vector2)>[];
    var pen = start;
    vm.Vector2? ctrl;
    for (final (p, on) in seq) {
      if (on) {
        out.add((pen, ctrl, p));
        pen = p;
        ctrl = null;
      } else {
        if (ctrl != null) {
          final mid = (ctrl + p) * 0.5;
          out.add((pen, ctrl, mid));
          pen = mid;
        }
        ctrl = p;
      }
    }
    out.add((pen, ctrl, start));
    return out;
  }

  // ── Posing ────────────────────────────────────────────────────────────────

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    pool.begin();
    // Every plot at once: its sprinkler's jet, then up as much as the
    // outline covers it (cleared again round a build's tour).
    final spray = math.sin(math.pi * seg(u, _spray, _spray + 0.9));
    final rise = Curves.easeOutBack.transform(seg(u, _grow0, _grow1)) * (1 - eio(seg(u, _clear0, _clear1))), ink = math.min(1.0, rise);
    // How they're shaded: aliased (a), subpixel (s) or grayscale (g), each
    // in turn, every plot at once.
    final g = eio(seg(u, grayscale + 0.4, grayscale + 0.4 + _shift)), s = eio(seg(u, subpixel + 0.4, subpixel + 0.4 + _shift)) * (1 - g), a = 1 - s - g;
    _q.setEuler(kit.yawOf(frame), 0, 0);
    for (var i = 0; i < _cols * _rows; i++) {
      final at = _at[i], c = _cover[i];
      if (spray > 0.02) {
        _jets.setInstanceTransform(i, setTqs(_m, at.x, 0.06 + 0.3 * spray, at.z, _q, 0.1, 0.6 * spray, 0.1));
      } else {
        _jets.setInstanceTransform(i, hidden);
      }
      // Aliased: on, all the way up and black, if half covered. Grayscale:
      // up as much as it's covered, as grey (black ink on white: 1 −
      // coverage, in sRGB). Subpixel: each third up as much as it's
      // covered, in its own colour that dark (and on an edge's plot, a stub
      // of each lit third).
      final on = c >= 0.5 ? 1.0 : 0.0, black = math.pow(1 - on * ink, 2.2).toDouble(), grey = math.pow(1 - c * ink, 2.2).toDouble();
      for (var j = 0; j < 3; j++) {
        final k = i * 3 + j, third = _thirds[k];
        final fill = (a * on + s * (c > 0.02 ? math.max(third, 0.08) : 0) + g * c) * rise;
        if (fill < 0.02) {
          _crops.setInstanceTransform(k, hidden);
          continue;
        }
        final hgt = 0.06 + 0.55 * fill, p = _at3[k];
        _crops.setInstanceTransform(k, setTqs(_m, p.x, 0.06 + hgt / 2, p.z, _q, _third, hgt, _crop));
        final lit = s * math.pow(1 - third * ink, 2.2).toDouble(), shade = a * black + g * grey;
        _crops.setInstanceColor(k, vm.Vector4(shade + (j == 0 ? lit : 0), shade + (j == 1 ? lit : 0), shade + (j == 2 ? lit : 0), 1));
      }
    }
    // The markers: what the shading on now is, sprung up in the margin (the
    // last sinking as it goes), on a stake.
    for (final (k, from, to) in [(0, _grow1, subpixel + 0.4), (1, subpixel + 0.4 + _shift, grayscale + 0.4), (2, grayscale + 0.4 + _shift, _clear0)]) {
      final up = Curves.easeOutBack.transform(seg(u, from, from + 0.5)) * (1 - eio(seg(u, to, to + 0.3)));
      final m = _markers[k];
      m.visible = up > 0.01;
      if (!m.visible) continue;
      m.localTransform = place(trs(vm.Vector3(_markX, 0.25 + 0.75 * up, _markZ), rotY: 0.41, rotX: 0.85) * vm.Matrix4.diagonal3Values(1, up, 1));
      pbox(_markX + 0.12, 0.42 * up, _markZ + 0.3, 0.07, 0.84 * up, 0.07, Vignette.c(0x6B4E2E));
    }
    _drawOutline(u, t, rise);
    // The farmer, beside the field, watching it.
    final p = _p..rest();
    p.pos.setValues(_standX, 0, -2.2);
    final m = Manner.of(190);
    Idle.stand(p, t, m);
    p.yaw = math.pi / 2 + Idle.facing(t, m, 0.25);
    draw(_farmer, p);
    pool.end();
  }

  /// The outline in light over the field: its points coming up one after
  /// another (on the curve: white squares), then its control points
  /// (amber, their handles to the points either side); its curves traced
  /// round. Once it's pixels, just the curves, over the crops' tops.
  void _drawOutline(double u, double t, double rise) {
    final out = 1 - eio(seg(u, _clear0 - 0.6, _clear0));
    if (out <= 0.001 || u < _onPts) return;
    final y = 0.1 + 0.62 * math.min(1.0, rise);
    final marks = (1 - eio(seg(u, pixels, pixels + 0.8))) * out;
    final trace = eio(seg(u, _trace0, _trace1));
    final line = vm.Vector4(0.4, 2.2, 3.4, 1) * (out * (rise > 0.5 ? 0.8 : 1.0));
    for (final (x0, z0, x1, z1, along) in _pieces) {
      if (along > trace) continue;
      _bar(x0, z0, x1, z1, y, 0.08, line);
    }
    if (marks <= 0.001) return;
    final amber = vm.Vector4(2.4, 1.3, 0.35, 1) * marks;
    for (final (cx, cz, x, z, along) in _handles) {
      final k = seg(u, _offPts + 0.9 * along + 0.1, _offPts + 0.9 * along + 0.4);
      if (k <= 0) continue;
      _bar(cx, cz, lerp(cx, x, k), lerp(cz, z, k), y - 0.01, 0.035, amber * 0.85);
    }
    for (final (x, z, on, order) in _points) {
      final k = Curves.easeOutBack.transform(seg(u, (on ? _onPts + 1.1 * order : _offPts + 0.9 * order), (on ? _onPts + 1.1 * order : _offPts + 0.9 * order) + 0.3));
      if (k <= 0) continue;
      if (on) {
        pglow(x, y + 0.02, z, 0.21 * k, 0.05, 0.21 * k, vm.Vector4(2.6, 2.6, 2.6, 1) * marks);
      } else {
        pglow(x, y + 0.02, z, 0.16 * k, 0.05, 0.16 * k, amber * 1.3, yaw: math.pi / 4);
      }
    }
  }

  /// A glowing bar from (x0, z0) to (x1, z1) of the field at height [y].
  void _bar(double x0, double z0, double x1, double z1, double y, double th, vm.Vector4 c) {
    final dx = x1 - x0, dz = z1 - z0, len = math.sqrt(dx * dx + dz * dz);
    if (len < 1e-4) return;
    pglow((x0 + x1) / 2, y, (z0 + z1) / 2, len + th * 0.6, th * 0.5, th, c, yaw: math.atan2(-dz, dx));
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    // Over the field, the outline on it; as the plots come up, higher: the
    // glyph, anti-aliased, from the air.
    final k = smooth(_grow0, _grow1 + 2.6, u);
    final eye = vm.Vector3(lerp(-0.4, -0.6, k), lerp(11.8, 15.5, k), lerp(-7.6, -9.5, k));
    final tg = vm.Vector3(0, lerp(0.1, 0.2, k), lerp(0.9, 0.4, k));
    return Shot(eye, tg, fov: lerp(44, 40, k), settle: 1.2, drift: 0.4);
  }
}
