import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/widgets.dart' show CustomPaint;
import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:fountain_pen/fountain_pen.dart' show homemadeApple;
import 'package:stroke_fx/stroke_fx.dart' show StrokeShaders, StrokeText, WrittenText;
import 'package:text_slides/deck/theme.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'devices.dart' show deviceScreen;
import 'grove.dart';
import 'hover_dash.dart';
import 'kit.dart';
import 'lamps.dart';
import 'live_screen.dart';
import 'package_fight.dart';
import 'package_path.dart';
import 'package_pen.dart';
import 'shapes.dart' show bevelBox;
import 'shot.dart';
import 'strip.dart';
import 'trim.dart';
import 'vignette.dart';

/// Package Town, where talk 06 is told: just east of Trade-off Town
/// (v_tradeoff.dart), a square round a crossing, three tall buildings on
/// its north side facing it. Each is a gap in Flutter's text that a small
/// package closes, without forking the engine, and shows the problem first
/// and, a press later, the fix:
///
/// * phrases (the west one): a giant screen, a Japanese sentence as
///   Text() breaks it, words split mid-phrase (red); at [_fixA]
///   KumihanText() unfolds beside it, the same sentence broken only
///   between its phrases (green: kumihan finds them with BudouX and glues
///   each with word joiners);
/// * punctuation (the middle one): 「こんにちは」「世界」。 as Text() sets
///   it, a whole em of blank where 」 meets 「 (each mark carries half); at
///   [_fixB] kumihan's row slides in below it, the font's halt taking one
///   half away;
/// * GPU text (the east one): the talk's word hangs in front of it
///   ([word]: v_word.dart's 'slug', its own turn), as a texture that blurs
///   close up, then from its outlines on the GPU (Slug), sharp;
/// * handwriting (a screen across the road, on the south-east block,
///   facing the square): a word written as a wipe would and as Tegaki
///   does, both uncovering the font; at [_penB] fountain_pen's row grows in
///   and all three write it again together (package_pen.dart);
/// * text on a path (its twin on the south-west block): a word on a strip
///   Dash pulls by a thread, one example a press ([_pathPress]): English,
///   English in cursive (the strip squeezed into a tight curve), then
///   Arabic, each letter turned whole as other packages do (fine in
///   English, the joins split in tight cursive and in Arabic); then Arabic
///   text_on_path's way, the joins closed, a rival Dash fighting Dash over
///   the strip (package_path.dart).
///
/// The layouts are Flutter's own (TextPainter), the marks measured on
/// them. Only a talk calls on it; the town stands there all along.
class PackageTown extends Vignette {
  PackageTown(super.kit);

  @override
  String get name => 'package';
  @override
  String get kick => 'UNSOLVED → SOLVED';
  @override
  String get line => 'Package Town: five gaps, five small fixes';
  @override
  String get note => 'each screen: the problem, then the fix';

  @override
  bool get talkOnly => true;

  @override
  double get loop => 96;
  @override
  double get visit => 12;

  /// The square's middle (world), the frame's origin, unturned (x east, z
  /// north).
  static final o = vm.Vector3(190, 0, -200);
  @override
  final frame = vm.Matrix4.translation(o);

  /// The three buildings on the square's north side: each one's bearing
  /// from its middle (degrees clockwise from north: their fronts face it),
  /// the radius to their fronts; their width, depth, height.
  static const _bearings = [-52.0, 0.0, 52.0];
  static const _r = 27.0, _bw = 18.0, _bd = 14.0;
  static const _heights = [30.0, 34.0, 30.0];

  /// The screens: their size, their middle's height, how far out from the
  /// front they hang; the band along their top.
  static const _sw = 14.0, _sh = 9.6, _sy = 10.3, _sz = -0.62, _band = 1.1;

  /// The east building's sign's height (above the Slug word's camera).
  static const _signY = 24.0;

  /// Where the screens' pictures go (m from a screen's middle): under the
  /// band, the phrases' two columns and the punctuation's two rows.
  static const _areaY = -0.55, _colX = 3.5, _colW = 6.6, _colH = 8.2, _rowW = 13.2, _rowH = 3.6, _rowDy = 1.9;

  /// When each fix comes (the scene's seconds): kumihan's column, its row.
  static const _fixA = 30.3, _fixB = 50.3;

  /// The handwriting screen's turn (the scene's seconds): from [_penA] the
  /// wipe and Tegaki's way write the word; at [_penB], all three, together.
  static const _penA = 60.0, _penB = 70.0;

  /// The handwriting screen's place: on the south-east block's front,
  /// facing the square (its −z), its middle's height.
  static final _penAt = trs(vm.Vector3(36, 0, -12), rotY: math.pi);
  static const _penY = 7.6;

  /// The text-on-a-path screen's turn: from [_pathA], its presses one from
  /// each of [_pathPress] (package_path.dart's, the last text_on_path's
  /// way). Its place: on the south-west block's front (a lower one: the
  /// screen a little lower too).
  static const _pathA = 80.0, _pathPress = [_pathA, 86.0, 92.0, 98.0];

  /// How long into each of its presses the strip's clock waits, come to
  /// afresh (the camera there first: the first press flies in, the others
  /// are there).
  static const _pathLead = [3.5, 0.6, 0.6, 0.6];
  static final _pathAt = trs(vm.Vector3(-36, 0, -12), rotY: math.pi);
  static const _pathY = 6.9;

  /// The rooftop's turn (stroke_fx's effects as fighters, on the south-west
  /// block's roof: package_fight.dart): a fighter a press, one from each of
  /// [_fightPress], in [fighters]' order; how long into its first press the
  /// first waits (the camera flying up).
  static const _fightA = 110.0, _fightPress = [_fightA, 118.0, 126.0, 134.0, 142.0, 150.0], _fightLead = 2.8;

  /// The block it's on ([_blocks]' index: its roof kept bare), its deck's
  /// top; the stage's middle (where each fighter lands); the billboard's
  /// size, its middle's height, its face's z (facing south, −z, over the
  /// street, the way the camera looks from).
  static const _arena = 4, _deckTop = 12.85;
  static final _stage = vm.Vector3(-36, _deckTop + 0.55, -21.5);
  static const _fbW = 14.0, _fbH = 6.0, _fbY = _deckTop + 6.4, _fbZ = -13.9;

  /// The fighters' size centre stage, and perched (on the billboard's top,
  /// each once it's landed: in a row this far apart, the first on the
  /// left); how long after landing a fighter hops up there; the lamps'
  /// places on the deck.
  static const _fighterSize = 4.0, _perchSize = 2.5, _perchGap = 2.5, _hopAt = 0.3;
  static const _lampsAt = [(-48.8, -27.0), (-23.2, -27.0), (-48.8, -15.2), (-23.2, -15.2)];

  /// The rooftop's camera: from over the street, the stage and the
  /// billboard (as a fighter comes on); square on to the billboard, close
  /// (its line being written: the billboard all but filling the frame, the
  /// perched fighters just out of its top). Closing in between [_closeIn]
  /// and [_closeAt] s after a press; pulled back over the first [_pullOut]
  /// s of the next.
  static final _wide = Shot(vm.Vector3(-35.2, 17.2, -36.5), vm.Vector3(-36, 17.9, -16.5), fov: 44, settle: 1.0, drift: 0.25);
  static final _close = Shot(vm.Vector3(-36, 18.15, -28.0), vm.Vector3(-36, 18.15, -14.0), fov: 34, settle: 1.0, drift: 0.08);
  static const _closeIn = 1.3, _closeAt = 2.4, _pullOut = 0.9;

  /// The roads' half width (along x through the square's south side, and
  /// an arm south); the town's paving.
  static const _road = 6.0, _paveX = 62.0, _paveZ0 = -62.0, _paveZ1 = 52.0;

  /// The town round the square: lower blocks (x0, z0, x1, z1, height).
  static const _blocks = [
    (-62.0, 12.0, -40.0, 44.0, 18.0),
    (40.0, 12.0, 62.0, 44.0, 20.0),
    (-32.0, 40.0, -12.0, 52.0, 24.0),
    (12.0, 40.0, 32.0, 52.0, 22.0),
    (-54.0, -30.0, -18.0, -12.0, 12.0),
    (18.0, -30.0, 54.0, -12.0, 14.0),
    (-60.0, -60.0, -30.0, -38.0, 9.0),
    (30.0, -60.0, 60.0, -38.0, 10.0),
  ];

