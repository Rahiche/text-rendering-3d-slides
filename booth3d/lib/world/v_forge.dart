import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart';
import 'shapes.dart' show roundedSlab;
import 'shot.dart';
import 'vignette.dart';

/// 合字工房 · Shaping, in the park past the alley (on the right of the long
/// path, across from the tofu shop): a forge where code points go in and
/// glyphs come out. Each job rides the belt into the furnace, comes out
/// red-hot onto the anvil, and the power press comes down on it twice:
/// what a shaper (HarfBuzz) makes of the run is what's left — Arabic
/// letters joined into a word, f + i into ﬁ, a code font's - + > into its
/// arrow, A and V kerned closer, Devanagari's vowel sign swapped in front
/// of its consonant, five code points of an emoji sequence into one
/// glyph — then it cools on the rack. In the narration's order and time
/// (01 shaping): each job's last blow as its sentence says it.
class LigatureForge extends Vignette {
  LigatureForge(super.kit);

  @override
  String get name => 'forge';
  @override
  String get kick => 'SHAPING';
  @override
  String get line => 'كتاب · ﬁ · -> · AV · कि · 🏃🏽‍♀️';
  @override
  String get note => 'code points in, glyphs out: joined, merged, kerned, reordered';

  @override
  double get loop => 42;
  @override
  double get visit => 16;

  @override
  final frame = trs(vm.Vector3(6.4, 0, 46.8), rotY: math.pi / 2);

  /// The jobs: what goes in (left to right as it's laid out), what comes
  /// out, when the press's last blow makes it.
  static const _jobs = [
    _Job(['ب', 'ا', 'ت', 'ك'], 'كتاب', 8.6),
    _Job(['f', 'i'], 'ﬁ', 14.0),
    _Job(['-', '>'], '->', 19.0, code: true),
    _Job(['A', 'V'], 'AV', 22.8),
    _Job(['क', 'ि'], 'कि', 27.8, reorder: true),
    _Job(['🏃', '🏽', 'ZWJ', '♀', 'FE0F'], '🏃🏽‍♀️', 33.4, emoji: true),
  ];

  /// "This forge is where letters go in, and glyphs come out": the rack
  /// glows.
  static const _outro = 36.5;

  // The forge's parts (its frame): the belt's start, the furnace's mouth,
  // the belt's top; the press's bed (its middle, its top); the rack's
  // shelves.
  static const _beltX0 = -3.4, _mouthX = -1.05, _beltY = 0.86, _beltZ = -0.62;
  static const _ax = 0.55, _bed = 1.02, _az = -0.35;
  static const _rackX0 = 1.62, _rackX1 = 2.98, _shelves = [1.34, 0.84], _rackZ = 0.12;

  static const _style = TextStyle(fontFamily: BP.display, fontFamilyFallback: [BP.arabic], fontSize: 160, fontWeight: FontWeight.w700);
  static const _codeStyle = TextStyle(fontFamily: BP.mono, fontSize: 160, fontVariations: [FontVariation('wght', 700)]);
  static const _unit = 0.3 / 160;

  @override
  List<(String, TextStyle)> get fontRuns => [
    ('كتاب ب ا ت ك ﬁ f i A V AV क ि कि SHAPING FORGE', _style),
    ('- > ->', _codeStyle),
    ('🏃 🏽 ♀ 🏃🏽‍♀️', const TextStyle()),
  ];

  /// Each job's pieces and its result, as shown.
  final _in = <List<_Part>>[];
  final _out = <_Part>[];

  /// Where each result stands on the rack (its left, its shelf).
  final _slots = <(double, double)>[];

  late final Node _ram, _wheel;
  late final PhysicallyBasedMaterial _fireMat;
  final _m = vm.Matrix4.identity();
  bool _ready = false;

