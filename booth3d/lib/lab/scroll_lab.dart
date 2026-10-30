import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../capture_stub.dart' if (dart.library.io) '../capture_io.dart';
import '../tuning.dart';
import '../world/hanging_scrolls.dart';
import '../world/kit.dart' show lin, pbr;
import '../world/scroll_typing.dart';
import '../world/shapes.dart' show geometryOf;
import '../world/sky.dart';

/// 掛け軸 · The lab the talk's hanging scrolls were tried in
/// (hanging_scrolls.dart, scroll_typing.dart; in the talk, v_scrolls.dart):
/// on a washing line out in a meadow of its own, the city's sky and sun
/// over it, the camera's views to choose from.
///
///   flutter run -d macos --dart-define=BOOTH3D_LAB=scrolls
///   bash booth3d/tool/build_scroll_lab.sh     (~/Applications/Scroll Lab.app)
///
/// R unrolls them again, U watches one unroll up close (the camera on its
/// roller), S slows it all down, C changes the view, Space holds the wind,
/// Esc quits; the writing as hanging_scrolls.dart has it (select, copy, the
/// text menu, the middle one typed into). A capture (BOOTH3D_TIMES,
/// BOOTH3D_TAG) works as the city's does; BOOTH3D_LOOK=0,2 takes each time
/// in those views (BOOTH3D_FPS: a video's frames).
class ScrollLabApp extends StatelessWidget {
  const ScrollLabApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Scroll Lab',
    home: _LabPage(),
  );
}

class _LabPage extends StatefulWidget {
  const _LabPage();