  /// Building [k]'s frame in the town's: its front's middle on the ground,
  /// facing the square (its −z).
  static vm.Matrix4 _at(int k) {
    final b = _bearings[k] * math.pi / 180;
    return trs(vm.Vector3(_r * math.sin(b), 0, _r * math.cos(b)), rotY: b);
  }

  /// Where the talk's Slug word hangs (v_word.dart): in front of the east
  /// building, facing the square, at 0.6 of its size.
  static final word = () {
    final b = _bearings[2] * math.pi / 180;
    return trs(o + vm.Vector3(16 * math.sin(b), 0, 16 * math.cos(b)), rotY: b, s: vm.Vector3.all(0.6));
  }();

  /// Where building [k]'s pin goes on the talk's overview (world): over its
  /// screen (the east one's: on its sign).
  static vm.Vector3 pin(int k) => o + _at(k).transform3(vm.Vector3(0, k < 2 ? _sy + _sh / 2 + 1.0 : _signY, -0.6));

  late final Node _aPlain, _aGlued, _bPlain, _bHalt;
  final _penClock = ValueNotifier<(double, double, double)>((0, 0, 0));
  late final LiveScreen _penScreen;
  final _pathState = ValueNotifier<(int, double)>((0, 0));

  /// The rooftop: its billboard's fighter on now and the seconds since its
  /// press; the billboard; the fighters (a Dash each, in its colours); the
  /// press it's on, when that began, the scene's last time, the seconds
  /// since the press (the camera's clock too), whether it's on.
  final _fightState = ValueNotifier<(int, double)>((0, 0));
  late final LiveScreen _fightScreen;
  late final List<HoverDash> _fighters;
  int _fightBeat = -1;
  double _fightT0 = 0, _fightU = 0, _fightSince = 0;
  bool _fightOn = false;
  late final LiveScreen _pathScreen;
  late final Node _pathNode;

  /// The presenter's pointer on the text on a path's screen (its px) while
  /// it's pressed there ([hand]).
  Offset? _pathHand;

  /// The strip the word stands on (moved here, a frame at a time: the
  /// screen draws it as it is); Dash out in front pulling its thread, and
  /// on text_on_path's press its rival too; their threads ([_pieces] short
  /// lengths each, beak to knot); the strip's clock as the rival came.
  final _strip = PathBoard.arch();
  late final HoverDash _dash, _rival;
  late final InstancedMesh _thread, _rivalThread;
  late final Node _threadNode, _rivalThreadNode;
  static const _pieces = 24;
  double? _duel;

  /// Dash's size (its tuft some 1.95 m up), and how far it turns its face
  /// out from along the thread toward the camera (radians).
  static const _dashSize = 2.6, _faceOut = 0.6;

  /// The text on a path's press (0 each letter turned whole, 1
  /// text_on_path's), the clock time it began (its strip's clock: running on
  /// while the press is held), and the scene's last time (going back
  /// restarts it); whether its turn's on.
  int _pathBeat = -1;
  double _pathT0 = 0, _pathU = 0;
  bool _pathOn = false;
  bool _ready = false;

  @override
  List<(String, TextStyle)> get fontRuns => [
    (_phrases.join(), _ja.copyWith(fontSize: 112)),
    (_punct, _ja.copyWith(fontSize: 160)),
    ('PACKAGE TOWN small packages · no engine fork GPU TEXT PHRASE BREAKING PUNCTUATION SPACING breaks anywhere breaks between phrases 1 em ½ em', _ui.copyWith(fontSize: 40)),
    ('Text() KumihanText()', _ui.copyWith(fontFamily: BP.mono, fontSize: 40)),
    (PenBoard.word, const TextStyle(fontFamily: 'HomemadeApple', fontSize: 100)),
    ...PathBoard.fontRuns,
    ('HANDWRITING uncovers the text uncovers the font writes it wipe Tegaki fountain_pen', _ui.copyWith(fontSize: 40)),
  ];

  static const _ui = TextStyle(fontFamily: BP.display);

  /// Its buildings, for the talk's camera to fly round.
  @override
  late final volumes = [
    for (var k = 0; k < 3; k++) building(_bw, _bd, _heights[k] + (k == 1 ? 5.0 : 0), on: _at(k)),
    for (final (x0, z0, x1, z1, h) in _blocks) building(x1 - x0, z1 - z0, h, on: trs(vm.Vector3((x0 + x1) / 2, 0, z0))),
  ];

  @override
  Future<void> init() async {
    final b = Batch();
    final paving = await photoPbr('pavement'), asphalt = await photoPbr('asphalt');
    final faces = await Future.wait([photoPbr('facade_panel'), photoPbr('facade_glass'), photoPbr('facade_clad')]);
    final backs = await Future.wait([photoPbr('facade_stone'), photoPbr('facade_tile')]);
    final stone = pbr(rgb(1, 1, 1), roughness: 0.6), dark = pbr(rgb(1, 1, 1), roughness: 0.35, metallic: 0.2);
    _ground(b, paving, asphalt, stone);
    _buildings(b, faces, backs, stone, dark);
    _penFrame(b, stone, dark, _penAt, _penY);
    _penFrame(b, stone, dark, _pathAt, _pathY);
    _roof(b, dark);
    b.buildInto(shell, 'package town', castsShadows: false, lightChannelMask: 0x01);
    makePool(boxes: 4, cyls: 2, glows: 16);
    await Future.wait([_screens(), _signs(), _trees(), _lamps(), _penBoard(), _pathBoard(), _fightBoard()]);
    _ready = true;
  }

  // ── The town ──────────────────────────────────────────────────────────────

  /// The roads (a crossing striped for walking every way, a scramble), the
  /// pavements a curb up round them.
  void _ground(Batch b, Material paving, Material asphalt, Material stone) {
    const r = _road, x0 = -_paveX, x1 = _paveX, z0 = _paveZ0, z1 = _paveZ1;
    void slab(Material m, double ax, double az, double bx, double bz, double top) =>
        b.add(m, _laid(CuboidGeometry(vm.Vector3(bx - ax, 0.3, bz - az)).extractMeshData(), vm.Vector3((ax + bx) / 2, top - 0.15, (az + bz) / 2)).transformed(frame));
    slab(asphalt, x0, -r, x1, r, -0.06);
    slab(asphalt, -r, z0, r, -r, -0.06);
    slab(paving, x0, r, x1, z1, 0.06);
    slab(paving, x0, z0, -r, -r, 0.06);
    slab(paving, r, z0, x1, -r, 0.06);
    // A zebra over each arm (its bars along the traffic); two more across
    // the middle, corner to corner.
    final white = Vignette.c(0xE6E6DE);
    for (final s in [-1.0, 1.0]) {
      for (var z = -r + 0.75; z < r - 0.5; z += 0.9) {
        box(b, stone, 3.2, 0.012, 0.45, s * (r + 2.6), -0.054, z, white);
      }
    }
    for (var x = -r + 0.75; x < r - 0.5; x += 0.9) {
      box(b, stone, 0.45, 0.012, 3.2, x, -0.054, -(r + 2.6), white);
    }
    for (final (i, d) in [1.0, -1.0].indexed) {
      for (var t = -7.6; t <= 7.6; t += 0.9) {
        box(b, stone, 0.45, 0.012, 3.0, t * 0.7071 * d, -0.054 + 0.002 * i, t * 0.7071, white, yaw: -d * math.pi / 4);
      }
    }
  }

