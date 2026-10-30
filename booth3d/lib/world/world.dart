import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:text_slides/booth/web_fonts.dart';
import 'package:text_slides/booth/model.dart';
import 'package:text_slides/booth/ui/booth_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../perf.dart' show PerfLog;
import '../talk/talk.dart';
import '../talk/talk_sections.dart';
import '../tuning.dart';
import 'city.dart';
import 'city_signs.dart' show CitySigns;
import 'dashes.dart' show Dashes;
import 'delivery.dart' show Delivery3D;
import 'devices.dart' show deviceRoots;
import 'director.dart';
import 'figure.dart' show Figures;
import 'figure_rig.dart' show FigureMotion;
import 'ease.dart' show approach, smooth;
import 'kit.dart' show lerp;
import 'life.dart';
import 'lineup.dart';
import 'icu_dashes.dart';
import 'horizon.dart';
import 'landmarks.dart';
import 'outskirts.dart';
import 'physics.dart';
import 'script_alley.dart' show ScriptAlley;
import 'site.dart';
import 'v_archive.dart';
import 'v_desk.dart' show DeskScene;
import 'v_package.dart' show PackageTown;
import 'v_scrolls.dart' show ScrollLine;
import 'sky.dart';
import 'typing.dart';
import 'glyph_works.dart' show WorksLayout;
import 'site_plan.dart' show SiteLayout;
import 'volume.dart';

/// 名前の街 · Name City: the whole 3D world, driven by the booth model.
class World3D {
  final scene = Scene();
  late final city = City3D(scene);
  late final outskirts = Outskirts(scene);
  late final icuDashes = IcuDashes(scene);
  late final landmarks = Landmarks(scene);
  late final horizon = Horizon(scene);
  late final sky = Sky3D(scene);
  late final site = Site3D(scene);
  late final typing = Typing3D(scene);
  late final life = Life3D(scene);
  final director = Director();

  /// The talk, told here (talk/talk.dart): its sections, in the deck's
  /// order.
  late final talk = Talk(director, talkSections(site))
    // (The questions' demo starts as its first delivery sets off: the
    // truck coming in, then the build.)
    ..askReady = ((start) => Delivery3D.firstArrival(start) <= start + 11.001 && Delivery3D.firstArrival(start + 0.2) <= start + 11.201)
    // (The slide it opens on is on the desk's laptop.)
    ..slideCorners = (() => _desk.corners);
  late final _desk = site.vignettes.byName('desk')! as DeskScene;

  /// The talk's vertical text stop's washing line (v_scrolls.dart), and
  /// whether the talk's at it (its writing to select, the middle scroll to
  /// type into: main.dart puts scroll_typing.dart over the canvas).
  late final scrollLine = site.vignettes.byName('scrolls')! as ScrollLine;
  bool get scrollsOn => ready && talk.on && !talk.questions && talk.section.stops[talk.stop] == 'scrolls';

  /// Typing into it: the keys its editor's, not the talk's.
  bool get typingScroll => ready && scrollLine.scrolls.editorFocused;
  late final _package = site.vignettes.byName('package') as PackageTown?;

  /// The presenter's pointer while it's pressed ([at], px in the [size]
  /// the scene's shown at), or null as it lifts: a hand on the text on a
  /// path's strip, while that's on (v_package.dart).
  void hand(Offset? at, Size size) {
    if (ready) _package?.hand(at, director.camera, size);
  }

  bool ready = false;
  bool _skipped = false;

  /// (Capture runs: people stood in a row to look at; see [Lineup].)
  Lineup? _lineup;

  /// What's being got ready, for the loading screen: 'fonts' (the web),
  /// 'city', 'people'; [ready] once done.
  final stage = ValueNotifier<String>('');

