import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:flutter_scene/scene.dart' as scene3d show RenderView, kRenderLayerAll;
import 'package:text_slides/booth/model.dart';
import 'package:text_slides/booth/platform.dart';
import 'package:text_slides/booth/ui/booth_ui.dart';
import 'package:text_slides/booth/ui/ink.dart' show UT;
import 'package:text_slides/deck/theme.dart';

import 'capture_stub.dart' if (dart.library.io) 'capture_io.dart';
import 'event_badge.dart';
import 'kern_chip.dart';
import 'lab/scroll_lab.dart';
import 'loading.dart';
import 'perf.dart';
import 'photo_chip.dart';
import 'picture_fx.dart';
import 'quality.dart';
import 'scene_chip.dart';
import 'talk/presentation.dart';
import 'talk/talk_overlay.dart';
import 'world/figure.dart' show Figures;
import 'tuning.dart';
import 'works_chip.dart';
import 'world/site.dart' show Site3D;
import 'world/live_screen.dart';
import 'world/scroll_typing.dart';
import 'world/site_plan.dart' show CityPace;
import 'world/world.dart';

/// 名前の街 · Name City — the conference booth's name builder in 3D.
///
///   flutter run -d macos                        (Flutter GPU is enabled in Info.plist)
///   --dart-define=BOOTH3D_TIMES=10,60,120       capture frames at scene times, then quit
///   --dart-define=BOOTH3D_NAMES=Ana,田中太郎      names typed at t=0 (capture)
///   --dart-define=BOOTH3D_PERF=true             log frame times, memory and scene size
///   --dart-define=BOOTH3D_SPEED=8               start fast-forwarded (as Ctrl+Shift+↑)
///   --dart-define=BOOTH3D_TALK=2,9,15           a capture's talk: started at 2, next at 9, 15, …
///   --dart-define=BOOTH3D_FPS=30                frames for a video: BOOTH3D_TIMES's ranges (12-15.5) every frame
///   --dart-define=BOOTH3D_SCALE=1.2             captures at 1.2× the 1600×900 canvas (1920×1080)
///   --dart-define=BOOTH3D_LIVELOG=1             live: log the camera's shots and the deliveries' plans
///   --dart-define=BOOTH3D_LAB=scrolls           a lab instead (lib/lab/scroll_lab.dart)
///
/// F5 (or Ctrl+Shift+T) tells the talk in the city, section by section:
/// → / PageDown / Space next, ← / PageUp back, Home / End the section's
/// first and last stop, 0–6 a section (0 the title), B or . to blank the
/// screen (any key back), Esc to leave it. To
/// open straight into it: on the Mac,
///   open -a "Name City" --env NAME_CITY_TALK=1      (or =05: at section 05;
///                                                  ="06/text on path": at that stop)
/// and on the web, the page with ?talk (or ?talk=05, ?talk=06/text%20on%20path).
///
/// F6 (or Ctrl+Shift+P) plays it as a presentation instead: the talk told
/// by itself in the presenter's recorded voice, 30 minutes from the title
/// to the thanks (talk/presentation.dart). Space pauses it, → and ← skip a
/// beat, Esc stops it. To open straight into it,
///   open -a "Name City" --env NAME_CITY_PRESENT=1   (the web: ?present)
void main() => runApp(_lab == 'scrolls' ? const ScrollLabApp() : const NameCityApp());

/// A lab instead of the city (lib/lab/): 'scrolls', the hanging scrolls.
const _lab = String.fromEnvironment('BOOTH3D_LAB');

const _times = String.fromEnvironment('BOOTH3D_TIMES');
const _names = String.fromEnvironment('BOOTH3D_NAMES');
const _tag = String.fromEnvironment('BOOTH3D_TAG', defaultValue: 'city');

/// Whether to open into the talk once the city's ready (see above); a build
/// can open into it by default (--dart-define=NAME_CITY_TALK=1: the slides
/// app for the conference's archive, tool/build_slides_app.sh).
String? get _talkAtLaunch {
  final q = Uri.base.queryParameters['talk'], env = launchEnv('NAME_CITY_TALK');
  return q ?? (env == null || env.isEmpty || env == '0' ? null : env) ?? (_talkByDefault.isEmpty ? null : _talkByDefault);
}

