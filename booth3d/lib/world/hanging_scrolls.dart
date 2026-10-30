import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_scene/gpu.dart' as gpu show SamplerAddressMode;
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'ease.dart';
import 'kit.dart' show lin, pbr;
import 'shapes.dart' show geometryOf;

/// Glyphs in their vertical forms (the font's 'vert' feature).
const _vertical = [FontFeature.enable('vert')];

/// 掛け軸 · Hanging scrolls of vertical writing on a washing line (the
/// talk's vertical text stop, v_scrolls.dart; and the lab it was tried in,
/// lib/lab/scroll_lab.dart): each rolled up at first, unrolling from the
/// top, right to left as the writing reads, then moving in the wind like
/// the washing. Their paper's unrolled on the GPU (assets/scrolls/
/// scroll.fmat: a spiral round the roller, the face inside, a layer of the
/// paper's thickness a turn, the normals from the same sum); the roll's
/// ends show its spiral (roll_end.fmat).
///
/// Their writing is text to select (picked through the paper as the
/// shader shapes it: the same sum on the CPU, [ScrollShape.paperPoint]),
/// and the middle one's written in: typing goes down its column in ink
/// laid on the paper (scroll_ink.fmat), the scroll unrolling further as it
/// grows. The pointer, the keys and the text menu are scroll_typing.dart's.
class HangingScrolls {
  /// Hung under [parent]: [at] a point of the line's frame (x along the
  /// line, y up, z out of the faces) in the world, the faces turned [yaw],
  /// the line [lineY] high at x, the scrolls [spacing] apart.
  HangingScrolls({required this.parent, required this.at, required this.yaw, required this.lineY, this.spacing = 1.3});

  final Node parent;
  final vm.Vector3 Function(double x, double y, double z) at;
  final double yaw, spacing;
  final double Function(double x) lineY;

  /// What hangs on the line, right to left as it's seen (the way the
  /// writing reads), and unrolled in that order: the work, the mounting's
  /// colours. The middle one ([editable]) is written in.
  static const works = [
    ('縦書き', Color(0xFF2E4A6B), Color(0xFF1D2F45)),
    ('春はあけぼの', Color(0xFF6E5A3A), Color(0xFF473922)),
    ('一期一会', Color(0xFF4F6B4A), Color(0xFF33462F)),
    ('花鳥風月', Color(0xFF7A3E3A), Color(0xFF512824)),
    ('ありがとう', Color(0xFF5B5470), Color(0xFF3B3649)),
  ];
  static const editable = 2;

  /// Where along the line scroll [i] hangs.
  double xOf(int i) => (i - (works.length - 1) / 2) * spacing;

  /// A timing run's log of the faces' repaints (the lab's), if any.
  static void Function(String)? log;

  final _scrolls = <_Scroll>[];
  bool get ready => _scrolls.length == works.length;

  Future<void> init() async {
    final material = await Future.wait([for (var i = 0; i < works.length; i++) loadFmatMaterial('assets/scrolls/scroll.fmat')]);
    final ends = await Future.wait([for (var i = 0; i < works.length; i++) loadFmatMaterial('assets/scrolls/roll_end.fmat')]);
    final wood = pbr(lin(const Color(0xFF6B4A2E)), roughness: 0.55);
    final knob = pbr(lin(const Color(0xFF2A1C14)), roughness: 0.35);
    final peg = pbr(lin(const Color(0xFFC9A877)), roughness: 0.7);
    for (var i = 0; i < works.length; i++) {
      final (text, silk, band) = works[i];
      final x = xOf(i);
      final s = _Scroll(i, x, lineY(x), text, silk: silk, band: band, material: material[i], ends: ends[i], wood: wood, knob: knob, peg: peg, yaw: yaw, world: at);
      await s.paint();
      if (s.editable) s.ink = await _Ink.make(parent, s.shape.origin, s.writing, s.length);
      _scrolls.add(s);
      s.addTo(parent);
    }
  }

  /// All rolled up again (to unroll from [t] 0 on).
  void reset() {
    for (final s in _scrolls) {
      s.reset();
    }
  }

  /// The wind along the line at [x], [t]: a slow swell with gusts on it,
  /// travelling along at 4 m/s; 0 still, ~1 a breeze, ~1.8 a gust.
  static double wind(double t, double x) {
    final u = t - (x + 4) / 4;
    return 0.95 + 0.42 * math.sin(0.21 * u) + 0.26 * math.sin(0.53 * u + 1.1) + 0.14 * math.sin(1.37 * u + 0.4) + 0.06 * math.sin(2.9 * u + 2.0);
  }

  /// [t] seconds in, [dt] since the last; unrolled [unrolled] seconds in
  /// (the first from 1.2 s, each the next 0.7 s after; [t] if not said: a
  /// talk's scene holds its unroll while the wind blows on); [calm]: no
  /// wind.
  void update(double t, double dt, {double? unrolled, bool calm = false}) {
    _clock += dt;
    // (A caret blinks, half a second on, half off; solid as it moves.)
    final blink = (_clock - _blinkFrom) % 1.06 < 0.53 ? 1.0 : 0.0;
    for (final s in _scrolls) {
      s.update(t, dt, calm ? 0.0 : wind(t, s.x), unrolled: unrolled ?? t);
      final mine = s.index == _sel, writing = mine && s.index == editable && editorFocused;
      s.show(mine ? _anchor : null, _focusAt, caret: writing ? blink : 0, composing: writing ? _composing : null);
    }
  }

  /// Scroll [i]'s roller (world), and how far it hangs (m).
  vm.Vector3 rollerOf(int i) => _scrolls[i].shape.rollerCentre();
  double hungOf(int i) => _scrolls[i].shape.s;

  // ── Selecting the writing ───────────────────────────────────────────────

  /// The scroll whose writing is selected (null: none), and the selection's
  /// ends as caret positions in it (0 before its first character, its
  /// length after its last); equal, a caret (shown, blinking from
  /// [_blinkFrom], while the middle one's written in).
  int? _sel;
  int _anchor = 0, _focusAt = 0;
  double _clock = 0, _blinkFrom = 0;

  bool get hasSelection => _sel != null;

