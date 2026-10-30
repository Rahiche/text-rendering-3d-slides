import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart' show Texture2D;
import 'package:vector_math/vector_math.dart' as vm;

import 'devices.dart';
import 'engine_pages.dart';
import 'kit.dart';
import 'shot.dart';
import 'v_tradeoff.dart' show TradeoffTown;
import 'vignette.dart';

/// Flutter's trade-off: the web page from Chrome's room in Engine Town
/// (v_town.dart), set by Flutter's Text() this time, one thing it can't do
/// a press, a red tag on it — the Japanese across, not down; then the
/// headline not balanced — on a billboard on Trade-off Town's west bank
/// (what Flutter doesn't have, v_tradeoff.dart), only while the talk calls
/// on it.
class TalkEngines extends Vignette {
  TalkEngines(super.kit);

  @override
  String get name => 'engines';
  @override
  String get kick => "FLUTTER'S TEXT()";
  @override
  String get line => "Chrome's page, set by Flutter";
  @override
  String get note => "what it doesn't do for you: vertical text, then balanced lines";

  @override
  bool get talkOnly => true;

  /// A navy board behind the screen, rising between the billboard's masts:
  /// the page reads against it, not against the town behind.
  @override
  ({vm.Vector3 at, double w, double h})? get backdrop => (at: vm.Vector3(0, 0.6, 1.6), w: 8.6, h: 7.4);

  @override
  double get loop => 16;
  @override
  double get visit => 14;

  /// When the page turns from the vertical text to the headline (the
  /// talk's next press).
  static const _turn = 6.0;

  /// On the west side, facing the street.
  @override
  final frame = TradeoffTown.engines;

  /// The screen's height, its size (m).
  static const _y = 4.6, _ww = 5.6, _wh = 3.5;

  late final Window3D _flutter;
  late final List<Texture2D> _pages;
  bool _ready = false;

  @override
  List<(String, TextStyle)> get fontRuns => EnginePages.fontRuns;

  @override
  Future<void> init() async {
    _pages = await Future.wait([EnginePages.flutterText(vertical: true), EnginePages.flutterText(vertical: false)]);
    _flutter = Window3D(detail, w: _ww, h: _wh, page: _pages[0], name: 'engines flutter');
    _ready = true;
  }

  final _m = vm.Matrix4.identity();

  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    if (!visited || u >= visit) {
      _flutter.hide();
      return;
    }
    // In as the camera comes, bobbing a little.
    final s = eio(seg(u, 0.0, 0.9));
    if (s <= 0.001) {
      _flutter.hide();
      return;
    }
    _flutter.page = _pages[u < _turn ? 0 : 1];
    _m.setFromTranslationRotationScale(vm.Vector3(0, _y + 0.05 * math.sin(t * 1.2), 0), vm.Quaternion.identity(), vm.Vector3.all(s));
    _flutter.place(frame * _m);
  }

  /// Head on, close enough to read.
  @override
  Shot shot(double u) => Shot(vm.Vector3(-0.3, _y + 0.15, -7.8), vm.Vector3(0, _y, 0), fov: 40, settle: 1.0, drift: 0.3);
}