const _talkByDefault = String.fromEnvironment('NAME_CITY_TALK');

/// Whether to open into the presentation (see above).
bool get _presentAtLaunch {
  final env = launchEnv('NAME_CITY_PRESENT');
  return Uri.base.queryParameters.containsKey('present') || (env != null && env.isNotEmpty && env != '0');
}

/// Which version of the narration the presentation speaks
/// (tool/narration/variants.py): NAME_CITY_VOICE=deep|quick (talk.sh
/// --voice deep), the web's ?voice=deep; the talk's own if none.
String? get _voice {
  final v = Uri.base.queryParameters['voice'] ?? launchEnv('NAME_CITY_VOICE');
  return v == null || v.isEmpty || v == 'talk' ? null : v;
}

/// Perf aid: --dart-define=BOOTH3D_SILENT=true plays the presentation
/// without its voice (a perf run timing the whole talk, unheard).
const _silent = bool.fromEnvironment('BOOTH3D_SILENT');

/// Capture aid: --dart-define=BOOTH3D_PRESENT=3 starts the presentation at
/// scene time 3 (silent; its clock on the capture's).
const _presentAt = String.fromEnvironment('BOOTH3D_PRESENT');

/// Capture aid: --dart-define=BOOTH3D_FPS=30 reads BOOTH3D_TIMES's ranges
/// ("12-15.5") as a frame every 1/30 s between, for a video: saved in order
/// (f00001.png…), each drawn as the scene steps on to it (the settling a
/// still gets, its camera snapped to where it's going, only after a jump).
const _fps = int.fromEnvironment('BOOTH3D_FPS');

/// Capture aid: --dart-define=BOOTH3D_SCALE=1.2 captures at that many times
/// the 1600×900 canvas (1.2: 1920×1080), the scene drawn as sharp.
const _scale = String.fromEnvironment('BOOTH3D_SCALE');
final _scaleBy = _scale.isEmpty ? 1.0 : double.parse(_scale);

/// Capture aid: --dart-define=BOOTH3D_CAMLOG=true logs the camera at every
/// step while the talk's on (CAM t beat eye target fov), and the city's
/// solids once (SOLID centre half-extents): to check its moves (tools'
/// cammoves.py).
const _camLog = bool.fromEnvironment('BOOTH3D_CAMLOG');

class NameCityApp extends StatefulWidget {
  const NameCityApp({super.key});

  @override
  State<NameCityApp> createState() => _NameCityAppState();
}

class _NameCityAppState extends State<NameCityApp> with SingleTickerProviderStateMixin {
  final model = BoothModel();
  final world = World3D();
  final canvasKey = GlobalKey();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _speed = Tuning.speed;
  late final _perf = PerfLog.enabled ? PerfLog(world, model, ratio: () => _sceneRatio) : null;
  final _quality = RenderQuality(log: PerfLog.enabled ? PerfLog.line : null);
  final _watch = Stopwatch();
  bool get _capturing => _times.isNotEmpty;

  /// The scene's render ratio now (device pixels per canvas pixel).
  double get _sceneRatio => _capturing ? _scaleBy : Tuning.ratio ?? (_talkOn ? _quality.atLeast(_talkRatio) : _quality.ratio);

  late final presentation = Presentation(world.talk, silent: _capturing || _silent, voice: _voice);

  /// On the web, a presentation opened into waits for a click (a browser
  /// plays sound only once the page has had one).
  bool _gate = false;