  /// What's selected (nothing for a caret).
  String get selectedText {
    final i = _sel;
    if (i == null) return '';
    return _scrolls[i].writing.chars.sublist(math.min(_anchor, _focusAt), math.max(_anchor, _focusAt)).join();
  }

  /// The nearest scroll's face under canvas point [p] ([size]: the canvas's,
  /// as [camera] shows it): which scroll, and where on its face (UV0).
  (int, Offset)? _pick(Offset p, Size size, Camera camera) {
    if (!ready) return null;
    final ray = camera.screenPointToRay(p, size);
    (int, Offset)? best;
    var near = double.infinity;
    for (final s in _scrolls) {
      final h = s.hit(ray);
      if (h != null && h.$1 < near) {
        near = h.$1;
        best = (s.index, h.$2);
      }
    }
    return best;
  }

  /// [p] over a scroll's writing (its work's paper; anywhere on the middle
  /// one's face, to write in): which scroll, and where on its face.
  (int, Offset)? _onWriting(Offset p, Size size, Camera camera) {
    final h = _pick(p, size, camera);
    return h != null && (h.$1 == editable || _scrolls[h.$1].writing.paper.contains(h.$2)) ? h : null;
  }

  bool overText(Offset p, Size size, Camera camera) => _onWriting(p, size, camera) != null;

  /// A press at [p]: the caret where it lands in the writing; off it, no
  /// selection.
  void selectFrom(Offset p, Size size, Camera camera) {
    final h = _onWriting(p, size, camera);
    if (h == null) {
      _sel = null;
      return;
    }
    _sel = h.$1;
    _anchor = _focusAt = _scrolls[h.$1].writing.caretAt(h.$2);
    _blinkFrom = _clock;
  }

  /// Dragged on to [p] (or a shift-press there): the selection's far end
  /// follows it, down or up a column and across to the next, on the same
  /// scroll.
  void selectTo(Offset p, Size size, Camera camera) {
    final i = _sel;
    if (i == null) return selectFrom(p, size, camera);
    final h = _pick(p, size, camera);
    if (h == null || h.$1 != i) return;
    _focusAt = _scrolls[i].writing.caretAt(h.$2);
    _blinkFrom = _clock;
  }

  /// All of the writing of the scroll under [p] (a double-click).
  void selectAllAt(Offset p, Size size, Camera camera) {
    final h = _onWriting(p, size, camera);
    if (h == null) return;
    _sel = h.$1;
    selectAll();
  }

  /// All of the selected scroll's writing.
  void selectAll() {
    final i = _sel;
    if (i == null) return;
    _anchor = 0;
    _focusAt = _scrolls[i].writing.chars.length;
  }

  void clearSelection() => _sel = null;

  /// Whether [p] is on the writing that's selected (a right-click there
  /// keeps it).
  bool inSelection(Offset p, Size size, Camera camera) {
    final h = _pick(p, size, camera), i = _sel;
    if (h == null || i == null || h.$1 != i || _anchor == _focusAt) return false;
    final w = _scrolls[i].writing, a = math.min(_anchor, _focusAt), b = math.max(_anchor, _focusAt);
    return w.boxes(a, b).any((r) => r.contains(h.$2));
  }

  // ── Writing in the middle one ───────────────────────────────────────────

  /// Its editor has the keys (scroll_typing.dart's): the caret and what's
  /// being composed are shown then, and whoever else listens to the keys
  /// leaves them be.
  bool editorFocused = false;

  /// What the input method's composing (caret positions), if anything.
  (int, int)? _composing;

  /// The selection's on the middle scroll: its editor's to have.
  bool get editing => _sel == editable;

  String get editableText => ready ? _scrolls[editable].writing.text : works[editable].$1;

  /// The selection as the editor counts (UTF-16).
  TextSelection get editorSelection {
    final w = _scrolls[editable].writing;
    return TextSelection(baseOffset: w.utf16At(_anchor), extentOffset: w.utf16At(_focusAt));
  }

  /// The editor's text, selection and composing, onto the middle scroll
  /// (laid out again, and unrolling to fit, when the text's changed).
  void edited(TextEditingValue v) {
    if (!ready) return;
    final s = _scrolls[editable];
    if (v.text != s.writing.text) s.retext(v.text);
    final w = s.writing;
    _sel = editable;
    _anchor = w.graphemeAt(v.selection.baseOffset);
    _focusAt = w.graphemeAt(v.selection.extentOffset);
    _composing = v.composing.isValid && !v.composing.isCollapsed ? (w.graphemeAt(v.composing.start), w.graphemeAt(v.composing.end)) : null;
    _blinkFrom = _clock;
  }

  /// Whether [text] fits the middle scroll: two columns at most.
  static bool fits(String text) => _Writing.columnsOf(text.characters.toList(), _Scroll.perColumn) <= _Scroll.maxColumns;

  /// The caret (the selection's moving end) to the next column ([next] +1,
  /// the one to the left) or the one before, as far down it.
  TextSelection columnMove(int next) {
    final w = _scrolls[editable].writing;
    return TextSelection.collapsed(offset: w.utf16At(w.columnMove(_focusAt, next)));
  }

  /// Where the middle scroll's caret is on the screen (canvas px).
  Offset? caretOnScreen(Size size, Camera camera) {
    if (!ready) return null;
    final s = _scrolls[editable];
    final (v, _, u1) = s.writing.caretBar(_focusAt);
    return camera.worldToScreen(s.facePoint(Offset(u1, v)), size);
  }
}

/// A scroll's writing as it's laid out on its face (UV0): its characters (a
/// newline among them ends a column), each one's cell, each caret position
/// (before each character, and after the last: its column, how far down),
/// the columns, right to left; the work's paper, and where the mounting's
/// foot band begins (metres down the scroll).
class _Writing {
  _Writing._(this.text, this.chars, this.cells, this.carets, this.columns, this.paper, this.foot, this.size, this.utf16);

  final String text;
  final List<String> chars;

  /// Each character's cell (a newline's: empty).
  final List<Rect> cells;
  final List<(int, double)> carets;

  /// Each column's left and right (UV0).
  final List<(double, double)> columns;
  final Rect paper;

