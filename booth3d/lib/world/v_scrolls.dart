import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show TextEditingValue, TextRange, TextSelection;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'hanging_scrolls.dart';
import 'kit.dart';
import 'shot.dart';
import 'v_package.dart' show PackageTown;
import 'vignette.dart';

/// 縦書き · Vertical text, by hand: in Package Town, talk 06's last demo
/// before stroke_fx (v_package.dart), what owning every piece lets you
/// build, Flutter having no vertical layout. Hanging scrolls on a washing
/// line on the south-east block's roof, rolled up until the talk comes,
/// unrolling right to left as the writing reads, then moving in the wind
/// like the washing (hanging_scrolls.dart); left unrolled once it has. Its
/// second beat comes in close on the middle one, to write in: a click puts
/// the caret in it and the presenter types (scroll_typing.dart over the
/// canvas, main.dart), and it grows. The unroll keeps the talk's clock
/// (held once it's done); the wind, the scene's.
class ScrollLine extends Vignette {
  ScrollLine(super.kit);

  @override
  String get name => 'scrolls';
  @override
  String get kick => '縦書き · VERTICAL TEXT';
  @override
  String get line => 'Columns top to bottom, right to left';
  @override
  String get note => 'hanging scrolls on a washing line, each unrolled as the writing reads';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 60;
  @override
  double get visit => 20;

  /// Across the middle of the south-east block's roof (its gravel 0.5 over
  /// the block's 14 m; the rooftop kit's by its north parapet), the faces
  /// south into the sun (its +z): the camera, three-quarters on from the
  /// west end, looks north-north-east over the street.
  @override
  final frame = trs(PackageTown.o + vm.Vector3(36, 14.5, -21), rotY: math.pi);

  /// The talk's beats: unrolled by [unrolled] (held there), and close on the
  /// middle one from [close].
  static const unrolled = 7.0, close = 8.0;

  /// Capture aid: --dart-define=BOOTH3D_SCROLLS_TYPE=… is typed into the
  /// middle one a second into the close-up (as the presenter would).
  static const _typed = String.fromEnvironment('BOOTH3D_SCROLLS_TYPE');

  /// Capture aid, for a video: --dart-define=BOOTH3D_SCROLLS_DEMO=1 acts the
  /// close-up out as the presenter would, from [_demoFrom] s into it: the
  /// middle one's writing selected down its column, then typed over through
  /// an input method, each word composed (underlined) and then converted,
  /// the caret blinking.
  static const _demo = String.fromEnvironment('BOOTH3D_SCROLLS_DEMO') != '';
  static const _demoFrom = 1.8;
  static final _demoSteps = () {
    TextEditingValue v(String text, [int? composeFrom]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: composeFrom == null ? TextRange.empty : TextRange(start: composeFrom, end: text.length),
    );
    const base = '一期一会';
    return <(double, TextEditingValue)>[
      for (var k = 1; k <= base.length; k++) ((k - 1) * 0.25, TextEditingValue(text: base, selection: TextSelection(baseOffset: 0, extentOffset: k))),
      (1.6, v('ふ', 0)),
      (1.78, v('ふら', 0)),
      (1.96, v('ふらっ', 0)),
      (2.14, v('ふらった', 0)),
      (2.32, v('ふらったー', 0)),
      (2.9, v('フラッター', 0)),
      (3.3, v('フラッター')),
      (3.6, v('フラッター、')),
      (3.9, v('フラッター、よ', 6)),
      (4.08, v('フラッター、よう', 6)),
      (4.26, v('フラッター、ようこ', 6)),
      (4.44, v('フラッター、ようこそ', 6)),
      (4.9, v('フラッター、ようこそ')),
      (5.2, v('フラッター、ようこそ。')),
    ];
  }();
  int _demoStep = -1;

