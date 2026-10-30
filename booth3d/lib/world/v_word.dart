import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/booth/craft/extrude.dart' show GlyphMesh;
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'slug_word.dart';
import 'shot.dart';
import 'vignette.dart';

/// フラッター · The talk's own word, hung up only while a talk calls on it
/// (twice: 'word' on Trade-off Town's east bank, v_tradeoff.dart, for the
/// first turn; 'slug' in front of Package Town's east building,
/// v_package.dart, for the second): "Flutter" in
/// its six glyphs (F l u tt e r: the t t a
/// ligature) as solid letters, their faces a gradient that flows (a
/// shader), their returns brushed metal. Two turns:
///
/// * what only Flutter can do (0–8 s): the letters arrive one by one; a box
///   for each grapheme is drawn round them as Flutter's debug paint would
///   (seven boxes for six glyphs: the ligature's split in two), over the
///   alphabetic baseline; then each glyph turns on its own, a Matrix4 with
///   nothing laid out again (the baseline stays put);
/// * Slug (20–35 s), a fair comparison (slug_word.dart), flat on a navy
///   board, the same font, layout and ink both ways: first as text reaches a
///   3D scene today, rasterized once into a texture sharp from where the
///   camera starts, the camera coming in on the e until it blurs; then, at
///   the press, the same word from its outlines on the GPU (the Slug
///   algorithm, in the scene's own pass), sharp however close, and from the
///   side too.
class TalkWord extends Vignette {
  TalkWord(super.kit, {this.name = 'word', vm.Matrix4? at}) : frame = at ?? trs(vm.Vector3(0, 0, 36));

  @override
  final String name;
  @override
  String get kick => 'ONLY IN FLUTTER';
  @override
  String get line => 'a box for each grapheme';
  @override
  String get note => 'seven graphemes, six glyphs: t t is one';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 40;
  /// (The talk holds its camera within a visit: both turns.)
  @override
  double get visit => 36;

  /// Where it hangs ([at]): by default over the alley, facing the plaza.
  @override
  final vm.Matrix4 frame;

  /// Its frame's scale (the prop pool's glows are sized in the world's
  /// metres, not the frame's).
  late final double _k = vm.Vector3(frame.storage[0], frame.storage[1], frame.storage[2]).length;

  static const _word = 'Flutter';

  /// The glyphs it shapes to (their text), and each grapheme's glyph.
  static const _pieces = [(0, 1), (1, 2), (2, 3), (3, 5), (5, 6), (6, 7)];
  static const _glyphOf = [0, 1, 2, 3, 3, 4, 5];

  /// An em (m), the size it's traced at (px), the baseline's height, the
  /// letters' depth; the gradient's period (m).
  static const _em = 4.2, _px = 400.0, _base = 9.4, _depth = 0.8, _period = 15.0;

  /// Where the Slug turn's flat word stands: as far forward as the
  /// letters' faces were, its board just behind it.
  static const _faceZ = -(_depth / 2 + 0.06);
  static const _upp = _em / _px;

  /// The turns: the first held at [_hold1], gone by [_end1]; the second
  /// from [_from2], its pixels going at [_dissolve], held at [_hold2].
  static const _hold1 = 7.0, _end1 = 8.4;
  static const _from2 = 20.0, _dissolve = 28.0, _hold2 = 33.5, _end2 = 34.8;