  /// Metres: where the foot band begins, and a character's size.
  final double foot, size;

  /// Where each character begins in the text as an editor counts it
  /// (UTF-16), and then its length.
  final List<int> utf16;

  /// The work's paper's top (m): under the top band and its gold strip.
  static const _top = 0.345, _halfPaper = 0.165;

  /// The written-in scroll's: a character every [_step] m, the columns
  /// [_pitch] apart, [_pad] above and below the writing.
  static const _step = 0.15, _pitch = 0.155, _pad = 0.06;

  /// Each character's column and row, [per] to a column at most (a newline
  /// ends one), and how many columns (an empty one after a last newline
  /// counted) and rows (the longest column's).
  static (List<int>, List<int>, int, int) _columns(List<String> chars, int per) {
    final colOf = List.filled(chars.length, 0), rowOf = List.filled(chars.length, 0);
    var col = 0, row = 0, rows = 0;
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == '\n') {
        colOf[i] = col;
        rowOf[i] = row;
        col++;
        row = 0;
        continue;
      }
      if (row == per) {
        col++;
        row = 0;
      }
      colOf[i] = col;
      rowOf[i] = row++;
      rows = math.max(rows, row);
    }
    return (colOf, rowOf, col + 1, rows);
  }

  static int columnsOf(List<String> chars, int per) => _columns(chars, per).$3;

  /// [text] laid out on a scroll of [length] m: every character in one
  /// column filling the work's paper (the hanging scrolls'); or, [grows], a
  /// character every [_step] m down columns of [_Scroll.perColumn], right to
  /// left, the work's paper as long as its longest column (the written-in
  /// one's).
  static _Writing lay(String text, {required double length, required bool grows}) {
    final chars = text.characters.toList(), n = chars.length;
    final (colOf, rowOf, cols, rows) = _columns(chars, grows ? _Scroll.perColumn : math.max(n, 1));
    final double first, step, bottom, size;
    if (grows) {
      step = _step;
      size = step * 0.86;
      first = _top + _pad;
      bottom = first + math.max(rows, 1) * step + _pad;
    } else {
      const paperBottom = 1.165;
      step = (paperBottom - _top) * 0.82 / math.max(n, 1);
      // (Spaced a little, as a calligrapher spaces them: room between two
      // for the caret.)
      size = math.min(2 * _halfPaper * 0.62, step * 0.86);
      first = _top + (paperBottom - _top) * 0.07;
      bottom = paperBottom;
    }
    // (Metres to UV: x across from the middle, y down the scroll.)
    double u(double x) => x / _Scroll.width + 0.5;
    double v(double y) => y / length;
    final half = grows ? math.min(size * 0.62, _pitch / 2) : size * 0.62;
    double x(int k) => ((cols - 1) / 2 - k) * _pitch;
    final cells = [
      for (var i = 0; i < n; i++)
        chars[i] == '\n' ? Rect.zero : Rect.fromLTRB(u(x(colOf[i]) - half), v(first + rowOf[i] * step), u(x(colOf[i]) + half), v(first + (rowOf[i] + 1) * step)),
    ];
    final carets = <(int, double)>[
      for (var i = 0; i < n; i++) (colOf[i], v(first + rowOf[i] * step)),
      if (n == 0)
        (0, v(first))
      else if (chars[n - 1] == '\n')
        (colOf[n - 1] + 1, v(first))
      else
        (colOf[n - 1], v(first + (rowOf[n - 1] + 1) * step)),
    ];
    final utf16 = <int>[0];
    for (final c in chars) {
      utf16.add(utf16.last + c.length);
    }
    return _Writing._(
      text,
      chars,
      cells,
      carets,
      [for (var k = 0; k < cols; k++) (u(x(k) - half), u(x(k) + half))],
      Rect.fromLTRB(u(-_halfPaper), v(_top), u(_halfPaper), v(bottom)),
      bottom + 0.075,
      size,
      utf16,
    );
  }

  /// The caret position nearest [p] (UV0): in the nearest column, before a
  /// character over its top half, after it over its bottom half.
  int caretAt(Offset p) {
    var col = 0;
    var near = double.infinity;
    for (var k = 0; k < columns.length; k++) {
      final d = (p.dx - (columns[k].$1 + columns[k].$2) / 2).abs();
      if (d < near) {
        near = d;
        col = k;
      }
    }
    return _nearestIn(col, p.dy) ?? 0;
  }

  int? _nearestIn(int col, double v) {
    int? best;
    var near = double.infinity;
    for (var i = 0; i < carets.length; i++) {
      if (carets[i].$1 != col) continue;
      final d = (v - carets[i].$2).abs();
      if (d < near) {
        near = d;
        best = i;
      }
    }
    return best;
  }

  /// Where caret position [i] is: down its column, and across it.
  (double, double, double) caretBar(int i) {
    final (k, v) = carets[i.clamp(0, carets.length - 1)];
    final (u0, u1) = columns[k.clamp(0, columns.length - 1)];
    return (v, u0, u1);
  }

  /// Round characters [a] to [b] (not [b]): a box a column.
  List<Rect> boxes(int a, int b) {
    final out = <int, Rect>{};
    for (var i = math.max(a, 0); i < b && i < cells.length; i++) {
      if (chars[i] == '\n') continue;
      final k = carets[i].$1;
      out[k] = out[k]?.expandToInclude(cells[i]) ?? cells[i];
    }
    return out.values.toList();
  }

  /// Caret position [i] moved to the next column ([next] +1, the one to the
  /// left) or the one before, as far down it.
  int columnMove(int i, int next) {
    final (k, v) = carets[i.clamp(0, carets.length - 1)];
    return _nearestIn(k + next, v) ?? i;
  }

  /// The caret position at UTF-16 [offset] (inside a character: before it),
  /// and back.
  int graphemeAt(int offset) {
    var i = 0;
    while (i + 1 < utf16.length && utf16[i + 1] <= offset) {
      i++;
    }
    return i;
  }

  int utf16At(int i) => utf16[i.clamp(0, utf16.length - 1)];
}