  @override
  Future<void> init() async {
    makePool(boxes: 24, glows: 12);
    final b = Batch();
    final m = pbr(rgb(1, 1, 1), roughness: 0.8);
    final steel = pbr(rgb(1, 1, 1), roughness: 0.4, metallic: 0.75);
    final brick = Vignette.c(0x8C4B3A), soot = Vignette.c(0x2A2626), iron = Vignette.c(0x3C4048), wood = Vignette.c(0x8A6440);
    // The furnace: brick, a dark mouth, a chimney.
    box(b, m, 1.4, 1.9, 1.3, -1.75, 0.95, 0.35, brick);
    box(b, m, 0.62, 0.5, 0.06, _mouthX - 0.65, 0.88, -0.33, soot);
    box(b, m, 0.5, 1.6, 0.5, -1.9, 2.6, 0.55, brick);
    // The belt on its legs, running into the mouth.
    box(b, m, _mouthX - _beltX0, 0.08, 0.5, (_beltX0 + _mouthX) / 2 - 0.35, _beltY - 0.06, _beltZ, iron);
    for (final x in [_beltX0 + 0.1, _mouthX - 0.8]) {
      box(b, m, 0.07, _beltY - 0.1, 0.07, x, (_beltY - 0.1) / 2, _beltZ - 0.2, iron);
      box(b, m, 0.07, _beltY - 0.1, 0.07, x, (_beltY - 0.1) / 2, _beltZ + 0.2, iron);
    }
    // The power press: its bed (a dark plate on top, what's pressed lies
    // on it), two columns, a crosshead, the flywheel's bearing.
    box(b, steel, 1.5, _bed - 0.04, 0.62, _ax, (_bed - 0.04) / 2, _az + 0.05, Vignette.c(0x2F5B8C));
    box(b, steel, 1.5, 0.04, 0.62, _ax, _bed - 0.02, _az + 0.05, Vignette.c(0x1E2125));
    for (final x in [_ax - 0.83, _ax + 0.83]) {
      box(b, steel, 0.16, 2.3, 0.2, x, 1.15, _az + 0.12, Vignette.c(0x2F5B8C));
    }
    box(b, steel, 1.86, 0.28, 0.36, _ax, 2.3, _az + 0.12, Vignette.c(0x2F5B8C));
    box(b, steel, 0.3, 0.14, 0.2, _ax + 1.05, 2.3, _az + 0.12, Vignette.c(0x2A2E35));
    // The rack: two shelves on their posts; a quench tub.
    for (final y in _shelves) {
      box(b, m, _rackX1 - _rackX0 + 0.14, 0.06, 0.4, (_rackX0 + _rackX1) / 2, y - 0.03, _rackZ + 0.03, wood);
    }
    for (final x in [_rackX0 - 0.04, _rackX1 + 0.04]) {
      box(b, m, 0.06, 1.6, 0.06, x, 0.8, _rackZ + 0.2, wood);
    }
    cylinder(b, m, 0.3, 0.42, -0.45, 0.21, 0.95, Vignette.c(0x5A6470));
    // (No roof: what's made is in the sun.)
    b.buildInto(detail, 'forge', castsShadows: false, lightChannelMask: 0x01);

    // The fire in the mouth.
    _fireMat = pbr(rgb(1, 0.5, 0.1), roughness: 0.9, emissive: rgb(1, 0.45, 0.12), emissiveStrength: 3);
    detail.add(
      Node(
        name: 'forge fire',
        mesh: Mesh(CuboidGeometry(vm.Vector3(0.5, 0.36, 0.04)), _fireMat),
        localTransform: place(trs(vm.Vector3(_mouthX - 0.65, 0.84, -0.36))),
      )..castsShadows = false,
    );
    // The ram (its middle at its origin; its rod up into the crosshead),
    // and the flywheel (spokes, a weight on its rim to see it turn).
    _ram = Node(
      name: 'forge ram',
      mesh: Mesh(
        merged([
          part(CuboidGeometry(vm.Vector3(0.36, 0.4, 0.34)), vm.Matrix4.identity(), Vignette.c(0x3A3F48)),
          part(CuboidGeometry(vm.Vector3(0.4, 0.06, 0.36)), vm.Matrix4.translation(vm.Vector3(0, -0.21, 0)), Vignette.c(0x1E2125)),
          part(CuboidGeometry(vm.Vector3(0.38, 0.05, 0.35)), vm.Matrix4.translation(vm.Vector3(0, 0.12, 0)), Vignette.c(0xE0B13A)),
          part(CylinderGeometry(bottomRadius: 0.045, topRadius: 0.045, height: 0.6, radialSegments: 12), vm.Matrix4.translation(vm.Vector3(0, 0.5, 0)), Vignette.c(0xB8BEC6)),
        ]),
        steel,
      ),
    )..castsShadows = false;
    detail.add(_ram);
    _wheel = Node(
      name: 'forge flywheel',
      mesh: Mesh(
        merged([
          part(CylinderGeometry(bottomRadius: 0.34, topRadius: 0.34, height: 0.07, radialSegments: 28), trs(vm.Vector3.zero(), rotX: math.pi / 2), Vignette.c(0x2A2E35)),
          for (var k = 0; k < 4; k++)
            part(CuboidGeometry(vm.Vector3(0.62, 0.05, 0.09)), trs(vm.Vector3.zero(), rotZ: k * math.pi / 4), Vignette.c(0x5A6470)),
          part(CuboidGeometry(vm.Vector3(0.1, 0.12, 0.1)), vm.Matrix4.translation(vm.Vector3(0, 0.28, 0)), Vignette.c(0xE0B13A)),
        ]),
        steel,
      ),
    )..castsShadows = false;
    detail.add(_wheel);

    // What goes in and what comes out: text extruded (each its own
    // material: it heats and cools), emoji on tiles.
    final texts = <(String, TextStyle)>[];
    for (final j in _jobs) {
      if (j.emoji) continue;
      for (final s in [...j.pieces, j.result]) {
        texts.add((s, j.code ? _codeStyle : _style));
      }
    }
    final solids = await extrudeTextsAt(texts, unitsPerPx: _unit, depth: 0.08);
    var next = 0;
    _Part glyph() {
      final s = solids[next++];
      final mat = pbr(Vignette.c(0xD9B45A), roughness: 0.32, metallic: 0.65, emissive: rgb(1, 0.42, 0.1), emissiveStrength: 0);
      final n = Node(name: 'forge glyph', mesh: Mesh(glyphGeometry(s.mesh), mat))
        ..castsShadows = false
        ..visible = false;
      detail.add(n);
      return _Part.glyph(Glyph3D(s, n), mat);
    }

    for (final j in _jobs) {
      if (j.emoji) {
        final parts = <_Part>[];
        for (final p in j.pieces) {
          parts.add(await _tile(p, 0.17));
        }
        _in.add(parts);
        _out.add(await _tile(j.result, 0.36));
      } else {
        _in.add([for (var i = 0; i < j.pieces.length; i++) glyph()]);
        _out.add(glyph());
      }
    }
    // The rack's slots: the first three on the top shelf, the rest below.
    for (final shelf in [0, 1]) {
      var x = _rackX0 + 0.05;
      for (var k = 3 * shelf; k < 3 * shelf + 3; k++) {
        _slots.add((x, _shelves[shelf] - _out[k].bottom));
        x += _out[k].w + 0.1;
      }
    }

    // The forge's name on the front of the press's bed.
    await sign(1.36, 0.34, vm.Matrix4.translation(vm.Vector3(_ax, 0.62, _az + 0.05 - 0.32)), (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2B2422));
      Vignette.text(c, 'SHAPING FORGE', Rect.fromLTWH(0, 0, s.width, s.height * 0.62), s.height * 0.4, const Color(0xFFF2C94C));
      Vignette.text(c, 'code points in · glyphs out', Rect.fromLTWH(0, s.height * 0.6, s.width, s.height * 0.36), s.height * 0.22, const Color(0xFFF4EBD8), family: BP.mono);
    });
    _ready = true;
  }

  /// An emoji tile [size] across: the emoji on its face (an invisible code
  /// point's name instead, on blue: ZWJ, FE0F).
  Future<_Part> _tile(String s, double size) async {
    final named = s == 'ZWJ' || s == 'FE0F';
    final tex = await paintedTexture(256, 256, (c, sz) {
      c.drawRect(Offset.zero & sz, Paint()..color = named ? const Color(0xFF0E3B4D) : const Color(0xFFF6F3EC));
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: named
              ? const TextStyle(fontFamily: BP.mono, fontSize: 64, fontWeight: FontWeight.w700, color: Color(0xFFDDF8FF))
              : const TextStyle(fontSize: 170, color: Color(0xFF1E2125)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((sz.width - tp.width) / 2, (sz.height - tp.height) / 2));
      tp.dispose();
    });
    final slab = pbr(named ? Vignette.c(0x1B6E8A) : Vignette.c(0xF6F3EC), roughness: 0.45, emissive: rgb(1, 0.42, 0.1), emissiveStrength: 0);
    final face = PhysicallyBasedMaterial()
      ..baseColorTexture = tex
      ..roughnessFactor = 0.55
      ..emissiveTexture = tex
      ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
      ..emissiveStrength = 0.3;
    final n = Node(name: 'forge tile', mesh: Mesh(MeshGeometry.fromMeshData(roundedSlab(size, size, 0.05, corner: 0.03, edge: 0.01, cornerSteps: 2, edgeSteps: 1)), slab))
      ..castsShadows = false
      ..visible = false;
    n.add(
      Node(
        name: 'forge tile face',
        mesh: Mesh(boardGeometry(size * 0.86, size * 0.86, thick: 0.004), face),
        localTransform: vm.Matrix4.translation(vm.Vector3(0, 0, -0.029)),
      )..castsShadows = false,
    );
    detail.add(n);
    return _Part.tile(n, slab, size);
  }

  // ── Posing ────────────────────────────────────────────────────────────────

  /// Shows [p] with its left at [x], standing on [base] (raised [lift]),
  /// at [z], [heat] 0 cold … 1 red-hot.
  void _show(_Part p, double x, double base, double z, double heat, {double lift = 0}) {
    if (p.glyph case final g?) {
      pen(g, x, base + lift, z);
      p.mat
        ..emissiveStrength = 3.2 * heat
        ..baseColorFactor = vm.Vector4(lerp(0.72, 1, heat), lerp(0.45, 0.3, heat), lerp(0.1, 0.06, heat), 1);
    } else {
      final n = p.tile!;
      n.visible = true;
      _m.setFromTranslationRotationScale(vm.Vector3(x + p.w / 2, base + p.w / 2 + lift, z), vm.Quaternion.identity(), vm.Vector3.all(1));
      n.localTransform = frame * _m;
      p.mat.emissiveStrength = 2.4 * heat;
    }
  }

  void _hide(_Part p) => p.glyph != null ? p.glyph!.node.visible = false : p.tile!.visible = false;

  /// [parts] laid out left to right from [x], [gap] apart: each one's left.
  static List<double> _row(List<_Part> parts, double x, double gap) {
    final out = <double>[];
    for (final p in parts) {
      out.add(x);
      x += p.w + gap;
    }
    return out;
  }

  static double _width(List<_Part> parts, double gap) => parts.fold(0.0, (a, p) => a + p.w) + gap * (parts.length - 1);

  /// The tallest of [parts] over its baseline; the lowest (under it: < 0).
  static double _top(List<_Part> parts) => parts.fold(0.0, (a, p) => math.max(a, p.top));
  static double _bottom(List<_Part> parts) => parts.fold(0.0, (a, p) => math.min(a, p.bottom));

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    pool.begin();
    // The belt's slats, moving.
    for (var i = 0; i < 9; i++) {
      final x = _beltX0 + ((i * 0.3 + t * 0.9) % 2.7) - 0.35;
      if (x < _mouthX - 0.5) pbox(x, _beltY - 0.01, _beltZ, 0.05, 0.02, 0.46, Vignette.c(0x22252B));
    }
    // Smoke from the chimney.
    for (var n = 0; n < 3; n++) {
      final age = ((t * 0.35 + n / 3) % 1);
      final w = world(-1.9, 3.5, 0.55);
      kit.fx.puff(w.x, w.y, w.z, age, 0.35, seed: n + 40, n: 2);
    }
    // The flywheel turns.
    _wheel.localTransform = frame * trs(vm.Vector3(_ax + 1.25, 2.3, _az - 0.02), rotZ: -t * 3.2);

    var inFire = 0.0, ramDrop = 0.0, ramTop = _bed + 0.3;
    for (var k = 0; k < _jobs.length; k++) {
      final j = _jobs[k], h = j.hit, ins = _in[k], res = _out[k];
      for (final p in ins) {
        _hide(p);
      }
      _hide(res);
      final c = u - h;
      if (c < -3.6) continue;
      inFire = math.max(inFire, smooth(-2.2, -2.0, c) * (1 - smooth(-1.6, -1.4, c)));
      if (c < -2.0) {
        // Along the belt into the mouth (cold, warming as it goes in).
        const gap = 0.07;
        final f = seg(c, -3.6, -2.0);
        final w = _width(ins, gap);
        final x0 = lerp(_beltX0 + 0.2, _mouthX - 0.35 - w, f);
        final xs = _row(ins, x0, gap);
        for (var i = 0; i < ins.length; i++) {
          // (Into the furnace: gone once past its mouth.)
          if (xs[i] + ins[i].w > _mouthX - 0.3) continue;
          _show(ins[i], xs[i], _beltY + 0.03 - _bottom(ins), _beltZ, 0.6 * f * f);
        }
      } else if (c < -1.5) {
        // In the fire.
      } else if (c < 0) {
        // Out onto the anvil, red-hot; pressed at each blow, the gaps
        // closing (the vowel sign hopping over to the front).
        final f = eio(seg(c, -1.5, -1.1));
        final gap = lerp(0.07, 0.035, smooth(-0.6, -0.5, c));
        final w = _width(ins, gap);
        final xs = _row(ins, _ax - w / 2, gap);
        final base = _bed - _bottom(ins);
        final dx = lerp(_mouthX - 0.4 - (_ax - w / 2), 0, f), dy = lerp(_beltY + 0.03 - _bed, 0, f), dz = lerp(_beltZ - _az, 0, f);
        if (j.reorder) {
          // क slides right, ि goes over it to the left.
          final e = eio(seg(c, -0.5, -0.05));
          final first = ins[0], mark = ins[1];
          _show(first, xs[0] + dx + e * (mark.w + gap), base + dy, _az + dz, 1);
          _show(mark, lerp(xs[1], xs[0], e) + dx, base + dy, _az + dz, 1, lift: 0.32 * math.sin(math.pi * e));
        } else {
          for (var i = 0; i < ins.length; i++) {
            _show(ins[i], xs[i] + dx, base + dy, _az + dz, 1);
          }
        }
        ramTop = base + _top(ins);
      } else if (c < 2.2) {
        // One glyph: on the anvil, cooling; then up onto the rack.
        final f = eio(seg(c, 1.4, 2.2));
        final (sx, sy) = _slots[k];
        final heat = 1 - 0.7 * seg(c, 0, 2.2);
        _show(res, lerp(_ax - res.w / 2, sx, f), lerp(_bed - res.bottom, sy, f), lerp(_az, _rackZ, f), heat, lift: 0.35 * math.sin(math.pi * f));
        ramTop = _bed - res.bottom + res.top;
      } else {
        // On the rack, cold (aglow as the narration sums up).
        final (sx, sy) = _slots[k];
        final glow = 0.35 * smooth(_outro, _outro + 0.4, u) * (1 - smooth(_outro + 2.2, _outro + 3.0, u));
        _show(res, sx, sy, _rackZ, math.max(glow, 0.3 * (1 - seg(c, 2.2, 4.0))));
      }
      // The press's two blows: down fast, a moment, up slower.
      for (final at in [-0.55, 0.0]) {
        final a = c - at;
        if (a > -0.16 && a < 0.5) {
          ramDrop = math.max(ramDrop, a < 0 ? math.pow((a + 0.16) / 0.16, 2).toDouble() : (a < 0.06 ? 1 : 1 - eio(seg(a, 0.06, 0.5))));
        }
        if (a >= 0 && a < 0.7) _blow(a, k);
      }
    }
    // The fire breathes; brighter while a job's in it.
    _fireMat.emissiveStrength = 2.4 + 0.6 * math.sin(t * 7) + 0.4 * math.sin(t * 13.1) + 3 * inFire;
    // The ram (its face 0.24 under its middle): up over the bed, down
    // onto what's on it.
    final rest = _bed + 1.03, hit = ramTop + 0.245;
    _ram.localTransform = frame * vm.Matrix4.translation(vm.Vector3(_ax, lerp(rest, hit, ramDrop), _az));
    pool.end();
  }

  /// Sparks and a flash [age] seconds after a blow on job [k].
  void _blow(double age, int k) {
    final w = world(_ax, _bed + 0.12, _az - 0.1);
    for (var s = 0; s < 16; s++) {
      final ang = rnd(s, k, 3) * math.pi * 2, up = 1.2 + 2.2 * rnd(s, k, 4), out = 0.8 + 1.6 * rnd(s, k, 5);
      final px = w.x + math.cos(ang) * out * age, pz = w.z + math.sin(ang) * out * age, py = w.y + up * age - 4.9 * age * age;
      kit.fx.spark(px, py, pz, 0.02 * (1 - age / 0.7), vm.Vector4(1, 0.55, 0.15, 1), 7, math.cos(ang) * out, up - 9.8 * age, math.sin(ang) * out);
    }
    if (age < 0.15) kit.fx.flashes.add((w.clone(), vm.Vector4(1, 0.5, 0.15, 1), 1 - age / 0.15));
  }

  // ── The camera ────────────────────────────────────────────────────────────

  /// From the path: the press's bed and the rack beside it (the belt
  /// coming in from the left); edging in.
  @override
  Shot shot(double u) {
    final k = smooth(0, 40, u);
    return Shot(vm.Vector3(1.4, 1.74, lerp(-4.2, -3.95, k)), vm.Vector3(1.5, 1.28, -0.1), fov: 46, settle: 1.0, drift: 0.3);
  }
}

/// A job for the forge: [pieces] in, [result] out, the last blow at [hit].
class _Job {
  const _Job(this.pieces, this.result, this.hit, {this.code = false, this.reorder = false, this.emoji = false});
  final List<String> pieces;
  final String result;
  final double hit;

  /// In a code font (its ligatures); a mark that's drawn before what it
  /// follows; emoji (on tiles).
  final bool code, reorder, emoji;
}

/// One thing shown: an extruded glyph, or a tile; its material (it heats).
class _Part {
  _Part.glyph(Glyph3D this.glyph, this.mat) : tile = null, w = glyph.solid.advance, bottom = glyph.solid.oy, top = glyph.solid.oy + glyph.height;
  _Part.tile(Node this.tile, this.mat, this.w) : glyph = null, bottom = 0, top = w;
  final Glyph3D? glyph;
  final Node? tile;
  final PhysicallyBasedMaterial mat;

  /// Its room along a row (its advance); its ink's bottom and top over
  /// its baseline.
  final double w, bottom, top;
}