  @override
  void initState() {
    super.initState();
    BoothUi.of(model).title = 'Name City'; // history, toasts, operator state
    model.pace = const CityPace(); // one letter at a time, with kerning
    HardwareKeyboard.instance.addHandler(_onKey);
    if (!_capturing) {
      BoothPlatform.keepAwake();
      if (!const bool.fromEnvironment('BOOTH_WINDOWED')) {
        WidgetsBinding.instance.addPostFrameCallback((_) => BoothPlatform.enterFullScreen());
      }
    }
    world.init().then((_) {
      if (!mounted) return;
      setState(() {});
      if (_capturing) {
        _capture();
      } else {
        _perf?.start();
        _quality
          ..attach()
          ..addListener(() => setState(() {}));
        world.talk.addListener(_talkTurned);
        _ticker = createTicker(_tick)..start();
        if (_presentAtLaunch) {
          if (kIsWeb) {
            setState(() => _gate = true);
          } else {
            _togglePresentation();
          }
        } else if (_talkAtLaunch case final at?) {
          _toggleTalk(at: at);
        }
      }
    });
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // (The presentation keeps time with its voice: the frame's real time.)
    presentation.update(math.min(dt, 0.5));
    dt = math.min(dt, 0.1) * _speed;
    final total = dt;
    while (dt > 0) {
      final step = math.min(dt, 1 / 30);
      model.update(step);
      dt -= step;
    }
    if (_perf case final perf?) {
      _watch
        ..reset()
        ..start();
      world.update(model, total);
      perf.frame(_watch.elapsedMicroseconds / 1000);
    } else {
      world.update(model, total);
    }
    // (The camera's shots as they're cut to, live: a capture's SHOT log.)
    if (_liveLog) {
      final d = world.director;
      if (d.shotLabel != _liveShot || d.cuts != _liveCuts) {
        // ignore: avoid_print
        print('LIVE ${model.t.toStringAsFixed(2)} ${d.cuts != _liveCuts ? 'cut  ' : 'glide'} ${model.job?.phase.name ?? '-'} · ${d.shotLabel} dip=${world.talk.dip.toStringAsFixed(2)}');
        _liveShot = d.shotLabel;
        _liveCuts = d.cuts;
      }
    }
  }

  static const _liveLog = String.fromEnvironment('BOOTH3D_LIVELOG') != '';
  String _liveShot = '';
  int _liveCuts = 0;

  /// Whether the talk's on, as the scene's resolution last took it.
  bool _talkOn = false;

  /// The talk's resolution: a 1080p projector's, for the 1600×900 canvas.
  static const _talkRatio = 1.2;

  void _talkTurned() {
    if (world.talk.on != _talkOn) setState(() => _talkOn = world.talk.on);
  }

  @override
  void dispose() {
    world.talk.removeListener(_talkTurned);
    presentation.stop();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker?.dispose();
    _quality.dispose();
    model.dispose();
    super.dispose();
  }

  /// Operator keys, as in the 2D booth (Ctrl+Shift+…); the talk's keys.
  /// (While the presenter types into the talk's scroll, none: they're its
  /// editor's, Esc to stop.)
  bool _onKey(KeyEvent e) {
    if (world.typingScroll) return false;
    final k = HardwareKeyboard.instance;
    if (_presentKey(e)) return true;
    if (_talkKey(e)) return true;
    if (!k.isControlPressed || !k.isShiftPressed || k.isAltPressed || k.isMetaPressed) return false;
    final ui = BoothUi.of(model);
    final key = e.logicalKey;
    final void Function() action;
    if (key == LogicalKeyboardKey.keyS) {
      action = ui.operatorSkip;
    } else if (key == LogicalKeyboardKey.backspace) {
      action = ui.operatorDropLast;
    } else if (key == LogicalKeyboardKey.keyF) {
      action = BoothPlatform.toggleFullScreen;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      action = () => ui.operatorSpeed(_speed = math.min(_speed * 2, 32));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      action = () => ui.operatorSpeed(_speed = math.max(_speed / 2, 1));
    } else if (key == LogicalKeyboardKey.keyH) {
      action = ui.toggleHelp;
    } else if (key == LogicalKeyboardKey.keyR) {
      action = ui.operatorReset;
    } else if (key == LogicalKeyboardKey.keyQ) {
      action = BoothPlatform.quit;
    } else if (key == LogicalKeyboardKey.keyT) {
      action = _toggleTalk;
    } else if (key == LogicalKeyboardKey.keyP) {
      action = _togglePresentation;
    } else {
      return false;
    }
    if (e is KeyDownEvent) action();
    return e is! KeyUpEvent;
  }