/// One scroll: its paper (the material's mesh) and its writing, its top
/// rod, its roller with its knobs, the two pegs that hold it to the line;
/// how far it's unrolled and how it swings.
class _Scroll {
  _Scroll(
    this.index,
    this.x,
    double lineY,
    String text, {
    required this.silk,
    required this.band,
    required this.material,
    required this.ends,
    required PhysicallyBasedMaterial wood,
    required PhysicallyBasedMaterial knob,
    required PhysicallyBasedMaterial peg,
    required double yaw,
    required vm.Vector3 Function(double, double, double) world,
  }) : shape = ScrollShape() {
    shape
      ..yaw = yaw
      ..len = length
      ..origin.setFrom(world(x, lineY, 0));
    writing = _Writing.lay(text, length: length, grows: editable);
    paper = Node(name: 'scroll $index', mesh: Mesh(_paperGeometry(shape.origin, length), material));
    rod = Node(name: 'scroll $index rod', mesh: Mesh(CuboidGeometry(vm.Vector3(width + 0.03, 0.014, 0.012)), wood));
    roller = Node(name: 'scroll $index roller', mesh: Mesh(CylinderGeometry(bottomRadius: ScrollShape.rod * 0.97, topRadius: ScrollShape.rod * 0.97, height: width + 0.02, radialSegments: 20), wood));
    for (var s = 0; s < 2; s++) {
      caps.add(Node(name: 'scroll $index roll end', mesh: Mesh(_disc, ends))..castsShadows = false);
      knobs.add(Node(name: 'scroll $index knob', mesh: Mesh(CylinderGeometry(bottomRadius: 0.0155, topRadius: 0.0155, height: 0.028, radialSegments: 20), knob)));
      pegs.add(Node(name: 'scroll $index peg', mesh: Mesh(CuboidGeometry(vm.Vector3(0.014, 0.078, 0.02)), peg)));
    }
  }

  final int index;

  /// Where along the line (the lab's x).
  final double x;
  final PreprocessedMaterial material;

  /// The roll's ends (roll_end.fmat): its spiral, edge on.
  final PreprocessedMaterial ends;

  /// The mounting's silk and its top and foot bands'.
  final Color silk, band;
  final ScrollShape shape;
  late final Node paper, rod, roller;
  final knobs = <Node>[], pegs = <Node>[], caps = <Node>[];
  late _Writing writing;

  /// Written in (the middle one): its paper longer, the rest of it on the
  /// roll until the writing needs it; its writing in ink laid on the paper
  /// ([_Ink]), not painted into it.
  bool get editable => index == HangingScrolls.editable;
  _Ink? ink;