  static TextStyle _style(double size) => TextStyle(
    fontFamily: BP.display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700)],
  );

  /// Flutter's debug paint: boxes cyan, the alphabetic baseline green.
  static final _cyan = vm.Vector4(0.3, 2.0, 2.6, 1), _green = vm.Vector4(0.2, 2.6, 0.4, 1);

  static const _hues = [Color(0xFF2F6BFF), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF2F6BFF)];

  final _glyphs = <Glyph3D>[];

  /// Each glyph's pen (x) and ink middle (its turn's axis); each
  /// grapheme's box (left, right, top, bottom).
  final _pens = <double>[], _pivots = <double>[];
  final _boxes = <(double, double, double, double)>[];
  double _width = 0;

  /// This frame's turn, bob and size of each glyph.
  final _spin = List.filled(6, 0.0), _bob = List.filled(6, 0.0);

  late final PhysicallyBasedMaterial _faceMat, _sideMat;
  final _flow = TextureTransform();

  /// The Slug turn's word, both ways, on its board.
  late final SlugWord _two;
  late final Node _flat;

  /// Where the camera comes in on the e (its bowl's lower right, on the
  /// atlas's face).
  vm.Vector3 _close = vm.Vector3(3, 10, -0.5);

  /// Which turn the talk last called (0: none yet).
  int _act = 0;
  bool _ready = false;

  @override
  List<(String, TextStyle)> get fontRuns => [(_word, _style(40))];

  @override
  Future<void> init() async {
    makePool(boxes: 2, cyls: 2, glows: 40);
    final grad = _gradient();
    _faceMat = PhysicallyBasedMaterial()
      ..baseColorTexture = grad
      ..baseColorTextureTransform = _flow
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.38
      ..emissiveTexture = grad
      ..emissiveTextureTransform = _flow
      ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
      ..emissiveStrength = 0.18;
    _sideMat = pbr(Vignette.c(0xC9D1DC), metallic: 0.85, roughness: 0.3);

    // The word laid out as Flutter lays it out: the pens, the boxes.
    final tp = TextPainter(
      text: TextSpan(text: _word, style: _style(_px)),
      textDirection: TextDirection.ltr,
    )..layout();
    _width = tp.width * _upp;
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    double wx(double px) => px * _upp - _width / 2;
    double wy(double py) => _base + (baseline - py) * _upp;
    for (final (a, _) in _pieces) {
      _pens.add(wx(tp.getOffsetForCaret(TextPosition(offset: a), Rect.zero).dx));
    }
    for (var i = 0; i < _word.length; i++) {
      final bs = tp.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1));
      final l = bs.isEmpty ? 0.0 : bs.map((b) => b.left).reduce(math.min), r = bs.isEmpty ? 0.0 : bs.map((b) => b.right).reduce(math.max);
      final top = bs.isEmpty ? 0.0 : bs.map((b) => b.top).reduce(math.min), bottom = bs.isEmpty ? 0.0 : bs.map((b) => b.bottom).reduce(math.max);
      _boxes.add((wx(l), wx(r), wy(top), wy(bottom)));
    }
    tp.dispose();

    final solids = await extrudeTextsAt([for (final (a, e) in _pieces) (_word.substring(a, e), _style(_px))], unitsPerPx: _upp, depth: _depth, simplify: 0.6);
    for (var i = 0; i < solids.length; i++) {
      final s = solids[i];
      _pivots.add(_pens[i] + s.ox);
      _glyphs.add(Glyph3D(s, _glyphNode(s.mesh, _pivots[i])));
    }
    final e = _glyphs[4];
    _close = vm.Vector3(_pivots[4] + 0.27 * e.width, _base + e.solid.oy + 0.3 * e.height, -(_depth / 2 + 0.06));
    _two = await SlugWord.build(_word, fontAsset: 'assets/fonts/SpaceGrotesk.ttf', style: const TextStyle(fontFamily: BP.display), em: _em, ink: Vignette.c(0xF2F4F8));
    final backing = Node(
      name: 'talk word board',
      mesh: Mesh(boardGeometry(_width + 1.6, 1.3 * _em, thick: 0.06), pbr(Vignette.c(0x14203A), roughness: 0.6)),
      localTransform: vm.Matrix4.translation(vm.Vector3(0, 0.27 * _em, 0.06)),
    )..castsShadows = false;
    _flat = Node(name: 'talk word flat')
      ..add(backing)
      ..add(_two.text)
      ..add(_two.slug)
      ..visible = false;
    detail.add(_flat);
    if (const String.fromEnvironment('BOOTH3D_TIMES') != '') {
      debugPrint('WORD boxes ${[for (final b in _boxes) '${b.$1.toStringAsFixed(2)}…${b.$2.toStringAsFixed(2)}'].join(' ')} · pivots ${_pivots.map((p) => p.toStringAsFixed(2)).join(' ')}');
    }
    _ready = true;
  }

  /// A glyph's node: faces in the flowing gradient (laid along the word),
  /// sides in metal.
  Node _glyphNode(GlyphMesh m, double pivot) {
    final faces = <int>[], sides = <int>[];
    for (var t = 0; t + 2 < m.indices.length; t += 3) {
      final v = m.indices[t];
      (m.normals[v * 3 + 2].abs() > 0.5 ? faces : sides).addAll([m.indices[t], m.indices[t + 1], m.indices[t + 2]]);
    }
    final uv = Float32List(m.vertexCount * 2);
    for (var v = 0; v < m.vertexCount; v++) {
      uv
        ..[v * 2] = (pivot + m.positions[v * 3]) / _period
        ..[v * 2 + 1] = 0.5;
    }
    MeshGeometry geometry(List<int> idx) => MeshGeometry.fromArrays(positions: m.positions, normals: m.normals, texCoords: uv, indices: idx);
    final n = Node(
      name: 'talk word glyph',
      mesh: Mesh.primitives(primitives: [MeshPrimitive(geometry(faces), _faceMat), MeshPrimitive(geometry(sides), _sideMat)]),
    )..visible = false;
    detail.add(n);
    return n;
  }

  /// The gradient's colour [u] periods along (it repeats).
  static Color _hueAt(double u) {
    final f = (u - u.floorToDouble()) * (_hues.length - 1);
    final i = f.floor().clamp(0, _hues.length - 2);
    return Color.lerp(_hues[i], _hues[i + 1], f - i)!;
  }

  Texture2D _gradient() {
    const w = 256, h = 4;
    final px = Uint8List(w * h * 4);
    for (var x = 0; x < w; x++) {
      final c = _hueAt(x / w);
      for (var y = 0; y < h; y++) {
        final i = (y * w + x) * 4;
        px
          ..[i] = (c.r * 255).round()
          ..[i + 1] = (c.g * 255).round()
          ..[i + 2] = (c.b * 255).round()
          ..[i + 3] = 255;
      }
    }
    return Texture2D.fromPixels(px, w, h);
  }

  // ── Posing ────────────────────────────────────────────────────────────────

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    if (visited) _act = u < 15 ? 1 : 2;
    pool.begin();
    final on = switch (_act) {
      1 => u < _end1,
      2 => u >= _from2 && u < _end2,
      _ => false,
    };
    if (!on) {
      for (final g in _glyphs) {
        g.node.visible = false;
      }
      _flat.visible = false;
    } else if (_act == 1) {
      _only(u, t);
    } else {
      _slug(u, t);
    }
    // (The shader: the gradient flows along the first turn's word.)
    _flow.offset.x = _act == 1 ? -0.035 * t : 0;
    pool.end();
  }

  /// 0 → 1, a little past 1 before it settles.
  static double _overshoot(double k) {
    if (k <= 0) return 0;
    if (k >= 1) return 1;
    const c1 = 1.70158, c3 = c1 + 1;
    final x = k - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }

  void _only(double u, double t) {
    _flat.visible = false;
    for (var i = 0; i < _glyphs.length; i++) {
      final g = _glyphs[i];
      // In one by one, rising into place; each turned round once, one after
      // another; then breathing while the presenter talks; out, one by one.
      final a = 0.25 + 0.15 * i, k = seg(u, a, a + 0.8);
      final s = _overshoot(k) * (1 - eio(seg(u, _hold1 + 0.07 * i, _hold1 + 0.07 * i + 0.45)));
      _spin[i] = 2 * math.pi * eio(seg(u, 3.7 + 0.22 * i, 3.7 + 0.22 * i + 1.2));
      _bob[i] = 0.09 * math.sin(t * 1.6 + i * 0.9) * smooth(5.2, 7.0, u);
      put(g, _pivots[i], _base + g.solid.oy + g.height / 2 - 1.4 * (1 - eo(k)) + _bob[i], 0, s: s, yaw: _spin[i]);
    }
    // A box for each grapheme, drawn on one after another, turning with its
    // glyph (the ligature's two together).
    final z = -(_depth / 2 + 0.16);
    for (var j = 0; j < _boxes.length; j++) {
      final gi = _glyphOf[j];
      final d = eo(seg(u, 2.1 + 0.13 * j, 2.7 + 0.13 * j)) * (1 - eio(seg(u, _hold1 + 0.07 * gi, _hold1 + 0.07 * gi + 0.3)));
      if (d <= 0.001) continue;
      final (l, r, top, bottom) = _boxes[j];
      _frame(l, r, top + _bob[gi], bottom + _bob[gi], z, _pivots[gi], _spin[gi], d);
    }
    // The line's baseline: it stays as the glyphs turn.
    final b = eo(seg(u, 3.0, 3.7)) * (1 - eio(seg(u, _hold1, _hold1 + 0.4)));
    if (b > 0.001) {
      final l = _boxes.first.$1 - 0.5, r = _boxes.last.$2 + 0.5;
      pglow(l + (r - l) * b / 2, _base, z - 0.03, (r - l) * b * _k, 0.05 * _k, 0.05 * _k, _green);
    }
  }

  /// A box's four sides drawn on ([d] 0…1), [z] in front of the letters,
  /// turned [yaw] round x = [p] as its glyph is (put's turn).
  void _frame(double l, double r, double top, double bottom, double z, double p, double yaw, double d) {
    final cs = math.cos(yaw), sn = math.sin(yaw);
    (double, double) turned(double x) => (p + (x - p) * cs + z * sn, -(x - p) * sn + z * cs);
    const th = 0.055;
    final w = r - l, h = top - bottom;
    // The sides, up from the bottom; the bottom and top, across from the left.
    for (final x in [l, r]) {
      final (tx, tz) = turned(x);
      pglow(tx, bottom + h * d / 2, tz, th * _k, h * d * _k, th * _k, _cyan, yaw: yaw);
    }
    final (mx, mz) = turned(l + w * d / 2);
    for (final y in [bottom, top]) {
      pglow(mx, y, mz, w * d * _k, th * _k, th * _k, _cyan, yaw: yaw);
    }
  }

  void _slug(double u, double t) {
    for (final g in _glyphs) {
      g.node.visible = false;
    }
    // The board and its word: in; out at the hold's end.
    final b = _overshoot(seg(u, _from2 + 0.15, _from2 + 0.85)) * (1 - eio(seg(u, _hold2, _hold2 + 0.5)));
    _flat.visible = b > 0.001;
    if (!_flat.visible) return;
    _flat.localTransform = place(trs(vm.Vector3(0, _base, _faceZ), s: vm.Vector3.all(b)));
    // The texture's word while the camera comes in on it (the e blurring);
    // at the press, the outlines' word in its place, the camera still close.
    final k = eio(seg(u, _dissolve, _dissolve + 0.6));
    _two
      ..textAlpha = 1 - k
      ..slugAlpha = k;
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    if (u < 15) {
      // Low on the cross path, looking up at the word against the sky.
      return Shot(vm.Vector3(-4.5, 3.4, -15.5), vm.Vector3(-0.5, 10.2, 0), fov: 52, settle: 1.0, drift: 0.5);
    }
    // Wide on the texture's word; in on the e until it blurs; once the
    // outlines' word is in its place, round to its side.
    final e = _close;
    final k = eio(seg(u, _from2 + 1.4, _dissolve)), o = eio(seg(u, _dissolve + 1.6, _hold2 - 0.3));
    vm.Vector3 path(vm.Vector3 wide, vm.Vector3 near, vm.Vector3 round) => wide + (near - wide) * k + (round - near) * o;
    return Shot(
      path(vm.Vector3(-2.5, 5.0, -20.0), e + vm.Vector3(-0.2, -0.15, -1.4), e + vm.Vector3(2.2, 0.45, -3.8)),
      path(vm.Vector3(-0.6, 10.6, 0), e, e + vm.Vector3(0.05, 0.35, 0.3)),
      fov: 46 + (32 - 46) * k + (40 - 32) * o,
      settle: 0.6,
      drift: 0.25,
    );
  }
}