  @override
  State<_LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<_LabPage> with SingleTickerProviderStateMixin {
  final lab = ScrollLab();
  late final Ticker _ticker = createTicker(_tick);
  final _canvas = GlobalKey();
  final _focus = FocusNode();
  final _typing = GlobalKey<ScrollTypingState>();
  Duration _last = Duration.zero;
  bool _ready = false;

  /// Slow motion (S): a quarter of the speed.
  bool _slow = false;

  static const _times = String.fromEnvironment('BOOTH3D_TIMES');

  /// Frames for a video: BOOTH3D_TIMES's ranges (2-7.5) every frame.
  static final _fps = double.tryParse(const String.fromEnvironment('BOOTH3D_FPS')) ?? 0;
  static const _tag = String.fromEnvironment('BOOTH3D_TAG', defaultValue: 'lab');

  /// The views a capture takes (BOOTH3D_LOOK=0,2: each time in each).
  static const _look = String.fromEnvironment('BOOTH3D_LOOK');

  /// A capture's drag across the writing, at its first time:
  /// BOOTH3D_LAB_DRAG=x0,y0,x1,y1 (canvas px); what's typed into the middle
  /// scroll then (BOOTH3D_LAB_TYPE: TEXT|n, its last n characters still
  /// being composed; ~TEXT, typed a character every 0.35 s from then on),
  /// and where the text menu opens (BOOTH3D_LAB_MENU=x,y).
  static const _drag = String.fromEnvironment('BOOTH3D_LAB_DRAG');
  static const _type = String.fromEnvironment('BOOTH3D_LAB_TYPE');
  static const _menuTest = String.fromEnvironment('BOOTH3D_LAB_MENU');

  static const _canvasSize = Size(1600, 900);

  @override
  void initState() {
    super.initState();
    lab.init().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      if (_times.isEmpty) {
        _ticker.start();
      } else {
        _capture();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 0.1);
    _last = elapsed;
    _Perf.start();
    if (_Perf.autotype) _typeOn(elapsed);
    lab.update(_slow ? dt / 4 : dt);
  }

  /// A timing run's typing (BOOTH3D_LAB_AUTOTYPE): a character every 0.3 s
  /// into the middle scroll, a line and back again, over and over.
  void _typeOn(Duration elapsed) {
    const line = '一期一会、また会う日まで';
    final step = elapsed.inMilliseconds ~/ 300;
    if (step == _typed || elapsed.inSeconds < 8) return;
    _typed = step;
    final all = line.characters.toList(), k = 4 + (step % 16 < 8 ? step % 8 : 8 - step % 8);
    final text = all.take(k).join();
    lab.scrolls.edited(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
  }

  int _typed = -1;

  /// (A drag, typing and the menu, as the capture asks.)
  void _act(CaptureSink out, int view) {
    final scrolls = lab.scrolls;
    lab
      ..view = view
      ..update(0);
    if (_drag.isNotEmpty) {
      final v = [for (final n in _drag.split(',')) double.parse(n)];
      scrolls
        ..selectFrom(Offset(v[0], v[1]), _canvasSize, lab.camera)
        ..selectTo(Offset(v[2], v[3]), _canvasSize, lab.camera);
      out.log('SELECTED "${scrolls.selectedText}" (over the writing at the start: ${scrolls.overText(Offset(v[0], v[1]), _canvasSize, lab.camera)})');
    }
    if (_type.isNotEmpty && !_type.startsWith('~')) {
      // (As typed: the text in, the caret after it; TEXT|n: its last n
      // characters still being composed.)
      final parts = _type.split('|'), text = parts.first.replaceAll(r'\n', '\n');
      final composing = parts.length > 1 ? int.parse(parts[1]) : 0;
      scrolls
        ..editorFocused = true
        ..edited(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: composing > 0 ? TextRange(start: text.length - composing, end: text.length) : TextRange.empty,
          ),
        );
      out.log('TYPED "${scrolls.editableText}" (fits: ${HangingScrolls.fits(text)})');
    }
    if (_menuTest.isNotEmpty) {
      final v = [for (final n in _menuTest.split(',')) double.parse(n)];
      _typing.currentState?.openMenu(Offset(v[0], v[1]));
      out.log('MENU at ${v[0]},${v[1]} (selected "${scrolls.selectedText}", editing: ${scrolls.editing})');
    }
  }

  /// Frames at scene times (BOOTH3D_TIMES), as the city's capture.
  Future<void> _capture() async {
    final out = CaptureSink(_tag);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final looks = _look.isEmpty ? [0] : [for (final v in _look.split(',')) int.parse(v)];
    final targets = [
      for (final s in _times.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty))
        if (_fps > 0 && s.indexOf('-', 1) > 0)
          for (var k = 0, a = double.parse(s.substring(0, s.indexOf('-', 1))), b = double.parse(s.substring(s.indexOf('-', 1) + 1)); a + k / _fps < b - 1e-6; k++) a + k / _fps
        else
          double.parse(s),
    ];
    var frame = 0;
    var acted = _drag.isEmpty && _type.isEmpty && _menuTest.isEmpty;
    final typewriter = _type.startsWith('~') ? _type.substring(1).characters.toList() : null;
    double? typedFrom;
    for (final target in targets) {
      while (lab.t < target - 1e-9) {
        lab.update(math.min(1 / 30, target - lab.t));
      }
      if (typewriter != null) {
        // (From what's there already, a character at a time.)
        typedFrom ??= target;
        final had = lab.scrolls.editableText.characters.toList();
        var k = 0;
        while (k < had.length && k < typewriter.length && had[k] == typewriter[k]) {
          k++;
        }
        final want = math.min(typewriter.length, math.max(k, ((target - typedFrom) / 0.35).floor() + 1));
        final text = typewriter.take(want).join();
        if (text != lab.scrolls.editableText) {
          lab.scrolls.edited(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
        }
      }
      if (!acted) {
        acted = true;
        _act(out, looks.first);
      }
      for (final v in looks) {
        lab.view = v;
        // (A video's frames: just drawn; a still's: settled a moment.)
        for (var k = 0; k < (_fps > 0 ? 1 : 6); k++) {
          lab.update(0);
          await WidgetsBinding.instance.endOfFrame;
          if (_fps == 0) await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        final boundary = _canvas.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final name = _fps > 0 ? 'v${v}_f${(++frame).toString().padLeft(5, '0')}.png' : 't${target.toStringAsFixed(2).padLeft(7, '0')}_v$v.png';
        out
          ..save(name, png!.buffer.asUint8List())
          ..log('captured $name');
      }
    }
    out.finish();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    // (Typing into the middle scroll: the editor's keys, none of these.)
    if (e is! KeyDownEvent || lab.scrolls.editorFocused) return KeyEventResult.ignored;
    final cmd = HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.keyC when cmd:
        _typing.currentState?.copy();
      case LogicalKeyboardKey.keyA when cmd:
        lab.scrolls.selectAll();
      case LogicalKeyboardKey.keyR:
        lab.restart();
      case LogicalKeyboardKey.keyU:
        lab
          ..view = ScrollLab.unrollView
          ..restart();
      case LogicalKeyboardKey.keyS:
        _slow = !_slow;
      case LogicalKeyboardKey.keyC:
        lab.view = (lab.view + 1) % ScrollLab.views;
      case LogicalKeyboardKey.space:
        lab.calm = !lab.calm;
      case LogicalKeyboardKey.escape:
        if (_typing.currentState?.closeMenu() ?? false) {
          // (The menu shut.)
        } else if (lab.scrolls.hasSelection) {
          lab.scrolls.clearSelection();
        } else {
          SystemNavigator.pop();
        }
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final view = _ready ? SceneView(lab.scene, camera: lab.camera, pixelRatio: 1.2) : const ColoredBox(color: Color(0xFF1B2433));
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Material(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            child: RepaintBoundary(
              key: _canvas,
              child: SizedBox.fromSize(
                size: _canvasSize,
                child: Stack(
                  children: [
                    Positioned.fill(child: view),
                    if (_ready)
                      Positioned.fill(
                        child: ScrollTyping(key: _typing, scrolls: lab.scrolls, camera: () => lab.camera, canvas: _canvasSize, keysBack: _focus),
                      ),
                    const Positioned(left: 28, bottom: 22, child: IgnorePointer(child: _Hint())),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the pointer does here, in a corner.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => const Text(
    'Drag across the writing to select it  ·  double-click: all of it  ·  right-click: the text menu  ·  ⌘C copies\n'
    'Click into the middle scroll and type: it grows  ·  R unrolls them again  ·  U one unroll up close  ·  S slow motion  ·  C views',
    style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 15, height: 1.5, shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)]),
  );
}

/// The meadow, the line, its scrolls (hanging_scrolls.dart) and the camera.
class ScrollLab {
  final scene = Scene();
  late final sky = Sky3D(scene);
  final camera = PerspectiveCamera(fovRadiansY: 38 * math.pi / 180);
  late final HangingScrolls scrolls;

  /// Seconds since it started (or since R).
  double t = 0;

  /// Which view (C): the line, the middle scroll close, along the line, from
  /// low in the grass, the first scroll's unroll up close (its roller
  /// followed down).
  int view = 0;
  static const views = 5, unrollView = 4;

  /// The wind held (Space).
  bool calm = false;

  /// The lab's frame: the line along its x, the scrolls' faces towards its
  /// +z, turned so the sun comes over the viewer's shoulder.
  double _yaw0 = 0;

  /// The line: its ends on the poles (x, along it), its height there, and
  /// how far it sags in the middle.
  static const _lineEnd = 3.7, _lineHigh = 2.38, _sag = 0.07;

  double _lineY(double x) => _lineHigh - _sag * (1 - (x / _lineEnd) * (x / _lineEnd));

  vm.Vector3 _world(double x, double y, double z) {
    final c = math.cos(_yaw0), s = math.sin(_yaw0);
    return vm.Vector3(c * x + s * z, y, -s * x + c * z);
  }

  Future<void> init() async {
    await Scene.initializeStaticResources();
    scene.antiAliasingMode = Tuning.aa;
    EnvironmentMap.radianceCubeSize = Tuning.cube;
    await sky.init();
    sky.talk = 1;
    // The faces turned 60° off the sun (its light from the viewer's side,
    // raking across the paper, round every curl).
    final sunAz = math.atan2(sky.sun.x, sky.sun.z);
    _yaw0 = sunAz + 60 * math.pi / 180;
    scene.depthOfField
      ..enabled = _Perf.dof
      ..quality = DepthOfFieldQuality.medium
      ..maxBackgroundBlur = 10
      ..maxForegroundBlur = 8;
    await _field();
    if (_Perf.grass) await _meadow();
    final root = Node(name: 'scrolls');
    scene.add(root);
    scrolls = HangingScrolls(parent: root, at: _world, yaw: _yaw0, lineY: _lineY);
    if (_Perf.on) HangingScrolls.log = _Perf.paint;
    await scrolls.init();
    restart();
    update(0);
  }

  void restart() {
    t = 0;
    scrolls.reset();
  }

  void update(double dt) {
    t += dt;
    scrolls.update(t, dt, calm: calm);
    _grass?.parameters.setVec4('wind', vm.Vector4(_downwind.x, _downwind.z, calm ? 0.0 : 0.6 + 0.4 * HangingScrolls.wind(t, 0), t));
    sky.update(1000 + t, dt);
    // (Out in the open: more air between here and the horizon than over the
    // city, the meadow's green filmic, not bright.)
    scene
      ..toneMapping = ToneMappingMode.agx
      ..fog.density = 0.006;
    _aim();
  }

  void _aim() {
    if (view == unrollView) {
      // Down with the first scroll's roller as it unrolls, close, from in
      // front and off to one side: the roll turning, the paper coming off
      // it, its spiral at the end.
      final c = scrolls.rollerOf(0), o = _world(0, 0, 0);
      camera
        ..position = c + _world(0.46, 0.07, 0.36) - o
        ..target = c + _world(0.22, 0.03, 0) - o
        ..fovRadiansY = 30 * math.pi / 180;
      scene.depthOfField.focusDistance = (camera.target - camera.position).length;
      return;
    }
    // A slow drift, as a hand-held camera's.
    final d = 0.05 * math.sin(t * 0.23), e = 0.03 * math.sin(t * 0.31 + 1);
    // (The middle one close: all of it in the picture, however long it's
    // grown.)
    final hung = scrolls.hungOf(HangingScrolls.editable), middle = _lineY(0) - 0.03 - hung / 2;
    final back = math.max(3.1, (hung + 0.4) / 2 / math.tan(18 * math.pi / 180));
    final (eye, at, fov) = switch (view) {
      // The line, all five, from a few steps back.
      0 => (vm.Vector3(0.3 + d * 4, 1.3 + e, 5.8), vm.Vector3(0.0, 1.62, 0), 38.0),
      // The middle one close, a little from the side.
      1 => (vm.Vector3(-0.6 + d, middle - 0.1 + e, back), vm.Vector3(0.0, middle, 0), 36.0),
      // Along the line from its end, the swing in and out across the view.
      2 => (vm.Vector3(4.6 + d * 2, 1.4 + e, 3.9), vm.Vector3(-0.6, 1.62, 0), 40.0),
      // From low in the grass, looking up at them against the sky.
      _ => (vm.Vector3(1.3 + d * 2, 0.5, 3.4), vm.Vector3(-0.2, 1.8, 0), 48.0),
    };
    camera
      ..position = _world(eye.x, eye.y, eye.z)
      ..target = _world(at.x, at.y, at.z)
      ..fovRadiansY = fov * math.pi / 180;
    scene.depthOfField.focusDistance = (camera.target - camera.position).length;
  }

  /// The field: grass to the horizon, two posts and the line between them.
  Future<void> _field() async {
    final detail = await Texture2D.fromAsset('assets/textures/grass_detail.jpg');
    final relief = await Texture2D.fromAsset('assets/textures/grass_normal.jpg', content: TextureContent.normal);
    // (As the city's lawn: the photo's detail, a meadow's colour over it.)
    final c = lin(const Color(0xFF5E7040));
    final grass = PhysicallyBasedMaterial()
      ..baseColorTexture = detail
      ..baseColorFactor = vm.Vector4(c.x / 0.58, c.y / 0.58, c.z / 0.58, 1)
      ..normalTexture = relief
      ..normalScale = 1.0
      ..metallicFactor = 0
      ..roughnessFactor = 0.95;
    // A tile every 3 m, out to 300 m.
    const r = 300.0, tile = 3.0;
    scene.add(
      Node(
        name: 'field',
        mesh: Mesh(
          geometryOf(
            MeshData(
              positions: Float32List.fromList([-r, 0, -r, r, 0, -r, r, 0, r, -r, 0, r]),
              vertexCount: 4,
              normals: Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]),
              texCoords: Float32List.fromList([-r / tile, -r / tile, r / tile, -r / tile, r / tile, r / tile, -r / tile, r / tile]),
              indices: [0, 2, 1, 0, 3, 2],
            ),
          ),
          grass,
        ),
      ),
    );
    final post = pbr(lin(const Color(0xFF7A5A3C)), roughness: 0.8);
    for (final x in [-_lineEnd - 0.05, _lineEnd + 0.05]) {
      scene.add(
        Node(
          name: 'post',
          mesh: Mesh(CylinderGeometry(bottomRadius: 0.05, topRadius: 0.045, height: 2.6, radialSegments: 14), post),
          localTransform: vm.Matrix4.translation(_world(x, 1.3, 0)),
        ),
      );
    }
    final rope = pbr(lin(const Color(0xFFD8D2C4)), roughness: 0.9);
    final path = CatmullRomPath([for (var k = 0; k <= 16; k++) _world(-_lineEnd + 2 * _lineEnd * k / 16, _lineY(-_lineEnd + 2 * _lineEnd * k / 16) + 0.004, 0)]);
    scene.add(Node(name: 'line', mesh: Mesh(TubeGeometry(path, radius: 0.004, radialSegments: 8, stations: 96), rope)));
  }

  /// The wind's way across the field (world), as the scrolls are pushed:
  /// out of their faces' backs.
  vm.Vector3 get _downwind => _world(0, 0, 1);

  PreprocessedMaterial? _grass;

  /// The meadow: clumps of blades (their sway in grass.fmat) scattered
  /// about a spot in front of the line, as many to each step further out as
  /// there are (log-uniform), the far ones spread wider: as thick on the
  /// screen near and far, out to the horizon, from a few thousand clumps.
  Future<void> _meadow() async {
    final grass = _grass = await loadFmatMaterial('assets/lab/grass.fmat');
    final clumps = InstancedMesh(geometry: _clump(), material: grass);
    final rnd = math.Random(7);
    for (var k = 0; k < 24000; k++) {
      final d = 0.4 * math.pow(150, rnd.nextDouble()), a = rnd.nextDouble() * 2 * math.pi;
      final x = 0.3 + math.cos(a) * d, z = 4.0 + math.sin(a) * d;
      final spread = math.max(1.0, d / 5);
      final h = 0.22 + 0.3 * rnd.nextDouble() + 0.1 * rnd.nextDouble();
      clumps.addInstance(vm.Matrix4.compose(_world(x, 0, z), vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), rnd.nextDouble() * 2 * math.pi), vm.Vector3(spread, h, spread)));
    }
    scene.add(Node(name: 'meadow')..addComponent(InstancedMeshComponent(clumps))..castsShadows = false);
  }

  /// A clump: seven blades, each a strip tapering to its tip in four
  /// pieces, leaning out and curving over a little, its own tint (vertex
  /// colour); 1 m tall (the instance sets its height); UV0.y up the blade.
  static Geometry _clump() {
    final rnd = math.Random(3);
    final pos = <double>[], nor = <double>[], uv = <double>[], col = <double>[];
    final idx = <int>[];
    for (var b = 0; b < 7; b++) {
      final a = rnd.nextDouble() * 2 * math.pi, r = 0.015 + 0.05 * rnd.nextDouble();
      final x0 = math.cos(a) * r, z0 = math.sin(a) * r;
      final turn = rnd.nextDouble() * math.pi, lean = 0.08 + 0.22 * rnd.nextDouble(), tall = 0.65 + 0.35 * rnd.nextDouble();
      final tint = 0.75 + 0.5 * rnd.nextDouble(), yellow = rnd.nextDouble() < 0.25 ? 1.25 : 1.0;
      // Across the blade, and the way it leans (out from the clump).
      final ax = math.cos(turn), az = math.sin(turn), ox = math.cos(a), oz = math.sin(a);
      final base = pos.length ~/ 3;
      for (var k = 0; k <= 4; k++) {
        final f = k / 4, y = f * tall, out = lean * f * f;
        final half = 0.0065 * (1 - f) + 0.0005;
        for (final side in [-1.0, 1.0]) {
          pos.addAll([x0 + ox * out + ax * half * side, y, z0 + oz * out + az * half * side]);
          nor.addAll([-az, 0.3, ax]);
          uv.addAll([side < 0 ? 0 : 1, f]);
          col.addAll([tint * yellow, tint, tint * (yellow > 1 ? 0.7 : 1.0), 1]);
        }
      }
      for (var k = 0; k < 4; k++) {
        final i = base + 2 * k;
        idx.addAll([i, i + 2, i + 1, i + 1, i + 2, i + 3]);
      }
    }
    return geometryOf(
      MeshData(
        positions: Float32List.fromList(pos),
        vertexCount: pos.length ~/ 3,
        normals: Float32List.fromList(nor),
        texCoords: Float32List.fromList(uv),
        colors: Float32List.fromList(col),
        indices: idx,
      ),
    );
  }
}

/// A timing run (BOOTH3D_LAB_PERF=1): every 2 s, how long the frames took
/// on the UI thread (build: the lab's update, the widgets) and the raster
/// thread (the scene drawn), and the faces' repaints meanwhile. With it,
/// BOOTH3D_LAB_AUTOTYPE=1 types into the middle scroll, BOOTH3D_LAB_GRASS=0
/// leaves the meadow out, BOOTH3D_LAB_DOF=0 the depth of field. (Each a
/// dart-define, or the launch's environment.)
abstract final class _Perf {
  static String _flag(String name, String defined) => launchEnv(name) ?? defined;
  static final on = _flag('BOOTH3D_LAB_PERF', const String.fromEnvironment('BOOTH3D_LAB_PERF')) != '';
  static final autotype = _flag('BOOTH3D_LAB_AUTOTYPE', const String.fromEnvironment('BOOTH3D_LAB_AUTOTYPE')) != '';
  static final grass = _flag('BOOTH3D_LAB_GRASS', const String.fromEnvironment('BOOTH3D_LAB_GRASS')) != '0';
  static final dof = _flag('BOOTH3D_LAB_DOF', const String.fromEnvironment('BOOTH3D_LAB_DOF')) != '0';
  static final _build = <double>[], _raster = <double>[], _paints = <String>[];
  static var _started = false;
  static final _window = Stopwatch();

  static void start() {
    if (!on || _started) return;
    _started = true;
    _window.start();
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        _build.add(t.buildDuration.inMicroseconds / 1000);
        _raster.add(t.rasterDuration.inMicroseconds / 1000);
      }
      if (_window.elapsedMilliseconds < 2000) return;
      String stats(List<double> v) {
        final s = [...v]..sort();
        return 'p50 ${s[s.length ~/ 2].toStringAsFixed(1)} p90 ${s[(s.length * 0.9).floor()].toStringAsFixed(1)} max ${s.last.toStringAsFixed(1)}';
      }

      if (_build.isNotEmpty) {
        // ignore: avoid_print
        print('PERF ${(_build.length / (_window.elapsedMilliseconds / 1000)).toStringAsFixed(1)} fps · build ${stats(_build)} · raster ${stats(_raster)} ms${_paints.isEmpty ? '' : ' · paints ${_paints.join(', ')}'}');
      }
      _build.clear();
      _raster.clear();
      _paints.clear();
      _window.reset();
    });
  }

  static void paint(String what) {
    if (on) _paints.add(what);
  }
}