  /// A disc of radius 1 across y (the roll's ends: scaled to its radius).
  static final Geometry _disc = () {
    const n = 48;
    final pos = <double>[0, 0, 0], nor = <double>[0, 1, 0];
    final idx = <int>[];
    for (var k = 0; k <= n; k++) {
      final a = k / n * 2 * math.pi;
      pos.addAll([math.cos(a), 0, math.sin(a)]);
      nor.addAll([0, 1, 0]);
      if (k > 0) idx.addAll([0, k, k + 1]);
    }
    return geometryOf(MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), indices: idx));
  }();

  /// The paper (m): its width, how much hangs when it's rolled up; its
  /// length (the last turn glued round the roller), the written-in one's
  /// longer. Its writing: [perColumn] characters to a column, [maxColumns]
  /// columns (the longest column as long as the line's height allows).
  static const width = 0.5, closed = 0.02;
  double get length => editable ? 2.6 : 1.5;
  static const perColumn = 8, maxColumns = 2;

  /// How far it hangs open: all its paper but the last turn; the
  /// written-in one, a hand below its writing (the roll the rest).
  double get _open => editable ? writing.paper.bottom * length + 0.12 : length - 2 * math.pi * ScrollShape.rod;

  /// How far it's unrolled; the swing (rad) and how fast it's going; the
  /// kick at the end of the unroll given yet.
  double _s = closed, _swing = 0, _spin = 0, _kicked = 0;

  void addTo(Node parent) {
    for (final n in [paper, rod, roller, ...caps, ...knobs, ...pegs]) {
      parent.add(n);
    }
  }

  void reset() {
    _s = closed;
    _swing = _spin = 0;
    _kicked = 0;
  }

  /// Written into: laid out again at once (the selection's on the new
  /// layout), its ink moved to it, unrolled to fit as it goes.
  void retext(String text) {
    writing = _Writing.lay(text, length: length, grows: editable);
    ink?.lay(writing, length);
  }

  /// The face painted from the writing (the latest only, if they overlap);
  /// the written-in one's once, its paper bare (a writing roll).
  Future<void> paint() async {
    final version = ++_painted, w = writing, clock = Stopwatch()..start();
    final face = await _paintFace(w, silk, band, index, length, roll: editable);
    HangingScrolls.log?.call('scroll $index ${clock.elapsedMilliseconds} ms');
    if (version != _painted) return;
    material.parameters.setTexture('face', face.gpuTexture, sampler: face.sampledSampler);
  }

  int _painted = 0;

  /// When it unrolls (each a little after the last, left to right), and
  /// how long it takes.
  double get _from => 1.2 + 0.7 * index;
  static const _unroll = 2.6;

  void update(double t, double dt, double v, {required double unrolled}) {
    // Unrolled from the top: lowered smoothly, coming to rest at the end of
    // its paper (a kick to its swing as it stops). Written into after: more
    // of it unrolled as the writing grows, the roll turning and dropping,
    // rolled back up as it's deleted.
    final u = c01((unrolled - _from) / _unroll);
    final f = u < 1 ? eio(u) : 1.0;
    if (u < 1) {
      _s = closed + (_open - closed) * f;
    } else {
      if (_kicked == 0) {
        _kicked = 1;
        _spin += 0.22;
      }
      _s = approach(_s, _open, dt, 0.28);
    }
    // The swing: a pendulum (as long as what hangs, its weight low), pushed
    // by the wind's square, a little of its own flutter on top.
    final reach = 0.08 + 0.75 * _s, w0 = math.sqrt(9.81 / reach);
    final push = 0.06 * v * v + 0.015 * math.sin(2.1 * t + index * 1.7) * v;
    if (dt > 0) {
      for (var k = 0, n = (dt / (1 / 240)).ceil(); k < n; k++) {
        final h = dt / n;
        _spin += (-w0 * w0 * (_swing - push) - 2 * 0.12 * w0 * _spin) * h;
        _swing += _spin * h;
      }
    }
    shape
      ..s = _s
      ..swing = _swing
      ..billow = 0.035 * v * f
      ..twist = (0.15 * math.sin(0.62 * t + index * 2.3) + 0.06 * math.sin(1.7 * t + index)) * (0.4 + 0.6 * v) * f
      ..ripple = 0.007 * v * f
      ..t = t;
    shape.apply(material.parameters);
    ink?.follow(shape);
    _place();
  }

  /// Where [ray] first meets the face of what hangs (not the roll): how far
  /// along the ray, and the point on the face (UV0); null if it misses, or
  /// meets only the back. The shape as the material has it this frame, the
  /// same sum on a coarse grid (ScrollShape.paperPoint).
  (double, Offset)? hit(vm.Ray ray) {
    const cols = 6;
    final s = shape.s, rows = (s / 0.02).ceil().clamp(2, 120);
    final grid = [
      for (var j = 0; j <= rows; j++) [for (var i = 0; i <= cols; i++) shape.paperPoint((i / cols - 0.5) * width, j / rows * s)],
    ];
    (double, Offset)? best;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final p00 = grid[j][i], p10 = grid[j][i + 1], p01 = grid[j + 1][i], p11 = grid[j + 1][i + 1];
        // (Only from the face's side: its normal as the material's.)
        if ((p01 - p00).cross(p10 - p00).dot(ray.direction) >= 0) continue;
        for (final (a, b, c, back) in [(p00, p10, p01, false), (p11, p01, p10, true)]) {
          final m = _meet(ray, a, b, c);
          if (m == null || (best != null && m.$1 >= best.$1)) continue;
          final fi = back ? i + 1 - m.$2 : i + m.$2, fj = back ? j + 1 - m.$3 : j + m.$3;
          // (UV0 as the mesh's: the face's u mirrored, v down it.)
          best = (m.$1, Offset(1 - fi / cols, fj / rows * s / length));
        }
      }
    }
    return best;
  }

  /// The point of the face at [p] (UV0), in the world.
  vm.Vector3 facePoint(Offset p) => shape.paperPoint((0.5 - p.dx) * width, p.dy * length);

  /// Where [ray] meets triangle (a, b, c), Möller–Trumbore: how far along
  /// it, and the point's weights for b and c; null if it misses.
  static (double, double, double)? _meet(vm.Ray ray, vm.Vector3 a, vm.Vector3 b, vm.Vector3 c) {
    final e1 = b - a, e2 = c - a;
    final p = ray.direction.cross(e2);
    final det = e1.dot(p);
    if (det.abs() < 1e-12) return null;
    final s = ray.origin - a;
    final u = s.dot(p) / det;
    if (u < 0 || u > 1) return null;
    final q = s.cross(e1);
    final v = ray.direction.dot(q) / det;
    if (v < 0 || u + v > 1) return null;
    final t = e2.dot(q) / det;
    return t > 0 ? (t, u, v) : null;
  }

  /// The selection on the face: caret positions [a] to [b] of the writing,
  /// a box a column (none for null); for a caret, [caret] of it showing;
  /// what's [composing], a line beside it.
  void show(int? a, int b, {double caret = 0, (int, int)? composing}) {
    final none = vm.Vector4.zero();
    var first = none, second = none, bar = none, line = none;
    if (a != null && a != b) {
      final boxes = writing.boxes(math.min(a, b), math.max(a, b));
      if (boxes.isNotEmpty) first = vm.Vector4(boxes[0].left, boxes[0].top, boxes[0].right, boxes[0].bottom);
      if (boxes.length > 1) second = vm.Vector4(boxes[1].left, boxes[1].top, boxes[1].right, boxes[1].bottom);
    } else if (a != null && caret > 0) {
      final (v, u0, u1) = writing.caretBar(a);
      bar = vm.Vector4(v, u0, u1, caret);
    }
    if (composing != null) {
      final boxes = writing.boxes(composing.$1, composing.$2);
      if (boxes.isNotEmpty) line = vm.Vector4(boxes.first.right + 0.008, boxes.first.top, boxes.first.bottom, 1);
    }
    material.parameters
      ..setVec4('selection', first)
      ..setVec4('selection2', second)
      ..setVec4('caret', bar)
      ..setVec4('composing', line);
  }

  void _place() {
    final q = shape.frame;
    rod.localTransform = vm.Matrix4.compose(shape.toWorld(0, -shape.drop, 0), q, vm.Vector3.all(1));
    for (var k = 0; k < 2; k++) {
      final side = k == 0 ? -1.0 : 1.0;
      pegs[k].localTransform = vm.Matrix4.compose(shape.toWorld(side * (width / 2 - 0.06), -0.012, 0.0), q, vm.Vector3.all(1));
    }
    final c = shape.rollerCentre(), a = shape.rollerAxis();
    final up = vm.Quaternion.fromTwoVectors(vm.Vector3(0, 1, 0), a);
    roller.localTransform = vm.Matrix4.compose(c, up, vm.Vector3.all(1));
    final r = shape.outer + 0.002;
    for (var k = 0; k < 2; k++) {
      final side = k == 0 ? -1.0 : 1.0;
      knobs[k].localTransform = vm.Matrix4.compose(c + a * (side * (width / 2 + 0.012)), up, vm.Vector3.all(1));
      caps[k].localTransform = vm.Matrix4.compose(c + a * (side * width / 2), up, vm.Vector3(r, 1, r));
    }
    // (The spiral's frame: from the middle to where the paper leaves the
    // roll, its back; and down, the way it winds.)
    final o = shape.toWorld(0, 0, 0);
    final back = shape.toWorld(math.sin(shape.twist), 0, -math.cos(shape.twist)) - o, down = shape.toWorld(0, -1, 0) - o;
    ends.parameters
      ..setVec4('centre', vm.Vector4(c.x, c.y, c.z, 0))
      ..setVec4('back', vm.Vector4(back.x, back.y, back.z, 0))
      ..setVec4('down', vm.Vector4(down.x, down.y, down.z, 0))
      ..setVec4('roll', vm.Vector4(shape.outer, ScrollShape.rod, ScrollShape.thick, 0));
  }

  /// The paper's grid: its own coordinates (x across, y down it), 4 mm a
  /// row so the roll stays round; bounds wide enough for wherever the wind
  /// takes it (it's placed by the material, not the node).
  static Geometry _paperGeometry(vm.Vector3 at, double length) {
    const cols = 12;
    final rows = (length / 0.004).round();
    final pos = Float32List((cols + 1) * (rows + 1) * 3), uv = Float32List((cols + 1) * (rows + 1) * 2), nor = Float32List((cols + 1) * (rows + 1) * 3);
    for (var j = 0; j <= rows; j++) {
      for (var i = 0; i <= cols; i++) {
        final k = j * (cols + 1) + i;
        pos
          ..[3 * k] = (i / cols - 0.5) * width
          ..[3 * k + 1] = j / rows * length;
        // (Seen from its face, flutter_scene has the scroll's +x on the
        // left: the work's left edge there.)
        uv
          ..[2 * k] = 1 - i / cols
          ..[2 * k + 1] = j / rows;
        nor[3 * k + 2] = 1;
      }
    }
    // Wound counter-clockwise seen from the face.
    final idx = <int>[];
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final a = j * (cols + 1) + i, b = a + 1, c = a + cols + 1, d = c + 1;
        idx.addAll([a, c, b, b, c, d]);
      }
    }
    final g = geometryOf(MeshData(positions: pos, vertexCount: pos.length ~/ 3, normals: nor, texCoords: uv, indices: idx));
    final box = vm.Aabb3.minMax(at - vm.Vector3(1.2, 2.6, 1.2), at + vm.Vector3(1.2, 0.4, 1.2));
    g.setLocalBounds(box, vm.Sphere.centerRadius(box.center, (box.max - box.min).length / 2));
    return g;
  }
}