  Future<void> init() async {
    await Scene.initializeStaticResources();
    // (The people's sculpted parts, before anyone's made: the talk's
    // sections make the scenes' people as soon as they're asked for.)
    await Figures.load();
    scene.antiAliasingMode = Tuning.aa;
    scene.depthOfField
      ..quality = DepthOfFieldQuality.medium
      ..maxBackgroundBlur = 22
      ..maxForegroundBlur = 14;
    EnvironmentMap.radianceCubeSize = Tuning.cube;
    if (kIsWeb) {
      stage.value = 'fonts';
      await _warmUpFonts();
    }
    stage.value = 'city';
    await Physics.ensureReady();
    if (const String.fromEnvironment('BOOTH3D_TIMES') != '') debugPrint(Physics.selfTest());
    site.physics.warmUp();
    await sky.init();
    site.init();
    typing.init();
    await Future.wait([city.init(), site.alley.init(), site.vignettes.init()]);
    director.solids = city.towers.solids;
    await landmarks.init();
    city.towers.solids.addAll(landmarks.solids);
    if (Tuning.outskirts) {
      await horizon.init();
      city.towers.solids.addAll(horizon.solids);
      await outskirts.init(city.towers.solids);
    }
    await icuDashes.init();
    // (Dash, to drive the talk's finale's delivery.)
    final driver = Dashes(scene);
    await driver.build();
    site.delivery.dash = driver;
    // What the talk's flights keep out of (besides the city's blocks): the
    // Glyph Works' hall, in by its loading door; the crane's mast; the
    // scenes' buildings; the trees (over their crowns, not through them).
    talk.volumes = [
      Volume(
        vm.Vector3(WorksLayout.cx, WorksLayout.roof / 2, WorksLayout.cz),
        vm.Vector3((WorksLayout.x1 - WorksLayout.x0) / 2, WorksLayout.roof / 2, (WorksLayout.z1 - WorksLayout.z0) / 2),
        door: Door(vm.Vector3(WorksLayout.x1, 0, WorksLayout.doorZ), vm.Vector3(1, 0, 0), WorksLayout.doorW / 2, WorksLayout.doorH),
      ),
      Volume(vm.Vector3(SiteLayout.mastX, 9.5, SiteLayout.mastZ), vm.Vector3(1.4, 9.5, 1.4)),
      for (final v in site.vignettes.all) ...v.volumes,
      for (final (x, z, top, r) in city.props.trees) Volume(vm.Vector3(x, top / 2, z), vm.Vector3(r, top / 2, r), soft: true),
      ...outskirts.volumes,
    ];
    // The street furniture: everyone keeps out of it.
    Figures.of(scene).addFixed(city.props.solids);
    stage.value = 'people';
    await life.init();
    _lineup = Lineup.of(scene);
    // Every pipeline compiled behind the loading screen (the talk's devices
    // shown for it: their glass is a pipeline of its own), not the first
    // time something appears on stage.
    final hidden = [
      for (final n in deviceRoots)
        if (!n.visible) n,
    ];
    for (final n in hidden) {
      n.visible = true;
    }
    Figures.of(scene).prime(director.camera.target);
    await scene.warmUp([RenderView(camera: director.camera)], includeOffscreen: true);
    for (final n in hidden) {
      n.visible = false;
    }
    ready = true;
  }