  /// The three tall buildings (two with a screen, the third's front the
  /// Slug word's backdrop), and the lower blocks round the square.
  void _buildings(Batch b, List<Material> faces, List<Material> backs, Material stone, Material dark) {
    for (var k = 0; k < 3; k++) {
      final m = frame * _at(k), h = _heights[k];
      void bx(Material mat, double w, double hh, double d, double x, double y, double z, int rgb) =>
          b.add(mat, painted(bevelBox(w, hh, d).transformed(m * trs(vm.Vector3(x, y, z))), v4(hex3(rgb))));
      b.add(faces[k], painted(_facade(_bw, h, _bd, ou: 0.3 * k, ov: 0.2 * k).transformed(m * trs(vm.Vector3(0, 0, _bd / 2))), vm.Vector4(1, 1, 1, 1)));
      // Its finish (trim.dart); a canopy over the way in.
      addTrim(b, stone, m * trs(vm.Vector3(0, 0, _bd / 2)), _bw, h, _bd, seed: 40 + k, glass: k == 1);
      bx(stone, 6.0, 0.25, 2.2, 0, 3.6, -1.0, 0x2A2F38);
      if (k == 2) continue;
      // The screen: a dark bezel on two brackets, black behind its pictures.
      bx(dark, _sw + 0.7, _sh + 0.7, 0.45, 0, _sy, -0.24, 0x1A1E25);
      bx(dark, _sw, _sh, 0.04, 0, _sy, _sz + 0.08, 0x05070B);
      for (final s in [-1.0, 1.0]) {
        bx(stone, 0.5, _sh * 0.8, 0.5, s * (_sw / 2 - 1.6), _sy, 0.0, 0x2A2F38);
      }
    }
    for (final (i, (x0, z0, x1, z1, h)) in _blocks.indexed) {
      final at = frame * trs(vm.Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2));
      b.add(backs[i % 2], painted(_facade(x1 - x0, h, z1 - z0, ou: 0.25 * i, ov: 0.375 * i).transformed(at), vm.Vector4(1, 1, 1, 1)));
      addTrim(b, stone, at, x1 - x0, h, z1 - z0, seed: 60 + i, kit: i != _arena);
    }
  }

  /// Street lights (lamps.dart) along the roads, their arms out over them,
  /// clear of the screens' views.
  Future<void> _lamps() async {
    final lamps = Lamps();
    await lamps.load(const [LampKind.tokyo]);
    const south = math.pi, west = -math.pi / 2, east = math.pi / 2;
    for (final (x, z, yaw) in const [
      (-14.0, -7.6, south),
      (14.0, -7.6, south),
      // (None at x ±36, south of the road: the handwriting screen's there,
      // and the text on a path's.)
      (-7.6, -16.0, west),
      (7.6, -16.0, east),
      (-36.0, 7.6, 0.0),
      (36.0, 7.6, 0.0),
    ]) {
      lamps.place(LampKind.tokyo, place(trs(vm.Vector3(x, 0, z), rotY: yaw)));
    }
    lamps.addTo(shell.add, 'package lamps');
  }

  /// The town's name on the middle building's roof (to the south, where
  /// the camera comes from), the east one's on its front.
  Future<void> _signs() async {
    final post = pbr(v4(hex3(0x4A4F57)), roughness: 0.5);
    final b1 = _at(1);
    for (final dx in [-7.0, 7.0]) {
      shell.add(
        Node(name: 'package sign post', mesh: Mesh(CuboidGeometry(vm.Vector3(0.3, 2.6, 0.3)), post), localTransform: place(b1 * trs(vm.Vector3(dx, _heights[1] + 1.3, 1.2))))..castsShadows = false,
      );
    }
    await Future.wait([
      sign(22.0, 3.8, b1 * trs(vm.Vector3(0, _heights[1] + 3.4, 1.0)), (c, s) {
        final r = Offset.zero & s;
        c
          ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s.height * 0.08)), Paint()..color = const Color(0xFF1B3A5C))
          ..drawRRect(
            RRect.fromRectAndRadius(r.deflate(s.height * 0.05), Radius.circular(s.height * 0.06)),
            Paint()
              ..color = const Color(0xFFF4F6F8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s.height * 0.025,
          );
        Vignette.text(c, 'PACKAGE TOWN', Rect.fromLTWH(0, s.height * 0.12, s.width, s.height * 0.5), s.height * 0.4, const Color(0xFFFFFFFF), weight: FontWeight.w800);
        Vignette.text(c, 'small packages · no engine fork', Rect.fromLTWH(0, s.height * 0.6, s.width, s.height * 0.26), s.height * 0.18, BP.amber, weight: FontWeight.w600);
      }, px: 1800, glow: 0.35, thick: 0.12, shell: true),
      sign(11.0, 2.4, _at(2) * trs(vm.Vector3(0, _signY, -0.3)), (c, s) {
        c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height * 0.1)), Paint()..color = const Color(0xFF16263D));
        Vignette.text(c, 'GPU TEXT', Rect.fromLTWH(0, s.height * 0.16, s.width, s.height * 0.68), s.height * 0.52, BP.amber, weight: FontWeight.w800);
      }, px: 1100, glow: 0.35, thick: 0.1, shell: true),
    ]);
  }

  /// Trees along the roads and round the blocks (none in front of a
  /// screen): keyaki, as down Omotesando (grove.dart).
  Future<void> _trees() async {
    final grove = Grove();
    await grove.load(const [TreeKind.zelkova, TreeKind.zelkovaB]);
    final spots = [
      // (None in front of the handwriting screen, nor its twin's.)
      for (var x = -56.0; x <= -20; x += 9)
        if (x < -50 || x > -25) (x, -9.4),
      for (var x = 20.0; x <= 56; x += 9)
        if (x < 25 || x > 50) (x, -9.4),
      for (var x = -58.0; x <= -40; x += 9) (x, 9.4),
      for (var x = 40.0; x <= 58; x += 9) (x, 9.4),
      for (var z = -56.0; z <= -36; z += 10) (-10.0, z),
      for (var z = -56.0; z <= -36; z += 10) (10.0, z),
    ];
    for (final (i, (x, z)) in spots.indexed) {
      grove.plant(
        i.isEven ? TreeKind.zelkova : TreeKind.zelkovaB,
        frame * trs(vm.Vector3(x, 0.06, z), rotY: rnd(i, 3) * 6, s: vm.Vector3.all(0.85 + 0.3 * rnd(i, 1))),
        shade: 0.92 + 0.14 * rnd(i, 4),
      );
    }
    grove.addTo(shell.add, 'package trees');
  }

  // ── The handwriting screen ────────────────────────────────────────────────

  /// A bezel on a block's front ([at], its middle [y] up), black behind
  /// the picture, on two brackets (the handwriting screen's, the text on a
  /// path's).
  void _penFrame(Batch b, Material stone, Material dark, vm.Matrix4 at, double y) {
    final m = frame * at;
    void bx(Material mat, double w, double hh, double d, double x, double y, double z, int rgb) =>
        b.add(mat, painted(bevelBox(w, hh, d).transformed(m * trs(vm.Vector3(x, y, z))), v4(hex3(rgb))));
    bx(dark, _sw + 0.7, _sh + 0.7, 0.45, 0, y, -0.24, 0x1A1E25);
    bx(dark, _sw, _sh, 0.04, 0, y, _sz + 0.08, 0x05070B);
    for (final s in [-1.0, 1.0]) {
      bx(stone, 0.5, _sh * 0.8, 0.5, s * (_sw / 2 - 1.6), y, 0.0, 0x2A2F38);
    }
  }

  /// Its picture: painted live (package_pen.dart) while its turn's on.
  Future<void> _penBoard() async {
    final dark = await paintedTexture(4, 4, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = _ground0));
    final mat = deviceScreen(dark);
    detail.add(Node(name: 'package handwriting screen', mesh: Mesh(boardGeometry(_sw, _sh, thick: 0.02), mat), localTransform: place(_penAt * trs(vm.Vector3(0, _penY, _sz))))..castsShadows = false);
    _penScreen = LiveScreen(PenBoard.w, PenBoard.h, CustomPaint(painter: PenBoard(_penClock)), pixelRatio: kIsWeb ? 0.7 : 1.3)..show(mat);
  }

  /// The text on a path's picture: text_on_path's own widget, live while
  /// its turn's on (package_path.dart).
  Future<void> _pathBoard() async {
    final dark = await paintedTexture(4, 4, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = _ground0));
    final mat = deviceScreen(dark);
    _pathNode = Node(name: 'package path screen', mesh: Mesh(boardGeometry(_sw, _sh, thick: 0.02), mat), localTransform: place(_pathAt * trs(vm.Vector3(0, _pathY, _sz))))..castsShadows = false;
    detail.add(_pathNode);
    _pathScreen = LiveScreen(PathBoard.w, PathBoard.h, PathBoard(_strip, _pathState), pixelRatio: kIsWeb ? 0.7 : 1.3)..show(mat);
    // Dash and its rival, and their threads, out in front of it while its
    // turn's on.
    _dash = HoverDash(detail);
    _rival = HoverDash(detail, rival: true);
    await Future.wait([_dash.build(), _rival.build()]);
    final piece = CylinderGeometry(bottomRadius: 1, topRadius: 1, height: 1, radialSegments: 8, bottomCap: false, topCap: false);
    (InstancedMesh, Node) thread(String name, Color colour) {
      final c = v4(lin3(colour));
      final m = InstancedMesh(geometry: piece, material: pbr(c, roughness: 0.6, emissive: c, emissiveStrength: 0.5));
      for (var i = 0; i < _pieces; i++) {
        m.addInstance(vm.Matrix4.diagonal3Values(0, 0, 0));
      }
      final n = Node(name: name)
        ..castsShadows = false
        ..visible = false
        ..addComponent(InstancedMeshComponent(m));
      detail.add(n);
      return (m, n);
    }

    final (dashes, dashesNode) = thread('package path thread', PathBoard.thread);
    final (rivals, rivalsNode) = thread('package path rival thread', PathBoard.rivalThread);
    _thread = dashes;
    _threadNode = dashesNode;
    _rivalThread = rivals;
    _rivalThreadNode = rivalsNode;
  }

  /// Dash (and its rival, once it's come) and their threads where the strip
  /// has them.
  void _poseDashes(double t) {
    _poseDash(_dash, _strip.beak, _strip.pull, _thread, t);
    final r = _strip.rival;
    _rival.visible = r != null;
    _rivalThreadNode.visible = r != null && _strip.rivalTied;
    if (r != null) _poseDash(_rival, r, _strip.rivalPull, _strip.rivalTied ? _rivalThread : null, t);
  }

  /// A Dash and its thread: its beak ([beak]) out in front of the screen
  /// ([Strip.depth]) over its place on it, facing along the thread (turned
  /// out toward the camera: its face seen), leaning back and beating its
  /// wings wider as it pulls ([pull]); the thread from its beak to the
  /// knot, straight while taut, hanging in a curve while slack.
  void _poseDash(HoverDash dash, Offset beak, double pull, InstancedMesh? thread, double t) {
    final m = _pathNode.globalTransform, k = _sw / PathBoard.w;
    vm.Vector3 local(Offset px, double out) => vm.Vector3((px.dx / PathBoard.w - 0.5) * _sw, (0.5 - px.dy / PathBoard.h) * _sh, -0.01 - out);
    final tip = local(beak, Strip.depth * k), knot = local(_strip.band(_strip.tied), 0.004);
    // Its facing, in the screen's frame (−z out toward the camera).
    final across = vm.Vector2(knot.x - tip.x, knot.y - tip.y);
    final a = across.length < 1e-6 ? vm.Vector2(1, 0) : across.normalized();
    final f = vm.Vector3(a.x * math.cos(_faceOut), a.y * math.cos(_faceOut), -math.sin(_faceOut));
    final pitch = math.asin(f.y.clamp(-0.55, 0.55)) + 0.25 * pull, yaw = math.atan2(-f.x, -f.z);
    dash.pose(
      m.clone()
        ..translateByDouble(tip.x, tip.y, tip.z, 1)
        ..rotateY(yaw)
        ..rotateX(pitch)
        ..scaleByDouble(_dashSize, _dashSize, _dashSize, 1)
        ..translateByDouble(-HoverDash.beakTip.x, -HoverDash.beakTip.y, -HoverDash.beakTip.z, 1),
      t,
      pull,
    );
    if (thread == null) return;
    // The thread: a parabola as long as it is, hanging down between its
    // ends while slack (a straight line once they're as far apart).
    final p0 = m.transform3(knot), p1 = m.transform3(tip), span = p1 - p0;
    final len = Strip.thread * k, c = span.length;
    final sag = c < len ? math.sqrt(3 * c * (len - c) / 8) : 0.0;
    vm.Vector3 at(double s) => p0 + span * s - vm.Vector3(0, sag * 4 * s * (1 - s), 0);
    final up = vm.Vector3(0, 1, 0);
    for (var i = 0; i < _pieces; i++) {
      final a = at(i / _pieces), b = at((i + 1) / _pieces), d = b - a, l = d.length;
      final turn = l < 1e-6 ? vm.Quaternion.identity() : vm.Quaternion.fromTwoVectors(up, d / l);
      thread.setInstanceTransform(i, vm.Matrix4.compose((a + b) * 0.5, turn, vm.Vector3(0.022, l + 0.004, 0.022)));
    }
  }

  /// The presenter's pointer while it's pressed ([at], px in a [size] view
  /// through [camera]), or null as it lifts: on the text on a path's screen
  /// while its turn's on, a hand on its strip (where it meets the screen,
  /// in the screen's px; off the screen too, once it holds the strip).
  void hand(Offset? at, Camera camera, Size size) {
    if (at == null || !visited || !_pathOn) {
      _pathHand = null;
      return;
    }
    final on = _boardAt(at, camera, size);
    if (on != null) _pathHand = on;
  }

  /// Where [at] (px in a [size] view through [camera]) meets the text on a
  /// path's screen, in its px (null if it's behind the camera).
  Offset? _boardAt(Offset at, Camera camera, Size size) {
    final ray = camera.screenPointToRay(at, size);
    final inv = vm.Matrix4.inverted(_pathNode.globalTransform);
    final o = inv.transform3(ray.origin.clone()), d = inv.rotate3(ray.direction.clone());
    // (Its face: the board's front, half its thickness out.)
    final s = d.z.abs() < 1e-9 ? -1.0 : (-0.01 - o.z) / d.z;
    if (s < 0) return null;
    return Offset(((o.x + d.x * s) / _sw + 0.5) * PathBoard.w, (0.5 - (o.y + d.y * s) / _sh) * PathBoard.h);
  }

  // ── The rooftop ───────────────────────────────────────────────────────────

  /// The rooftop stage on the south-west block (its roof bare): a deck, the
  /// billboard's back on two legs at the deck's north side, a post at each
  /// corner for a lamp (the lamps, and the deck's lit edges, the pool's: in
  /// the fighter's colour).
  void _roof(Batch b, Material dark) {
    void bx(double sx, double sy, double sz, double x, double y, double z, int rgb) =>
        b.add(dark, painted(bevelBox(sx, sy, sz).transformed(frame * trs(vm.Vector3(x, y, z))), v4(hex3(rgb))));
    bx(27.0, 0.3, 13.0, -36, _deckTop - 0.15, -21.0, 0x1F232A);
    bx(27.4, 0.14, 13.4, -36, _deckTop - 0.32, -21.0, 0x3A404A);
    bx(_fbW + 0.6, _fbH + 0.6, 0.4, -36, _fbY, _fbZ + 0.32, 0x15181D);
    final foot = _fbY - _fbH / 2;
    for (final sx in [-1.0, 1.0]) {
      bx(0.45, foot - _deckTop, 0.45, -36 + sx * (_fbW / 2 - 1.6), (foot + _deckTop) / 2, _fbZ + 0.4, 0x2A2F38);
    }
    for (final (x, z) in _lampsAt) {
      bx(0.22, 3.2, 0.22, x, _deckTop + 1.6, z, 0x2A2F38);
    }
  }

  /// The billboard (package_fight.dart's FightBoard: each fighter's line
  /// written in its effect, in the hand fountain_pen's Latin is traced from)
  /// and the fighters, a Dash each in its effect's colours.
  Future<void> _fightBoard() async {
    await StrokeShaders.load();
    final texts = await Future.wait([for (final f in fighters) StrokeText.of(WrittenText(f.line, hand: homemadeApple, fontSize: 96, duration: 2.4))]);
    final effects = [for (final f in fighters) f.effect()];
    final dark = await paintedTexture(4, 4, (c, s) => c.drawRect(Offset.zero & s, Paint()..color = _ground0));
    final mat = deviceScreen(dark);
    detail.add(Node(name: 'package fight board', mesh: Mesh(boardGeometry(_fbW, _fbH, thick: 0.2), mat), localTransform: place(trs(vm.Vector3(-36, _fbY, _fbZ))))..castsShadows = false);
    // (As sharp as the screen when the camera's close: the billboard all
    // but fills it.)
    const ratio = kIsWeb ? 0.7 : 2.0;
    _fightScreen = LiveScreen(FightBoard.w, FightBoard.h, FightBoard(texts, effects, _fightState, pixelRatio: ratio), pixelRatio: ratio)..show(mat);
    _fighters = [for (final f in fighters) HoverDash(detail, colours: f.colours)];
    await Future.wait([for (final d in _fighters) d.build()]);
  }

  /// The rooftop, its turn on or not ([u] the scene's, [t] the clock): a
  /// fighter a press landing centre stage, then up to perch on the
  /// billboard behind (with those before it) as its line is written there;
  /// the stage's lamps and edges lit in its colour, flaring as it lands.
  /// (Only on a visit; come to afresh, or back a press, it comes on again.)
  void _poseRoof(double u, double t) {
    final on = visited && u > _fightA - 1;
    if (on && !_fightOn) _fightBeat = -1;
    _fightOn = on;
    var k = 0, since = 0.0;
    if (on) {
      k = math.max(0, _fightPress.lastIndexWhere((a) => u >= a));
      if (_fightBeat < 0 || k < _fightBeat || u < _fightU - 0.01) {
        _fightT0 = t - math.max(0.0, u - _fightPress[k]) + (k == 0 ? _fightLead : 0.6);
      } else if (k > _fightBeat) {
        _fightT0 = t - math.max(0.0, u - _fightPress[k]);
      }
      _fightBeat = k;
      _fightU = u;
      since = _fightSince = math.max(0.0, t - _fightT0);
      _fightState.value = (k, since);
      _fightScreen.capture();
    }
    for (final (i, d) in _fighters.indexed) {
      final shown = on && i <= k;
      d.visible = shown;
      if (!shown) continue;
      final (at, yaw, squash, s) = _fighterAt(i, k, since, t);
      final sx = s / math.sqrt(squash);
      d.pose(place(trs(at, rotY: yaw)) * vm.Matrix4.diagonal3Values(sx, s * squash, sx), t, i == k ? 0.6 : 0.2);
      d.glow = switch (fighters[i].sparkle) {
        Sparkle.embers => 0.85 + 0.15 * math.sin(t * 13) + 0.08 * math.sin(t * 31),
        Sparkle.zaps => 0.8 + 0.2 * math.sin(t * 17),
        _ => 1.0,
      };
      if (i == k) _sparkle(fighters[i].sparkle, at, s / _fighterSize, since, t);
    }
    // The lamps and the deck's edges: the fighter's colour (a dim white off
    // its turn), flaring as it lands.
    final c = on ? lin3(fighters[k].accent) : vm.Vector3(0.5, 0.52, 0.55);
    final flare = on && since > FightBoard.lands ? math.exp(-(since - FightBoard.lands) * 3) : 0.0;
    final g = v4(c * ((on ? 1.8 : 0.35) * (1 + 2.5 * flare)));
    for (final (x, z) in _lampsAt) {
      pglow(x, _deckTop + 3.35, z, 0.55, 0.36, 0.55, g);
    }
    for (final z in [-27.62, -14.38]) {
      pglow(-36, _deckTop + 0.03, z, 26.8, 0.07, 0.12, g);
    }
    for (final x in [-49.62, -22.38]) {
      pglow(x, _deckTop + 0.03, -21.0, 0.12, 0.07, 13.0, g);
    }
  }

  /// Fighter [i]'s place, yaw, squash (1 none; above 1 stretched up) and
  /// size, [since] s after fighter [k]'s press (the one on now): coming on
  /// the way its [Entry] says and landing centre stage; then hopping up to
  /// perch on the billboard's top, out of its line's way as it's written,
  /// in a row with those before it.
  (vm.Vector3, double, double, double) _fighterAt(int i, int k, double since, double t) {
    final land = FightBoard.lands, bob = vm.Vector3(0, 0.12 * math.sin(t * 2 * math.pi * 0.7 + i * 1.7), 0);
    final wobble = fighters[i].sparkle == Sparkle.bubbles ? 1 + 0.05 * math.sin(t * 2 * math.pi * 2.2) : 1.0;
    final perch = vm.Vector3(-36 + (i - (fighters.length - 1) / 2) * _perchGap, _fbY + _fbH / 2 + 0.35, _fbZ + 0.32) + bob * 0.5;
    if (i < k) return (perch, 0.0, wobble, _perchSize);
    final from = switch (fighters[i].entry) {
      Entry.sky => vm.Vector3(0, 12, 3),
      Entry.below => vm.Vector3(0, -9, -10),
      Entry.right => vm.Vector3(18, 2, 2),
      Entry.left => vm.Vector3(-18, 2, 2),
      Entry.drop => vm.Vector3(0, 14, 0),
    };
    if (since >= land) {
      // Landed: a hop as it touches down (a jelly's bounce), then up to its
      // perch.
      final a = since - land;
      final squash = fighters[i].entry == Entry.drop ? 1 - 0.32 * math.exp(-a * 4) * math.cos(a * 15) : 1 - 0.1 * math.exp(-a * 6) * math.cos(a * 12);
      final go = eio(seg(a, _hopAt, _hopAt + 0.6)), arc = vm.Vector3(0, 1.8 * math.sin(math.pi * go), 0);
      return (_mix(_stage + bob * smooth(0.0, 0.6, a), perch, go) + arc, 0.0, lerp(squash, 1.0, go) * wobble, lerp(_fighterSize, _perchSize, go));
    }
    final x = since / land;
    // Dropped: falling, faster and faster; the rest easing in, a turn on the way.
    final e = fighters[i].entry == Entry.drop ? x * x : 1 - math.pow(1 - x, 3).toDouble();
    final spin = switch (fighters[i].entry) {
      Entry.sky || Entry.below => 2 * math.pi * (1 - e),
      Entry.right => 0.5 * (1 - e),
      Entry.left => -0.5 * (1 - e),
      Entry.drop => 0.0,
    };
    final stretch = fighters[i].entry == Entry.drop ? 1 + 0.25 * x : 1.0;
    return (_stage + from * (1 - e), spin, stretch * wobble, _fighterSize);
  }

  static vm.Vector3 _mix(vm.Vector3 a, vm.Vector3 b, double t) => a + (b - a) * t;

  /// What flies round the fighter on now, at [c] (its frame's; [g] of its
  /// size on stage, the cloud shrinking with it as it perches), [since] s
  /// after its press: built from the clock each frame (the site's particle
  /// pools), and a ring of its sparks bursting out along the deck as it
  /// lands.
  void _sparkle(Sparkle s, vm.Vector3 c, double g, double since, double t) {
    final fx = kit.fx;
    vm.Vector3 at(double x, double y, double z) => world(c.x + x * g, c.y + y * g, c.z + z * g);
    switch (s) {
      case Sparkle.frost:
        // Glints drifting down round it, twinkling.
        for (var i = 0; i < 36; i++) {
          final ph = (t * 0.22 + rnd(i, 1)) % 1, a = rnd(i, 2) * 2 * math.pi + t * 0.3, r = 0.7 + 1.7 * rnd(i, 3);
          final p = at(math.cos(a) * r, 4.4 - 4.6 * ph, math.sin(a) * r), tw = 0.5 + 0.5 * math.sin(t * 9 + i);
          fx.spark(p.x, p.y, p.z, 0.012 + 0.03 * tw, vm.Vector4(0.7, 0.95, 1.3, 1), 5, 0, -0.5, 0);
        }
      case Sparkle.embers:
        // Embers rising off it, shrinking as they cool.
        for (var i = 0; i < 44; i++) {
          final ph = (t * 0.5 + rnd(i, 1)) % 1, a = rnd(i, 2) * 2 * math.pi, r = (0.3 + 1.1 * rnd(i, 3)) * (1 - 0.4 * ph);
          final p = at(math.cos(a + ph * 2) * r, 0.2 + 4.8 * ph, math.sin(a + ph * 2) * r);
          fx.spark(p.x, p.y, p.z, 0.05 * (1 - ph) + 0.008, vm.Vector4(1.0, 0.42 - 0.25 * ph, 0.08, 1), 7, 0, 1.8, 0);
        }
      case Sparkle.zaps:
        // Sparks zipping round it, pink and cyan.
        for (var i = 0; i < 26; i++) {
          final w = 2.6 + 2.2 * rnd(i, 1), a = t * w + rnd(i, 2) * 2 * math.pi, r = 1.4 + 0.6 * rnd(i, 3);
          final y = 0.4 + 2.0 * rnd(i, 4) + 0.3 * math.sin(t * 5 + i);
          final p = at(math.cos(a) * r, y, math.sin(a) * r);
          final pink = i.isEven;
          fx.spark(p.x, p.y, p.z, 0.035, pink ? vm.Vector4(1.0, 0.22, 0.85, 1) : vm.Vector4(0.25, 0.95, 1.1, 1), 8, -math.sin(a) * r * w, 0, math.cos(a) * r * w);
        }
      case Sparkle.leaves:
        // Leaves swirling down round it.
        for (var i = 0; i < 24; i++) {
          final ph = (t * 0.16 + rnd(i, 1)) % 1, a = rnd(i, 2) * 2 * math.pi + t * 0.7, r = 1.0 + 1.6 * rnd(i, 3);
          final p = at(math.cos(a) * r, 4.6 - 4.8 * ph, math.sin(a) * r);
          final green = vm.Vector4(0.08 + 0.1 * rnd(i, 4), 0.35 + 0.25 * rnd(i, 5), 0.06, 1);
          fx.confetti(p.x, p.y, p.z, t * 2 + i, t * 3 + i * 0.7, t * 1.3 + i, 0.18, green);
        }
      case Sparkle.bubbles:
        // Little jellies bobbing up round it.
        for (var i = 0; i < 18; i++) {
          final ph = (t * 0.2 + rnd(i, 1)) % 1, a = rnd(i, 2) * 2 * math.pi, r = 1.1 + 1.0 * rnd(i, 3);
          final p = at(math.cos(a) * r + 0.15 * math.sin(t * 3 + i), 0.3 + 4.0 * ph, math.sin(a) * r);
          final hue = vm.Vector4(0.55 + 0.4 * rnd(i, 4), 0.35 + 0.4 * rnd(i, 5), 0.9, 1);
          fx.pixel(p.x, p.y, p.z, 0.13 * (1 - 0.5 * ph), hue, glow: 1.6, spin: t * 2 + i);
        }
      case Sparkle.petals:
        // Petals drifting down over the stage, swaying.
        for (var i = 0; i < 48; i++) {
          final ph = (t * 0.12 + rnd(i, 1)) % 1;
          final x = -6 + 12 * rnd(i, 2) + 0.8 * math.sin(t * 1.3 + i), z = -2.5 + 5 * rnd(i, 3);
          final p = at(x, 6.5 - 7.0 * ph, z);
          final pink = vm.Vector4(1.0, 0.55 + 0.2 * rnd(i, 4), 0.7 + 0.15 * rnd(i, 5), 1);
          fx.confetti(p.x, p.y, p.z, t * 1.5 + i, math.sin(t * 2 + i) * 0.9, t * 2.2 + i, 0.14, pink);
        }
    }
    // Landing: a ring of its sparks bursting out along the deck (from where
    // it landed, as it's off to its perch).
    final a = since - FightBoard.lands;
    if (a > 0 && a < 0.7) {
      final colour = v4(lin3(fighters.firstWhere((f) => f.sparkle == s).accent) * 2.2);
      for (var i = 0; i < 28; i++) {
        final ang = i / 28 * 2 * math.pi, r = 0.5 + 5.5 * eo(a / 0.7);
        final p = world(_stage.x + math.cos(ang) * r, _stage.y + 0.15, _stage.z + math.sin(ang) * r * 0.6);
        fx.spark(p.x, p.y, p.z, 0.05 * (1 - a / 0.7), colour, 7, math.cos(ang) * 6, 0, math.sin(ang) * 3.6);
      }
    }
  }

  // ── The screens ───────────────────────────────────────────────────────────

  static const _ground0 = Color(0xFF0B1220), _ink = Color(0xFFF2F5FA);
  static const _red = Color(0xFFE8505F), _redInk = Color(0xFFFFC9CF), _green = Color(0xFF34C77B), _greenInk = Color(0xFFC6F6DA);
  static const _pad = 56.0, _px = 160.0;

  static const _ja = TextStyle(fontFamily: BP.display, locale: Locale('ja'));

  /// A sentence in its phrases (文節, as BudouX finds them).
  static const _phrases = ['今日は', '天気が', 'いいので、', '公園で', '友達と', '一緒に', 'お弁当を', '食べました。'];

  /// Two full-width marks meeting: 」 (at [_meet]) and 「.
  static const _punct = '「こんにちは」「世界」。';
  static const _meet = 6;

  Future<void> _screens() async {
    // The phrases: the type size at which Text() splits two of them at
    // least, and KumihanText() none, in a column's lines.
    final width = _colW * _px - 2 * _pad, room = _colH * _px - 236 - 40;
    final (size, split) = _phraseFit(width, room);
    final made = await Future.wait([
      _panel(_colW, _colH, (c, s) => _column(c, s, glued: false, size: size, split: split)),
      _panel(_colW, _colH, (c, s) => _column(c, s, glued: true, size: size, split: split)),
      _panel(_rowW, _rowH, (c, s) => _punctRow(c, s, halt: false)),
      _panel(_rowW, _rowH, (c, s) => _punctRow(c, s, halt: true)),
      _panel(_sw, _band, (c, s) => _bandPaint(c, s, 'PHRASE BREAKING')),
      _panel(_sw, _band, (c, s) => _bandPaint(c, s, 'PUNCTUATION SPACING')),
    ]);
    _aPlain = made[0];
    _aGlued = made[1];
    _bPlain = made[2];
    _bHalt = made[3];
    for (final k in [0, 1]) {
      made[4 + k].localTransform = place(_at(k) * trs(vm.Vector3(0, _sy + _sh / 2 - _band / 2, _sz)));
    }
  }

  /// A screen's picture, [w]×[h] m, painted at [_px] a metre and lit
  /// from within, as an LED wall is.
  Future<Node> _panel(double w, double h, void Function(Canvas c, Size s) paint) async {
    final tex = await paintedTexture((w * _px).round(), (h * _px).round(), paint);
    final mat = PhysicallyBasedMaterial()
      ..baseColorTexture = tex
      ..emissiveTexture = tex
      ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
      ..emissiveStrength = 0.9
      ..metallicFactor = 0
      ..roughnessFactor = 0.45;
    final n = Node(name: 'package screen', mesh: Mesh(boardGeometry(w, h, thick: 0.02), mat))..castsShadows = false;
    detail.add(n);
    return n;
  }

  /// The sentence's parts: its phrases, or ([glued]) each glued with word
  /// joiners (U+2060) between its letters, as KumihanText() sets it.
  static List<String> _parts(bool glued) => [for (final p in _phrases) glued ? p.split('').join('⁠') : p];

  /// Where each line of [parts] starts (an offset into them, joined) at
  /// [size] in [width] px.
  static List<int> _starts(List<String> parts, double size, double width) {
    final tp = TextPainter(
      text: TextSpan(text: parts.join(), style: _ja.copyWith(fontSize: size, height: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final out = [for (final m in tp.computeLineMetrics()) tp.getPositionForOffset(Offset(1, m.baseline - m.ascent + 1)).offset];
    tp.dispose();
    return out;
  }

  /// Which of [parts] a line starts inside of.
  static Set<int> _split(List<String> parts, List<int> starts) {
    final out = <int>{};
    var at = 0;
    for (final (k, p) in parts.indexed) {
      if (starts.any((s) => s > at && s < at + p.length)) out.add(k);
      at += p.length;
    }
    return out;
  }

  /// The largest of a few sizes at which, [width] px wide, Text() splits
  /// two phrases at least and KumihanText() none, in [room] px of lines;
  /// with the phrases Text() splits.
  static (double, Set<int>) _phraseFit(double width, double room) {
    for (final s in [120.0, 116.0, 112.0, 108.0, 104.0, 100.0, 96.0, 92.0]) {
      final plain = _split(_parts(false), _starts(_parts(false), s, width));
      final glued = _starts(_parts(true), s, width);
      if (plain.length >= 2 && _split(_parts(true), glued).isEmpty && glued.length * s * 1.5 <= room) return (s, plain);
    }
    return (92, _split(_parts(false), _starts(_parts(false), 92, width)));
  }

  /// A column: Text()'s sentence, the phrases it splits in red; or
  /// KumihanText()'s, the same phrases kept whole, in green.
  static void _column(Canvas c, Size s, {required bool glued, required double size, required Set<int> split}) {
    final accent = glued ? _green : _red;
    c.drawRect(Offset.zero & s, Paint()..color = _ground0);
    _label(c, glued ? 'KumihanText()' : 'Text()', const Offset(_pad, 78), 72, _ink, mono: true);
    _chip(c, glued ? 'breaks between phrases' : 'breaks anywhere', const Offset(_pad, 168), 42, accent);
    final mark = TextStyle(background: Paint()..color = accent.withValues(alpha: 0.34), color: glued ? _greenInk : _redInk);
    final tp = TextPainter(
      text: TextSpan(
        style: _ja.copyWith(fontSize: size, height: 1.5, color: _ink),
        children: [for (final (k, p) in _parts(glued).indexed) TextSpan(text: p, style: split.contains(k) ? mark : null)],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width - 2 * _pad);
    tp.paint(c, const Offset(_pad, 236));
    tp.dispose();
  }

  /// Whether the font's 'halt' (half-width alternates) narrows 」 at
  /// [size]; if not, kumihan's half em is taken off by letter spacing.
  static bool _haltWorks(double size) {
    double width(TextStyle st) {
      final tp = TextPainter(text: TextSpan(text: '」', style: st), textDirection: TextDirection.ltr)..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    final base = _ja.copyWith(fontSize: size);
    return width(base.copyWith(fontFeatures: const [FontFeature('halt')])) < width(base) * 0.75;
  }

  /// A row: Text()'s 「こんにちは」「世界」。, a whole em of blank where 」
  /// meets 「 (amber); or ([halt]) kumihan's, half an em taken off there
  /// (green). The blank's shaded, measured under it.
  static void _punctRow(Canvas c, Size s, {required bool halt}) {
    const size = 160.0, x0 = _pad, ty = 128.0;
    final accent = halt ? _green : BP.amber;
    c.drawRect(Offset.zero & s, Paint()..color = _ground0);
    _label(c, halt ? 'KumihanText()' : 'Text()', const Offset(_pad, 62), 64, _ink, mono: true);
    _chip(c, halt ? 'halt where 」「 meet' : 'half an em of blank in each mark', Offset(_pad + (halt ? 560 : 300), 62), 40, accent);
    final base = _ja.copyWith(fontSize: size, height: 1.2, color: _ink);
    final narrow = _haltWorks(size) ? base.copyWith(fontFeatures: const [FontFeature('halt')]) : base.copyWith(letterSpacing: -size / 2);
    final tp = TextPainter(
      text: halt
          ? TextSpan(
              style: base,
              children: [
                TextSpan(text: _punct.substring(0, _meet)),
                TextSpan(text: _punct.substring(_meet, _meet + 1), style: narrow),
                TextSpan(text: _punct.substring(_meet + 1)),
              ],
            )
          : TextSpan(text: _punct, style: base),
      textDirection: TextDirection.ltr,
    )..layout();
    final a = tp.getBoxesForSelection(const TextSelection(baseOffset: _meet, extentOffset: _meet + 1)).first;
    final b = tp.getBoxesForSelection(const TextSelection(baseOffset: _meet + 1, extentOffset: _meet + 2)).first;
    // (Each mark is half an em of ink and half of blank: the blank between
    // them runs from the middle of 」's box to the middle of 「's.)
    final g0 = x0 + a.left + size / 2, g1 = x0 + b.left + size / 2;
    c.drawRect(Rect.fromLTRB(g0, ty + size * 0.06, g1, ty + size * 1.14), Paint()..color = accent.withValues(alpha: 0.3));
    tp.paint(c, const Offset(x0, ty));
    tp.dispose();
    final my = ty + size * 1.2 + 34;
    final line = Paint()
      ..color = accent
      ..strokeWidth = 8;
    c
      ..drawLine(Offset(g0, my), Offset(g1, my), line)
      ..drawLine(Offset(g0, my - 16), Offset(g0, my + 16), line)
      ..drawLine(Offset(g1, my - 16), Offset(g1, my + 16), line);
    _label(c, halt ? '½ em' : '1 em', Offset(g1 + 28, my), 56, accent, mono: true, weight: FontWeight.w800);
  }

  /// A screen's band: what it's about.
  static void _bandPaint(Canvas c, Size s, String title) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF16263D));
    _label(c, title, Offset(_pad, s.height / 2), s.height * 0.52, BP.amber, weight: FontWeight.w800);
  }

  /// [text] at [at] (its left, the middle of its line).
  static void _label(Canvas c, String text, Offset at, double size, Color color, {bool mono = false, FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: mono ? BP.mono : BP.display, fontSize: size, color: color, fontWeight: weight, locale: const Locale('ja')),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx, at.dy - tp.height / 2));
    tp.dispose();
  }

  /// A rounded chip with [text] in [accent], its left middle at [at].
  static void _chip(Canvas c, String text, Offset at, double size, Color accent) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: BP.display, fontSize: size, color: accent, fontWeight: FontWeight.w700, locale: const Locale('ja')),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromLTWH(at.dx, at.dy - tp.height / 2 - size * 0.22, tp.width + size * 0.9, tp.height + size * 0.44);
    c
      ..drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), Paint()..color = accent.withValues(alpha: 0.16))
      ..drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)),
        Paint()
          ..color = accent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    tp.paint(c, Offset(at.dx + size * 0.45, at.dy - tp.height / 2));
    tp.dispose();
  }

  // ── Its turn ──────────────────────────────────────────────────────────────

  /// The screens [u] seconds in: Text()'s column in the middle of its
  /// screen until kumihan's fix, then moving aside as KumihanText()'s
  /// grows in beside it; Text()'s row likewise, kumihan's growing in under
  /// it. (On past the last fix, both stay fixed.)
  @override
  void pose(double u, double t, double night) {
    if (!_ready) return;
    final a = eio(seg(u, _fixA, _fixA + 1.0)), b = eio(seg(u, _fixB, _fixB + 1.0));
    _put(_aPlain, 0, -_colX * a, _areaY);
    _put(_aGlued, 0, _colX, _areaY, s: eo(seg(u, _fixA + 0.25, _fixA + 1.05)));
    _put(_bPlain, 1, 0, _areaY + _rowDy * b);
    _put(_bHalt, 1, 0, _areaY - _rowDy, s: eo(seg(u, _fixB + 0.25, _fixB + 1.05)));
    // The handwriting screen, while its turn's on (a capture paints it
    // whole): the first two rows writing from [_penA]; from [_penB] all
    // three, the pen's growing in.
    if (u > _penA - 1 && u < _penB + PenBoard.write + 3) {
      final again = u >= _penB;
      final tau = again ? u - _penB - 0.7 : u - _penA - 0.5;
      _penClock.value = (math.max(0.0, tau), again ? math.max(0.0, tau) : 0.0, eo(seg(u, _penB, _penB + 0.6)));
      _penScreen.capture();
    }
    // The text on a path's, while its turn's on: a press each from
    // [_pathPress], the strip going on from one to the next (the presenter's
    // hand on it too, if they take hold), squeezed into a tight curve on the
    // cursive's, the rival Dash flying in on text_on_path's. (Only on a
    // visit: a talk-only scene's clock runs on between them. Come to
    // afresh, or back a press, its strip starts again.)
    final on = visited && u > _pathA - 1 && u < _pathPress.last + 8;
    if (on && !_pathOn) _pathBeat = -1;
    _pathOn = on;
    _dash.visible = _pathOn;
    _threadNode.visible = _pathOn;
    if (!_pathOn) _rival.visible = _rivalThreadNode.visible = false;
    if (_pathOn) {
      final beat = math.max(0, _pathPress.lastIndexWhere((a) => u >= a));
      if (_pathBeat < 0 || beat < _pathBeat || u < _pathU - 0.01) {
        // Afresh (or back a press): the strip starts again once the
        // camera's there, the rival there from the start on text_on_path's.
        _pathT0 = t - math.max(0.0, u - _pathPress[beat]) + _pathLead[beat];
        _duel = beat == PathBoard.fix ? 0 : null;
      } else if (beat == PathBoard.fix && _duel == null) {
        // On to text_on_path's: the rival flies in, the strip going on.
        _duel = math.max(0.0, t - _pathT0);
      }
      _pathBeat = beat;
      _pathU = u;
      final clock = math.max(0.0, t - _pathT0);
      _strip.advanceTo(clock, hand: _pathHand, duel: _duel, squeeze: beat == PathBoard.tight);
      _pathState.value = (beat, clock);
      _poseDashes(t);
      _pathScreen.capture();
    }
    pool.begin();
    _poseRoof(u, t);
    pool.end();
  }

  /// [n] on screen [k], its middle at (x, y) of the screen's, [s] of its
  /// size (growing in from its middle).
  void _put(Node n, int k, double x, double y, {double s = 1}) {
    final g = math.max(s, 0.002);
    n
      ..visible = s > 0.002
      ..localTransform = place(_at(k) * trs(vm.Vector3(x, _sy + y, _sz)) * vm.Matrix4.diagonal3Values(g, g, 1));
  }

  // ── The camera ────────────────────────────────────────────────────────────

  /// The square from up the south road, level with the screens' tops, its
  /// three fronts facing it, the town's name over them (as the talk frames
  /// it, slid some 16 m west for its card: onto the road's middle) (to 15
  /// s); then square on to the phrases' screen, from the square (to 40 s);
  /// then the punctuation's.
  @override
  Shot shot(double u) {
    if (u < 15) {
      final k = eio(seg(u, 0, 10));
      return Shot(vm.Vector3(lerp(17.4, 15.6, k), lerp(15, 14, k), lerp(-50, -46, k)), vm.Vector3(0, 14, 22), fov: 46, settle: 1.0, drift: 0.6);
    }
    if (u >= _fightA) return _onRoof(u);
    if (u >= _pathA) return _onPath(u - _pathA);
    if (u >= _penA) return _onPen(u - _penA);
    return u < 40 ? _onScreen(0, u - 20) : _onScreen(1, u - 40);
  }

  /// Square on to the handwriting screen from the road, as to the others
  /// but nearer (its writing's finer) ([v] in).
  static Shot _onPen(double v) {
    final c = _penAt.transform3(vm.Vector3(0, _penY, _sz));
    final out = _penAt.transform3(vm.Vector3(0, _penY, _sz - 1)) - c;
    final eye = (c + out * lerp(17.6, 16.8, eio(seg(v, 0, 4))))..y = 5.8;
    return Shot(eye, c, fov: 46, settle: 1.0, drift: 0.3);
  }

  /// Square on to the text on a path's screen, as to the handwriting's
  /// ([v] in).
  static Shot _onPath(double v) {
    final c = _pathAt.transform3(vm.Vector3(0, _pathY, _sz));
    final out = _pathAt.transform3(vm.Vector3(0, _pathY, _sz - 1)) - c;
    final eye = (c + out * lerp(17.6, 16.8, eio(seg(v, 0, 4))))..y = 5.4;
    return Shot(eye, c, fov: 46, settle: 1.0, drift: 0.3);
  }

  /// The rooftop at [u]: the stage from the south, over the street, as each
  /// fighter comes on (the fighter in front, the billboard behind, those
  /// perched on it over that; after the first, pulled back from close);
  /// then closing in, square on to the billboard, as the fighter's off to
  /// its perch and its line is written. (On the fighters' clock while the
  /// press is on: the scene's own holds as the presenter talks.)
  Shot _onRoof(double u) {
    final k = math.max(0, _fightPress.lastIndexWhere((a) => u >= a));
    final s = _fightOn && k == _fightBeat ? _fightSince : u - _fightPress[k] - (k == 0 ? _fightLead : 0.0);
    final c = math.max(k == 0 ? 0.0 : 1 - eio(seg(s, 0, _pullOut)), eio(seg(s, _closeIn, _closeAt)));
    return Shot(
      _mix(_wide.eye, _close.eye, c),
      _mix(_wide.target, _close.target, c),
      fov: lerp(_wide.fov, _close.fov, c),
      settle: _wide.settle,
      drift: lerp(_wide.drift, _close.drift, c),
    );
  }

  /// Square on to screen [k] from the square, a little below its middle,
  /// easing in a metre over the first seconds of its turn ([v] in).
  static Shot _onScreen(int k, double v) {
    final m = _at(k);
    final c = m.transform3(vm.Vector3(0, _sy, _sz));
    final out = m.transform3(vm.Vector3(0, _sy, _sz - 1)) - c;
    final eye = (c + out * lerp(19.4, 18.5, eio(seg(v, 0, 4))))..y = 5.4;
    return Shot(eye, c, fov: 46, settle: 1.0, drift: 0.3);
  }

  // ── Building parts ────────────────────────────────────────────────────────

  /// [_facade] for the towns round about (v_tradeoff.dart's terraces).
  static MeshData facadeBox(double w, double h, double d, {double ou = 0, double ov = 0}) => _facade(w, h, d, ou: ou, ov: ov);

  /// A building [w]×[h]×[d] (its bottom middle at the origin) faced in a
  /// photographed facade, its windows at their real size: a texture holds
  /// 8×8 cells of 1.7 × 2.6 m (from [ou], [ov] into it); the roof plain.
  static MeshData _facade(double w, double h, double d, {double ou = 0, double ov = 0}) {
    const cw = 1.7 * 8, ch = 2.6 * 8;
    final pos = <double>[], nor = <double>[], uv = <double>[], idx = <int>[];
    void quad(vm.Vector3 o, vm.Vector3 u, vm.Vector3 v, vm.Vector3 n, double uw, double vh, {bool roof = false}) {
      final base = pos.length ~/ 3;
      for (final (a, c) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]) {
        final p = o + u * (a * uw) + v * (c * vh);
        pos.addAll([p.x, p.y, p.z]);
        nor.addAll([n.x, n.y, n.z]);
        uv.addAll(roof ? [0.004, 0.004] : [ou + a * uw / cw, ov + (1 - c) * vh / ch]);
      }
      if (u.cross(v).dot(n) > 0) {
        idx.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
      } else {
        idx.addAll([base, base + 2, base + 1, base, base + 3, base + 2]);
      }
    }

    final x0 = -w / 2, z0 = -d / 2;
    final ux = vm.Vector3(1, 0, 0), uy = vm.Vector3(0, 1, 0), uz = vm.Vector3(0, 0, 1);
    quad(vm.Vector3(x0, 0, z0), ux, uy, vm.Vector3(0, 0, -1), w, h);
    quad(vm.Vector3(-x0, 0, -z0), -ux, uy, vm.Vector3(0, 0, 1), w, h);
    quad(vm.Vector3(x0, 0, -z0), -uz, uy, vm.Vector3(-1, 0, 0), d, h);
    quad(vm.Vector3(-x0, 0, z0), uz, uy, vm.Vector3(1, 0, 0), d, h);
    quad(vm.Vector3(x0, h, z0), ux, uz, vm.Vector3(0, 1, 0), w, d, roof: true);
    return MeshData(positions: Float32List.fromList(pos), vertexCount: pos.length ~/ 3, normals: Float32List.fromList(nor), texCoords: Float32List.fromList(uv), indices: idx);
  }

  /// [d] (a slab) moved to [at] in the town's frame, its texture laid at
  /// 3 m a tile where it is in the world.
  static MeshData _laid(MeshData d, vm.Vector3 at) {
    final m = d.transformed(vm.Matrix4.translation(at));
    final uv = Float32List(m.vertexCount * 2);
    for (var i = 0; i < m.vertexCount; i++) {
      uv
        ..[i * 2] = (o.x + m.positions[i * 3]) / 3
        ..[i * 2 + 1] = (o.z + m.positions[i * 3 + 2]) / 3;
    }
    return painted(m, vm.Vector4(1, 1, 1, 1), uvs: uv);
  }
}