/// The mounted work, painted from its writing: the silk mounting (its top
/// and foot bands darker, thin gold strips either end of the work), the
/// washi with the writing in its columns, a red seal; all of the paper
/// after the work (and the roll) the foot band's. 1280 px a metre. A
/// [roll]'s: the mounting's top, then bare washi to the end of the paper
/// (written on in ink: [_Ink]).
Future<Texture2D> _paintFace(_Writing w, Color silk, Color band, int seed, double length, {bool roll = false}) async {
  const tw = 640, perMetre = tw / _Scroll.width;
  final th = (length * perMetre).round();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  double ym(double m) => m * perMetre;
  double xm(double m) => (m / _Scroll.width + 0.5) * tw;
  void weave(Rect r, Color base) {
    c.drawRect(r, Paint()..color = base);
    // A brocade's fine weave: faint diagonal threads.
    final thread = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var k = -r.height; k < r.width; k += 7) {
      c.drawLine(Offset(r.left + k, r.bottom), Offset(r.left + k + r.height, r.top), thread);
    }
    // And a small figure, scattered.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var y = r.top + 18.0; y < r.bottom; y += 36) {
      for (var x = r.left + ((y ~/ 36).isEven ? 14.0 : 32.0); x < r.right; x += 36) {
        c.drawPath(
          Path()
            ..moveTo(x, y - 5)
            ..lineTo(x + 5, y)
            ..lineTo(x, y + 5)
            ..lineTo(x - 5, y)
            ..close(),
          dot,
        );
      }
    }
  }

  final paper = Rect.fromLTRB(w.paper.left * tw, w.paper.top * th, w.paper.right * tw, roll ? th.toDouble() : w.paper.bottom * th);
  weave(Rect.fromLTRB(0, 0, tw.toDouble(), th.toDouble()), silk);
  weave(Rect.fromLTRB(0, 0, tw.toDouble(), ym(0.30)), band);
  if (!roll) weave(Rect.fromLTRB(0, ym(w.foot), tw.toDouble(), th.toDouble()), band);
  // The two strips hanging from the top (風帯).
  for (final x in [xm(-0.085), xm(0.085)]) {
    c.drawRect(Rect.fromLTRB(x - 14, 0, x + 14, ym(0.30) - 6), Paint()..color = silk);
    c.drawRect(Rect.fromLTRB(x - 14, ym(0.30) - 14, x + 14, ym(0.30) - 6), Paint()..color = const Color(0xFFB8975A));
  }
  // The gold strips either end of the work (一文字).
  const gold = Color(0xFFC2A05A);
  c.drawRect(Rect.fromLTRB(paper.left, ym(0.32), paper.right, paper.top), Paint()..color = gold);
  if (!roll) c.drawRect(Rect.fromLTRB(paper.left, paper.bottom, paper.right, paper.bottom + ym(0.025)), Paint()..color = gold);
  // The washi: warm white, its fibres (the same ones wherever it ends, so
  // they stay put as it grows).
  c.drawRect(paper, Paint()..color = const Color(0xFFF1E9D6));
  c.save();
  c.clipRect(paper);
  final rnd = math.Random(seed * 7919 + 13);
  for (var k = 0; k < (roll ? 3000 : 2400); k++) {
    final x = paper.left + rnd.nextDouble() * paper.width, y = paper.top + rnd.nextDouble() * ym(roll ? 2.3 : 2.0);
    final a = rnd.nextDouble() * math.pi, l = 4 + rnd.nextDouble() * 16;
    final color = (rnd.nextBool() ? const Color(0xFFFFFFFF) : const Color(0xFFC9BCA0)).withValues(alpha: 0.35);
    if (y > paper.bottom) continue;
    c.drawLine(
      Offset(x, y),
      Offset(x + math.cos(a) * l, y + math.sin(a) * l),
      Paint()
        ..color = color
        ..strokeWidth = 0.8,
    );
  }
  c.restore();
  // The writing, each character upright in its cell (in its vertical form,
  // the font's 'vert': 、 and 。 to the top right, ー down the column).
  // (The cell's square, the layout's: where the form puts its ink stays.)
  for (var i = 0; i < (roll ? 0 : w.chars.length); i++) {
    if (w.chars[i] == '\n') continue;
    final cell = Rect.fromLTRB(w.cells[i].left * tw, w.cells[i].top * th, w.cells[i].right * tw, w.cells[i].bottom * th);
    final tp = TextPainter(
      text: TextSpan(
        text: w.chars[i],
        style: TextStyle(fontFamily: 'Hiragino Mincho ProN', fontSize: w.size * perMetre, fontWeight: FontWeight.w600, color: const Color(0xFF1C1A17), height: 1.0, fontFeatures: _vertical),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cell.center.dx - tp.width / 2, cell.center.dy - tp.height / 2));
    tp.dispose();
  }
  // The seal, red, low on the left.
  if (roll) return _textureOf(rec, tw, th);
  final seal = Rect.fromCenter(center: Offset(paper.left + paper.width * 0.2, paper.bottom - ym(0.055)), width: 44, height: 44);
  c.drawRRect(RRect.fromRectAndRadius(seal, const Radius.circular(3)), Paint()..color = const Color(0xFFB8322A));
  final mark = TextPainter(
    text: const TextSpan(
      text: '印',
      style: TextStyle(fontFamily: 'Hiragino Mincho ProN', fontSize: 30, fontWeight: FontWeight.w600, color: Color(0xFFF6E7DC), height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  mark.paint(c, Offset(seal.center.dx - mark.width / 2, seal.center.dy - mark.height / 2));
  mark.dispose();
  return _textureOf(rec, tw, th);
}

/// What's drawn on [rec], a texture of [tw] × [th] (mipmapped, its edges
/// clamped).
Future<Texture2D> _textureOf(ui.PictureRecorder rec, int tw, int th) async {
  final clock = Stopwatch()..start();
  final picture = rec.endRecording();
  final recorded = clock.elapsedMicroseconds;
  final image = await picture.toImage(tw, th);
  final drawn = clock.elapsedMicroseconds;
  try {
    return await Texture2D.fromImage(image, sampling: const TextureSampling(addressMode: gpu.SamplerAddressMode.clampToEdge));
  } finally {
    HangingScrolls.log?.call('  (record ${(recorded / 1000).toStringAsFixed(1)}, image ${((drawn - recorded) / 1000).toStringAsFixed(1)}, upload ${((clock.elapsedMicroseconds - drawn) / 1000).toStringAsFixed(1)} ms)');
    image.dispose();
  }
}

/// The written-in scroll's writing: a quad a character, and the seal after
/// it, laid on the paper (scroll_ink.fmat bends them with it). A keystroke
/// moves quads; each glyph's painted once, the first time it's written,
/// and kept.
class _Ink {
  _Ink._(this.nodes, this.materials);

  static Future<_Ink> make(Node parent, vm.Vector3 at, _Writing writing, double length) async {
    const count = _Scroll.perColumn * _Scroll.maxColumns + 1;
    final materials = await Future.wait([for (var i = 0; i < count; i++) loadFmatMaterial('assets/scrolls/scroll_ink.fmat')]);
    final quad = _quad(at);
    final nodes = [
      for (final m in materials)
        Node(name: 'scroll ink', mesh: Mesh(quad, m))
          ..castsShadows = false
          ..visible = false,
    ];
    for (final n in nodes) {
      parent.add(n);
    }
    // (The seal's colours its own: the ink white.)
    materials.last.parameters.setVec4('ink', vm.Vector4(1, 1, 1, 1));
    final ink = _Ink._(nodes, materials);
    await _glyphOf(_seal);
    for (final ch in writing.chars) {
      if (ch != '\n') await _glyphOf(ch);
    }
    ink.lay(writing, length);
    return ink;
  }

  final List<Node> nodes;
  final List<PreprocessedMaterial> materials;

  /// What each quad has on it (a character, the seal), and how many are
  /// shown.
  late final List<String?> _on = List.filled(nodes.length, null);
  int _shown = 0;

  static const _seal = '\u0000seal';
  static final _glyphs = <String, Texture2D>{};
  static final _painting = <String, Future<Texture2D>>{};

  static Future<Texture2D> _glyphOf(String ch) => _painting.putIfAbsent(ch, () => _paintGlyph(ch).then((t) => _glyphs[ch] = t));

  /// [w]'s characters on the quads, its seal after them, the rest hidden.
  void lay(_Writing w, double length) {
    var k = 0;
    for (var i = 0; i < w.chars.length && k < nodes.length - 1; i++) {
      if (w.chars[i] == '\n') continue;
      final c = w.cells[i];
      _put(k++, w.chars[i], c.center, _Writing._pitch / 2, length);
    }
    final p = w.paper;
    _put(nodes.length - 1, _seal, Offset(p.left + p.width * 0.2, p.bottom - 0.055 / length), 0.0175, length);
    for (var j = k; j < nodes.length - 1; j++) {
      nodes[j].visible = false;
      _on[j] = null;
    }
    _shown = k;
  }

  /// Quad [k]: [ch] centred at [centre] (UV0), [half] a side (m).
  void _put(int k, String ch, Offset centre, double half, double length) {
    final x = (0.5 - centre.dx) * _Scroll.width, sig = centre.dy * length, m = materials[k];
    m.parameters.setVec4('cell', vm.Vector4(x - half, sig - half, x + half, sig + half));
    _on[k] = ch;
    final glyph = _glyphs[ch];
    if (glyph != null) {
      m.parameters.setTexture('glyph', glyph.gpuTexture, sampler: glyph.sampledSampler);
      nodes[k].visible = true;
      return;
    }
    // (A glyph not written before: shown once it's painted, if it's still
    // this quad's.)
    nodes[k].visible = false;
    _glyphOf(ch).then((t) {
      if (_on[k] != ch) return;
      m.parameters.setTexture('glyph', t.gpuTexture, sampler: t.sampledSampler);
      nodes[k].visible = true;
    });
  }

  /// Each frame: the paper's shape onto the quads shown.
  void follow(ScrollShape shape) {
    for (var k = 0; k < _shown; k++) {
      shape.apply(materials[k].parameters);
    }
    shape.apply(materials.last.parameters);
  }

  /// A glyph, white on nothing, in the square round its cell (the columns'
  /// pitch across, 192 px); the seal in its own colours.
  static Future<Texture2D> _paintGlyph(String ch) {
    const px = 192;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    void centred(String text, double size, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Hiragino Mincho ProN', fontSize: size, fontWeight: FontWeight.w600, color: color, height: 1.0, fontFeatures: _vertical),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((px - tp.width) / 2, (px - tp.height) / 2));
      tp.dispose();
    }

    if (ch == _seal) {
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(6, 6, px - 12, px - 12), const Radius.circular(14)), Paint()..color = const Color(0xFFB8322A));
      centred('印', px * 0.66, const Color(0xFFF6E7DC));
    } else {
      centred(ch, _Writing._step * 0.86 / _Writing._pitch * px, const Color(0xFFFFFFFF));
    }
    return _textureOf(rec, px, px);
  }

  /// A quad of 4 × 4 over the unit square (UV0 mirrored across, as the
  /// paper's), its bounds round where the scroll can be (the material
  /// places it).
  static Geometry _quad(vm.Vector3 at) {
    const n = 4;
    final pos = <double>[], uv = <double>[], nor = <double>[];
    final idx = <int>[];
    for (var j = 0; j <= n; j++) {
      for (var i = 0; i <= n; i++) {
        pos.addAll([i / n, j / n, 0]);
        uv.addAll([1 - i / n, j / n]);
        nor.addAll([0, 0, 1]);
      }
    }
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final a = j * (n + 1) + i, b = a + 1, c = a + n + 1, d = c + 1;
        idx.addAll([a, c, b, b, c, d]);
      }
    }
    final g = geometryOf(MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), texCoords: Float32List.fromList(uv), indices: idx));
    final box = vm.Aabb3.minMax(at - vm.Vector3(1.2, 2.6, 1.2), at + vm.Vector3(1.2, 0.4, 1.2));
    g.setLocalBounds(box, vm.Sphere.centerRadius(box.center, (box.max - box.min).length / 2));
    return g;
  }
}