  /// The web has no system CJK/Arabic/… fonts: Flutter downloads Noto
  /// fallbacks on first use. What's drawn once (the signs, the props' and
  /// the factory's lettering, the blueprint) needs every script it uses
  /// first, so fetch them all at once, in one wait (a cold page load takes
  /// a few seconds); names typed later wait for their own.
  Future<void> _warmUpFonts() async {
    const ja = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
        'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンー'
        '日目月高自門凸本字語名前田中山川東京漢'; // (names)
    const world = 'ب ع ا مرحبا ש שלום क ह नमस्ते ก สวัสดี 한 Ж Я Привет Ω λ Γεια σου ¶ Ⅲ ß ñ ♻ ♥';
    TextStyle style(String? locale) => TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 40, locale: locale == null ? null : Locale(locale));
    await awaitFallbackFontsAll(
      [
        (ja, style('ja')),
        (world, style(null)),
        ('你好', style('zh')),
        ('안녕', style('ko')),
        ...ScriptAlley.fontRuns,
        ...site.vignettes.fontRuns,
        ...CitySigns.fontRuns,
        // The talk's cards (in the UI's faces, Japanese forms for Han).
        (talk.allText, style('ja')),
      ],
      firstWait: const Duration(seconds: 4),
      quiet: const Duration(milliseconds: 700),
      max: const Duration(seconds: 15),
    );
  }

  /// The miniature's lens: its stop, and how soft what's twice as far as
  /// the focus is (half this share of the picture's height, as a blur's
  /// radius), whatever the distance.
  static const _fStop = 2.8, _miniature = 0.014;

  /// Call once per frame after stepping the model.
  void update(BoothModel m, double dt) {
    if (!ready) return;
    // Capture aid: --dart-define=BOOTH3D_SKIP_AT=<t> presses the operator's
    // skip at scene time t (to check what an interrupted build does).
    const skipAt = String.fromEnvironment('BOOTH3D_SKIP_AT');
    if (skipAt.isNotEmpty && !_skipped && m.t >= double.parse(skipAt)) {
      _skipped = true;
      m.skip();
    }
    // (A perf build says what took the time in a slow update.)
    final watch = PerfLog.enabled ? (Stopwatch()..start()) : null;
    final marks = watch == null ? null : <(String, int)>[];
    void mark(String what) => marks?.add((what, watch!.elapsedMicroseconds));

    FigureMotion.clock = m.t;
    // (The finale's delivery sets off as the talk hands over: the lights
    // moved on to let it, where that's safe, from the beat before (the
    // avenue then kept on green), so the press on to it needn't wait.)
    if (talk.askingSoon) TrafficLights.alignFor(m.t, from: 5.0, to: 13.4, at: 6.0);
    // (A talk sets the works' clock and the camera before the site goes.)
    talk.update(m.t, dt);
    _desk.shown = talk.slidePage;
    // Nothing built while the talk's on: a quiet plaza (the build under
    // way gone behind the slide it opens on). Then its finale: the thanks
    // built on the plaza from its start (as the city dips), a special
    // delivery from Dash, quickly, and kept, the camera on nothing else.
    m.hold = talk.on && !talk.questions;
    life.dashesOut = talk.on && !talk.questions;
    // (The finale's delivery has the streets to itself: the cars gone in
    // the dip, as the booth takes over.)
    life.carsOff = talk.on && talk.questions;
    m.finale = site.finale = talk.on && talk.questions;
    m.setShowcase(talk.questions ? Talk.thanks : null, now: true);
    // The talk's look comes in with it (and goes with it, as at its
    // questions, the booth's build on again behind them).
    final talking = talk.on && !talk.questions;
    sky.talk = dt <= 0 ? (talking ? 1.0 : 0.0) : approach(sky.talk, talking ? 1.0 : 0.0, dt, 0.5);
    final archive = site.vignettes.byName('archive') as UnicodeArchive?;
    director.mayGoUnder ??= archive?.mayGoUnder;
    sky
      ..underground = archive?.undergroundAt(director.camera.position) ?? 0
      ..update(m.t, dt);
    city.update(sky, m.t);
    mark('sky+city');
    site.fx
      ..night = sky.night
      ..begin();
    site.camera.setFrom(director.camera.position);
    site.cameraTarget.setFrom(director.camera.target);
    site.update(m, dt, night: sky.night);
    talk.caption();
    mark('site');
    city
      ..gate = math.max(site.delivery.gateOpen(m.t), site.verdict.gateOpen(m.t))
      ..bayGate = site.bayGateOpen(m.t);
    typing
      ..attach(BoothUi.of(m))
      ..update(m, dt, site.fx);
    site.fx.end();
    mark('typing+fx');
    director
      ..typingWeight = typing.weight
      ..night = sky.night
      ..update(m, dt, site);
    talk.framed();
    site.captionFor(m, director.shotLabel);
    // The site's people (the crew, the new manager's party on the
    // pavement, the driver): the crowd walks round them.
    final crew = site.crew.poses;
    final out = [
      for (var i = 0; i < crew.length; i++)
        if (crew[i].visible && crew[i].pos.y < 0.5) () {
          final (vx, vz) = site.crew.velocityOf(i);
          return (vm.Vector3(crew[i].pos.x + crew[i].nudgeX, 0, crew[i].pos.z + crew[i].nudgeZ), vx, vz);
        }(),
      for (final w in site.vignettes.kit.walkers) (w, 0.0, 0.0),
    ];
    mark('director');
    life.update(m, dt, camera: director.camera.position, wallWidth: site.wallWidth, night: sky.night, work: site.streetWork, others: out);
    icuDashes.update(m.t);
    landmarks.update();
    if (Tuning.outskirts) horizon.update(m.t);
    _lineup?.update(m.t);
    // Everyone's drawn: into the people's meshes, in full near the camera.
    Figures.of(scene).commit(director.camera.position);
    mark('life');
    if (watch != null && marks != null && watch.elapsedMicroseconds > 12000) {
      var last = 0;
      PerfLog.line('slow update at t=${m.t.toStringAsFixed(1)} (${m.job?.phase.name}): ${[
        for (final (w, at) in marks) () {
          final d = at - last;
          last = at;
          return '$w ${(d / 1000).toStringAsFixed(1)}';
        }(),
      ].join(', ')} ms');
    }
    // The lens. On the booth's build (the names going up on the plaza, the
    // thanks after the talk): a miniature's, as if the city were a model on
    // a table seen close up (a tilt-shift photograph's), as shallow at every
    // distance, what's in focus standing out, the rest soft before and
    // behind it; in close, a real lens's if that's shallower still. In the
    // talk: none, everything sharp (its crisp look, sky.dart).
    final mini = 1 - sky.talk;
    final c = talk.deepFocus ? 0.0 : math.max(director.closeness, sky.talk * 0.5 * smooth(48, 14, director.focus));
    final stop = lerp(lerp(16, 2.4, c), _fStop, mini);
    final dof = scene.depthOfField, f = 0.5 * dof.sensorHeight / math.tan(0.5 * director.camera.fovRadiansY);
    // (The blur a unit of 1 − focus/depth makes, of the picture's height.)
    final lens = (f / stop) * f / (math.max(director.focus, f * 1.01) - f) / dof.sensorHeight * 0.5;
    dof
      ..enabled = Tuning.dof && (c > 0.02 || mini > 0.02) && sky.talk < 0.5
      ..focusDistance = director.focus
      ..fStop = stop
      ..blurScale = math.max(1.0, mini * _miniature / lens);
  }
}