  /// The line between its posts (x, along it: both out of the first beat's
  /// picture), its height there, how far it sags in the middle; the scrolls
  /// closer than the lab's (all five beside the talk's card, near enough to
  /// read).
  static const _from = -3.4, _to = 4.0, _high = 2.38, _sag = 0.09, _spacing = 0.95;
  static double _lineY(double x) {
    final k = (2 * x - _from - _to) / (_to - _from);
    return _high - _sag * (1 - k * k);
  }

  late final HangingScrolls scrolls;

  /// The talk's clock and the scene's, last frame (null: not seen yet);
  /// whether the talk's been here (they stay unrolled after it).
  double? _lastU, _lastT;
  bool _shown = false;

  @override
  Future<void> init() async {
    final b = Batch(), wood = pbr(rgb(1, 1, 1), roughness: 0.8);
    for (final x in [_from - 0.05, _to + 0.05]) {
      cylinder(b, wood, 0.05, 2.6, x, 1.3, 0, Vignette.c(0x7A5A3C));
    }
    b.buildInto(detail, 'scroll line posts', castsShadows: true, lightChannelMask: 0x01);
    final rope = pbr(lin(const Color(0xFFD8D2C4)), roughness: 0.9);
    final path = CatmullRomPath([for (var k = 0; k <= 16; k++) world(_from + (_to - _from) * k / 16, _lineY(_from + (_to - _from) * k / 16) + 0.004, 0)]);
    detail.add(Node(name: 'scroll line', mesh: Mesh(TubeGeometry(path, radius: 0.004, radialSegments: 8, stations: 96), rope)));
    scrolls = HangingScrolls(parent: detail, at: world, yaw: kit.yawOf(frame), lineY: _lineY, spacing: _spacing);
    await scrolls.init();
  }

  @override
  void pose(double u, double t, double night) {
    if (!scrolls.ready) return;
    // (Posed all along, a talk-only scene: rolled up on the line until the
    // talk's here; back to the start of the stop, rolled up again.)
    final lastU = _lastU, lastT = _lastT;
    if (visited && (lastU == null || u < lastU - 0.01)) scrolls.reset();
    final dt = lastT == null ? 0.0 : (t - lastT).clamp(0.0, 0.1);
    _lastU = visited ? u : null;
    _lastT = t;
    if (visited) _shown = true;
    if (_typed.isNotEmpty && visited && u >= close + 1 && scrolls.editableText != _typed) {
      scrolls.edited(TextEditingValue(text: _typed, selection: const TextSelection.collapsed(offset: _typed.length)));
    }
    if (_demo && visited) {
      final s = u - close - _demoFrom;
      var step = -1;
      while (step + 1 < _demoSteps.length && _demoSteps[step + 1].$1 <= s) {
        step++;
      }
      if (step != _demoStep && step >= 0) scrolls.edited(_demoSteps[step].$2);
      _demoStep = step;
      scrolls.demo = step >= 0;
    }
    scrolls.update(t, dt, unrolled: visited ? u : (_shown ? unrolled : 0));
  }

  // ── The camera ────────────────────────────────────────────────────────────

  @override
  Shot shot(double u) {
    if (u < close) {
      // All five, three-quarters on from the line's west end: the last to
      // unroll (ありがとう) nearest, by the card on the left; the first
      // (縦書き) farthest, on the right, where the writing starts.
      return Shot(vm.Vector3(2.9, 1.5, 3.2), vm.Vector3(0.65, 1.55, 0), fov: 42, settle: 1.0, drift: 0.3);
    }
    // In close on the middle one, a little from the side: all of it in the
    // picture, however long it's grown, its foot clear of the talk's way
    // along the bottom.
    final hung = scrolls.ready ? scrolls.hungOf(HangingScrolls.editable) : 1.3, middle = _lineY(0) - 0.03 - hung / 2;
    final back = math.max(3.0, (hung + 0.6) / 2 / math.tan(18 * math.pi / 180));
    return Shot(vm.Vector3(-0.5, middle - 0.15, back), vm.Vector3(0, middle - 0.1, 0), fov: 36, settle: 0.8, drift: 0.12);
  }
}