/// A scroll's shape, the material's parameters (scroll.fmat), and the same
/// sum on the CPU for what hangs with the paper: the roller at the foot of
/// what's unrolled, the top rod and the pegs.
class ScrollShape {
  /// The roller's radius, the paper's thickness (a layer a turn).
  static const rod = 0.011, thick = 0.0018;

  /// Paper unrolled (m), out of its whole length [len].
  double s = 0, len = 1.5;

  /// In the wind: the swing on the line (rad, the foot forward for +), the
  /// billow (m), the twist at the foot (rad), the ripple (m); the time.
  double swing = 0, billow = 0, twist = 0, ripple = 0, t = 0;

  /// The top rod below the line (on its pegs).
  final double drop = 0.03;

  /// Where it hangs (world) and its turn.
  final origin = vm.Vector3.zero();
  double yaw = 0;

  /// The ripple's wavenumber (rad/m) and speed (rad/s).
  static const rippleK = 9.0, rippleSpeed = 3.2;

  void apply(MaterialParameters p) {
    p
      ..setVec4('origin', vm.Vector4(origin.x, origin.y, origin.z, yaw))
      ..setVec4('roll', vm.Vector4(s, len, rod, thick))
      ..setVec4('sway', vm.Vector4(swing, billow, twist, ripple))
      ..setVec4('wave', vm.Vector4(t, rippleK, rippleSpeed, _Scroll.width))
      ..setVec4('hang', vm.Vector4(drop, 0, 0, 0));
  }