  /// F6 starts (or stops) the presentation; while it's on, Space pauses
  /// it, → and ← skip a beat, Esc stops it (the talk's other keys as ever).
  bool _presentKey(KeyEvent e) {
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.f6) {
      if (e is KeyDownEvent) _togglePresentation();
      return true;
    }
    if (_gate && e is KeyDownEvent) {
      _togglePresentation();
      return true;
    }
    if (!presentation.on || HardwareKeyboard.instance.isMetaPressed) return false;
    final void Function()? action = switch (key) {
      LogicalKeyboardKey.space => presentation.togglePause,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown || LogicalKeyboardKey.enter => presentation.next,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp || LogicalKeyboardKey.backspace => presentation.back,
      LogicalKeyboardKey.escape => presentation.stop,
      _ => null,
    };
    if (action == null) return false;
    if (e is KeyDownEvent) action();
    return true;
  }

  /// Starts the presentation from the title, or stops it.
  void _togglePresentation() {
    if (!world.ready) return;
    if (_gate) setState(() => _gate = false);
    if (presentation.on) {
      presentation.stop();
    } else {
      _speed = 1;
      presentation.start(world.director.camera);
    }
  }

  /// F5 starts (or ends) the talk; while it's on, the clicker's keys move
  /// along it. (Held keys don't repeat: one press, one stop.)
  bool _talkKey(KeyEvent e) {
    final key = e.logicalKey;
    final talk = world.talk;
    if (key == LogicalKeyboardKey.f5) {
      if (e is KeyDownEvent) _toggleTalk();
      return true;
    }
    if (!talk.on || HardwareKeyboard.instance.isMetaPressed) return false;
    // (The presentation's own keys: see above.)
    // A clicker's blank key (B, or .): the screen to navy and back. While
    // it's blank, the other keys only bring the talk back (Esc still ends
    // it).
    if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.period) {
      if (e is KeyDownEvent) talk.blank.value = !talk.blank.value;
      return true;
    }
    final void Function()? action = switch (key) {
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown || LogicalKeyboardKey.space || LogicalKeyboardKey.enter => talk.next,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp || LogicalKeyboardKey.backspace => talk.back,
      LogicalKeyboardKey.home => talk.first,
      LogicalKeyboardKey.end => talk.last,
      LogicalKeyboardKey.escape => talk.end,
      _ => switch (_digit(key)) {
        final d? => () => talk.jump(_sectionOf(d.toString().padLeft(2, '0'))),
        null => null,
      },
    };
    if (action == null) return false;
    if (e is KeyDownEvent) {
      if (talk.blank.value && action != talk.end) {
        talk.blank.value = false;
      } else {
        action();
      }
    }
    return true;
  }

  /// The digit [key] is (top row or keypad), or null.
  static int? _digit(LogicalKeyboardKey key) {
    for (var d = 0; d <= 9; d++) {
      if (key == LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d) || key == LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + d)) return d;
    }
    return null;
  }

  /// The talk's section numbered [n] ('05'); the first (the title) for
  /// '00' or none.
  int _sectionOf(String n) => world.talk.sections.indexWhere((s) => s.number == n).clamp(0, world.talk.sections.length - 1);

  /// Starts the talk (at section [at], '05'; else from the start), or ends
  /// it.
  void _toggleTalk({String? at}) {
    if (!world.ready) return;
    final talk = world.talk;
    if (presentation.on) {
      presentation.stop();
    } else if (talk.on) {
      talk.end();
    } else {
      // (At the booth's own pace.)
      _speed = 1;
      // (=1 or a bare ?talk: from the start; =05: at section 05; =06/text
      // on path: at that stop of 06.)
      final parts = (at ?? '').split('/');
      final from = parts.first.length < 2 ? 0 : _sectionOf(parts.first);
      talk.start(world.director.camera, at: from, stop: parts.length > 1 ? parts[1] : null);
    }
  }

  Future<void> _capture() async {
    final out = CaptureSink(_tag);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    model.update(1 / 30);
    for (final n in _names.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      model.submit(n);
    }
    final targets = [
      for (final s in _times.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty))
        if (_fps > 0 && s.indexOf('-', 1) > 0)
          for (var k = 0, a = double.parse(s.substring(0, s.indexOf('-', 1))), b = double.parse(s.substring(s.indexOf('-', 1) + 1)); a + k / _fps < b - 1e-6; k++) a + k / _fps
        else
          double.parse(s),
    ]..sort();
    if (_camLog) {
      for (final (c, h) in world.director.solids) {
        out.log('SOLID ${[c.x, c.y, c.z, h.x, h.y, h.z].map((v) => v.toStringAsFixed(2)).join(' ')}');
      }
    }
    // The shot list: every cut (or new shot glided to), as it happens.
    final d = world.director;
    var shot = '', cuts = 0;
    var presented = false;
    for (final (i, target) in targets.indexed) {
      Site3D.lookIndex = i;
      while (model.t < target) {
        final step = math.min(1 / 30, target - model.t + 1e-9);
        if (_presentAt.isNotEmpty && !presented && model.t >= double.parse(_presentAt)) {
          presented = true;
          await presentation.start(world.director.camera);
          out.log('PRESENT ${model.t.toStringAsFixed(2)} start: ${presentation.length.toStringAsFixed(1)} s');
        }
        final beat = world.talk.on ? world.talk.beatNumber : -1;
        presentation.update(step);
        model.update(step);
        world.update(model, step);
        if (_camLog && world.talk.on && !world.talk.questions) {
          final c = world.director.camera;
          String f(double v) => v.toStringAsFixed(3);
          out.log('CAM ${f(model.t)} ${world.talk.beatNumber} ${f(c.position.x)} ${f(c.position.y)} ${f(c.position.z)} '
              '${f(c.target.x)} ${f(c.target.y)} ${f(c.target.z)} ${f(c.fovRadiansY * 180 / math.pi)}');
        }
        if (presentation.on && world.talk.beatNumber != beat) {
          out.log('PRESENT ${model.t.toStringAsFixed(2)} beat ${world.talk.beatNumber} · ${world.talk.section.number} ${world.talk.section.stops[world.talk.stop]} (at ${presentation.elapsed.toStringAsFixed(1)} s)');
        }
        if (d.shotLabel != shot || d.cuts != cuts) {
          out.log('SHOT ${model.t.toStringAsFixed(2)} ${d.cuts != cuts ? 'cut  ' : 'glide'} ${model.job?.phase.name ?? '-'} · ${d.shotLabel}');
          shot = d.shotLabel;
          cuts = d.cuts;
        }
        if (model.pending case final p?) await p;
        // The Glyph Works' name (its atlas, its pixels) before going on.
        if (world.site.works.pending case final p?) await p;
        if (world.talk.pending case final p?) await p;
      }
      // Let the async letter meshes and the IBL bake catch up, then render
      // (a video's next frame: just drawn as it is, the scene stepped on to
      // it).
      final next = _fps > 0 && i > 0 && target - targets[i - 1] < 1.5 / _fps;
      for (var k = 0; k < (next ? 1 : 6); k++) {
        if (!next) world.update(model, 0);
        await WidgetsBinding.instance.endOfFrame;
        if (!next) await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      final boundary = canvasKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: _scaleBy);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final j = model.job;
      // Whole seconds as t0020; fractions keep two decimals (t0020.50).
      final stamp = target == target.roundToDouble() ? target.toStringAsFixed(0).padLeft(4, '0') : target.toStringAsFixed(2).padLeft(7, '0');
      final name = _fps > 0 ? 'f${(i + 1).toString().padLeft(5, '0')}.png' : 't${stamp}_${j?.phase.name ?? 'none'}.png';
      out
        ..save(name, png!.buffer.asUint8List())
        ..log('captured $name  (${j?.name} · ${j?.phase.name} ${(j?.progress(model.t) ?? 0).toStringAsFixed(2)} · ${world.director.shotLabel})');
    }
    out
      ..log(world.life.overlapReport())
      ..log(Figures.of(world.scene).overlapReport())
      ..finish();
  }

  /// The presenter's pointer, pressed, over [canvas]: a hand on whatever
  /// in the scene takes one (the text on a path's strip).
  Widget _hands(Widget canvas) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => world.hand(e.localPosition, BP.canvas),
    onPointerMove: (e) => world.hand(e.localPosition, BP.canvas),
    onPointerUp: (_) => world.hand(null, BP.canvas),
    onPointerCancel: (_) => world.hand(null, BP.canvas),
    child: canvas,
  );

  @override
  Widget build(BuildContext context) {
    // The canvas is scaled to fit the window: render no finer than it shows.
    final size = MediaQuery.sizeOf(context);
    _quality.screen(
      native: MediaQuery.devicePixelRatioOf(context) * math.min(size.width / BP.canvas.width, size.height / BP.canvas.height),
      refreshRate: View.of(context).display.refreshRate,
    );
    final view = world.ready
        ? SceneView(
            world.scene,
            // (Not the layer only shadows are cast from.)
            viewsBuilder: (_) => [scene3d.RenderView(camera: world.director.camera, layerMask: scene3d.kRenderLayerAll & ~Figures.shadowLayer)],
            pixelRatio: _sceneRatio,
          )
        : const ColoredBox(color: BP.bg);
    final canvas = SizedBox.fromSize(
      size: BP.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          view,
          // (The city's live screens' widgets: never shown here.)
          const LiveScreens(),
          PictureFx(model: model),
          // The booth's own on screen, unless the talk is on (over its
          // finale too: only the thanks, over the build).
          ListenableBuilder(
            listenable: world.talk,
            builder: (context, _) => world.talk.on
                ? const SizedBox.shrink()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      BoothOverlay(model: model),
                      KernChip(model: model, caption: world.site.kern.caption),
                      PhotoChip(model: model, cue: world.site.photo.cue),
                      SceneChip(model: model, caption: world.site.caption),
                    ],
                  ),
          ),
          // (Not in the talk, nor over its finale: its card says what the
          // works is doing, big enough for the room.)
          ListenableBuilder(
            listenable: world.talk,
            builder: (context, _) => world.talk.on
                ? const SizedBox.shrink()
                : WorksChip(model: model, caption: world.site.works.caption),
          ),
          TalkOverlay(talk: world.talk, animate: !_capturing),
          // The talk's vertical text stop: its scrolls' writing to select,
          // the middle one to type into (scroll_typing.dart); under the
          // presentation's pause and gate.
          ListenableBuilder(
            listenable: world.talk,
            builder: (context, _) => world.scrollsOn
                ? Positioned.fill(
                    child: ScrollTyping(scrolls: world.scrollLine.scrolls, camera: () => world.director.camera, canvas: BP.canvas),
                  )
                : const SizedBox.shrink(),
          ),
          // The presentation paused; on the web, waiting for its click.
          ListenableBuilder(
            listenable: presentation,
            builder: (context, _) => presentation.on && presentation.paused ? const _Paused() : const SizedBox.shrink(),
          ),
          if (_gate) _PresentGate(onStart: _togglePresentation),
          if (!_capturing) LoadingCurtain(stage: world.stage, ready: world.ready),
          ListenableBuilder(
            listenable: world.talk,
            builder: (context, _) => world.talk.on ? const SizedBox.shrink() : const EventBadge(),
          ),
        ],
      ),
    );
    return MaterialApp(
      title: 'Name City',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BP.bg,
        textSelectionTheme: TextSelectionThemeData(cursorColor: BP.amber, selectionColor: BP.line.withValues(alpha: 0.35)),
      ),
      home: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: BP.display, fontSize: 16, color: BP.ink),
          child: ColoredBox(
            color: BP.bg,
            child: Center(
              child: FittedBox(child: RepaintBoundary(key: canvasKey, child: _hands(canvas))),
            ),
          ),
        ),
      ),
    );
  }
}

/// The presentation paused: a quiet note at the bottom.
class _Paused extends StatelessWidget {
  const _Paused();

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, 0.9),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: BP.panel.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BP.line.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Text('❚❚  paused · space to carry on', style: UT.mono(15, color: BP.ink, weight: 500, ls: 1.2)),
      ),
    ),
  );
}

/// The web's presentation, opened into: a click (or a key) starts it, so
/// the browser lets it speak.
class _PresentGate extends StatelessWidget {
  const _PresentGate({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onStart,
    child: ColoredBox(
      color: BP.bg.withValues(alpha: 0.55),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BP.panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BP.amber.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('▶  Play the talk', style: UT.name(44, color: BP.ink, weight: 600)),
                const SizedBox(height: 10),
                Text('narrated · 30 minutes · click to start', style: UT.mono(15, color: BP.inkDim, weight: 500, ls: 1.2)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