  /// The roll's outer radius now.
  double get outer {
    const a = thick / (4 * math.pi);
    final left = math.max(0.0, len - s);
    final phi0 = (-rod + math.sqrt(rod * rod + 4 * a * left)) / (2 * a);
    return rod + thick * phi0 / (2 * math.pi);
  }

  /// The paper's point ([x] across, [sig] down it) in the world: the
  /// material's Vertex() on the CPU (scroll.fmat's ScrollPoint, ScrollWorld).
  vm.Vector3 paperPoint(double x, double sig) {
    final hung = math.max(s, 1e-4), d = math.min(sig, hung);
    var pin = math.sin(math.pi * d / hung);
    pin *= pin;
    final tau = twist * d / hung;
    final ax = math.cos(tau), az = math.sin(tau), fx = -math.sin(tau), fz = math.cos(tau);
    final bulge = pin * (billow + ripple * math.sin(rippleK * d - rippleSpeed * t + 2.6 * x / _Scroll.width));
    var px = ax * x + fx * bulge, py = -drop - d, pz = az * x + fz * bulge;
    if (sig > hung) {
      const a = thick / (4 * math.pi);
      final phi0 = (-rod + math.sqrt(rod * rod + 4 * a * (len - hung))) / (2 * a);
      final outer = rod + thick * phi0 / (2 * math.pi);
      final phi = (outer - math.sqrt(math.max(outer * outer - 4 * a * (sig - hung), 0.0))) / (2 * a);
      final r = outer - thick * phi / (2 * math.pi), k = outer - r * math.cos(phi);
      px += fx * k;
      pz += fz * k;
      py -= r * math.sin(phi);
    }
    return toWorld(px, py, pz);
  }

  /// The scroll's frame: turned, then swung on the line.
  vm.Quaternion get frame => vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -swing);

  /// A point in the scroll's own frame (x along the line, y up, z out of
  /// the face; the line through the origin), in the world.
  vm.Vector3 toWorld(double x, double y, double z) {
    final cs = math.cos(swing), sn = math.sin(swing);
    final py = y * cs + z * sn, pz = -y * sn + z * cs;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    return origin + vm.Vector3(cy * x + sy * pz, py, -sy * x + cy * pz);
  }

  /// The roller's middle: in front of the foot of what hangs (twisted with
  /// it), by the roll's outer radius.
  vm.Vector3 rollerCentre() {
    final r = outer;
    return toWorld(-math.sin(twist) * r, -drop - s, math.cos(twist) * r);
  }

  /// Along the roller (the twist at the foot, swung and turned).
  vm.Vector3 rollerAxis() => (toWorld(math.cos(twist), 0, math.sin(twist)) - toWorld(0, 0, 0))..normalize();
}
