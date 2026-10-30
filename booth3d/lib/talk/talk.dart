import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:vector_math/vector_math.dart' as vm;

import '../world/director.dart';
import '../world/ease.dart';
import '../world/shot.dart';
import '../world/volume.dart';
import 'flight.dart';
import 'talk_section.dart';

/// The talk, told in the city instead of on slides: each press of the
/// clicker flies the camera to the next stop of a section (the deck's
/// sections, in order), where the city shows it, and a card beside it says
/// what happens there.
///
/// Sections (talk_section.dart) bring their stops, the camera's beats, the
/// cards and what they do to the world while they're on. Next goes on to
/// the next beat, from a section's last beat to the next section; back cuts
/// to the beat before, as it was left. The booth carries on round it all:
/// names are built on the plaza, the crowd walks by.
class Talk extends ChangeNotifier {
  Talk(this.director, this.sections);

  final Director director;
  final List<TalkSection> sections;

  bool get on => _on;
  bool _on = false;

  /// The section and the beat (of its beats) on screen, how long it's been
  /// on.
  int _section = 0, _beat = 0;
  double _age = 0;

  /// The last of the opening's slides shown over the whole canvas (the one
  /// on the laptop the camera then pulls back from; not one the
  /// presentation passed over).
  int _page = 0;

  /// The camera when the beat started (flown from there), the beat's own
  /// framing (once known), the camera this frame; the flight there (null:
  /// not worked out yet).
  Shot? _from, _to, _cam;
  Flight? _flight;

  /// How the camera was moving, the frame before (its eye, metres a
  /// second; its turn round and up or down, radians a second), and as a
  /// press caught it: carried on into the next flight, dying away (a
  /// press mid-flight doesn't stop it dead).
  final _vel = vm.Vector3.zero(), _carry = vm.Vector3.zero();
  double _yawRate = 0, _pitchRate = 0, _carryYaw = 0, _carryPitch = 0;
  Shot? _was2;

  /// What the camera keeps out of as it flies, and the rooms it goes into
  /// and out of by their doors (set by the world; the city's own blocks
  /// and towers too, from the director's solids).
  List<Volume> volumes = const [];
  List<Volume>? _volumes;

  /// A step back (Back, Home, End): a quick flight there, the scene shown
  /// as it ends, the card at once.
  bool _back = false;

  /// A scene's own camera as the talk follows it: eased after it (its
  /// cuts, made for the booth's director, become quick moves).
  vm.Vector3? _liveEye, _liveTarget;
  double _liveFov = 0;

  /// Counts frames while the talk's on (what's pinned to the city follows
  /// the camera).
  final frame = ValueNotifier<int>(0);

  /// The screen blanked (a clicker's blank key), the talk held behind it.
  final blank = ValueNotifier<bool>(false);

  TalkSection get section => sections[_section];
  int get sectionIndex => _section;

  /// The beat on screen, of the section's (for the talk's progress).
  int get beatIndex => _beat;

  /// The beat on screen, counted through the whole talk (the
  /// presentation's narration has a clip a beat).
  int get beatNumber {
    var n = _beat;
    for (var i = 0; i < _section; i++) {
      n += sections[i].beats.length;
    }
    return n;
  }
  TalkBeat get _now => section.beats[_beat];

  /// Beat [n], counted through the whole talk; how many there are.
  TalkBeat beatAt(int n) {
    for (final s in sections) {
      if (n < s.beats.length) return s.beats[n];
      n -= s.beats.length;
    }
    return sections.last.beats.last;
  }

  int get beatCount => sections.fold(0, (a, s) => a + s.beats.length);

  /// Whether the beat's card is up yet (a beat may hold it back until the
  /// camera's on its way down).
  bool get cardShown => _on && (_from == null || _back || _age >= _now.cardAt);

  /// Whether what a card holds back until [at] (seconds into the beat) is
  /// out: all of it at once when the beat's come back to (its scene cut to
  /// its end).
  bool shown(double at) => _on && (_back || _from == null || _age >= at);

  /// Whether the chapter's title is up (a chapter's beat, its card not yet,
  /// for as long as it's to stay; not over the questions).
  bool get chapter => _on && _now.chapter && !cardShown && !questions && (_now.chapterFor == null || _age < _now.chapterFor!);
  bool _cardWas = false, _chapterWas = false, _readyWas = true;

  /// The word the booth builds behind the questions: the thanks, in
  /// Japanese.
  static const thanks = 'ありがとう';

  /// The questions (the beat's [TalkBeat.questions] seconds in, or at a
  /// press): the city dips through the deck's navy and comes back as the
  /// booth's own demo, [thanks] built from its start by the director's
  /// camera, behind the thanks. When they may begin (the beat's age; null:
  /// not on this beat), whether they were pressed on to, and when the dip
  /// began (null: not yet).
  double? _askAt, _dipAt;
  bool _askPressed = false;

  /// Whether the demo would start well at [start] (scene time): its first
  /// delivery on its way at once. The dip waits for it up to [_askWait]
  /// seconds (a press doesn't).
  bool Function(double start)? askReady;
  static const _askWait = 30.0;

  /// Over to the booth (from the dip at its darkest: the change is hidden
  /// in it).
  bool get questions => _on && _dipAt != null && _age >= _dipAt! + _dipDown;

  /// On a beat that hands over to the booth, not yet dipping: waiting for
  /// its demo to start well ([askReady]).
  bool get asking => _on && _askAt != null && _dipAt == null;

  /// [asking], or on the beat before one that will: the time to get the
  /// demo's start ready (so the press on to it needn't wait).
  bool get askingSoon => asking || (_on && _dipAt == null && _beat + 1 < section.beats.length && section.beats[_beat + 1].questions != null);

  /// How dark the dip is (0..1): down, held while the booth starts the
  /// word, then up on its demo.
  double get dip {
    final a = _dipAt;
    if (!_on || a == null || _age < a) return 0;
    final u = _age - a;
    return u < _dipDown ? smooth(0, _dipDown, u) : 1 - smooth(_dipDown + _dipHold, _dipDown + _dipHold + _dipUp, u);
  }

  static const _dipDown = 0.7, _dipHold = 0.9, _dipUp = 1.3;

  /// Up out of the ground (the archive's hall, its ceiling half a metre
  /// under the street): dark as the camera goes through it (0..1).
  double get underDip {
    final f = _flight, c = _cam;
    if (!_on || f == null || c == null || f.from.eye.y > -0.2) return 0;
    final y = c.eye.y;
    return smooth(-1.7, -0.6, y) * (1 - smooth(0.4, 1.5, y));
  }

  /// The presenter's slide over the picture now (title_slide.dart), and
  /// where the laptop's screen it's on is in the city (its corners, as
  /// Laptop3D.corners: set by the world).
  Slide get slide => _on && !questions ? _now.slide : Slide.none;

  /// Which of the opening's slides it is (intro_slides.dart; on the
  /// laptop, the last shown over the whole canvas: the title if the
  /// presentation passed the others over), and how long it's been up: its
  /// sketches drawn in that far (all of them at once, stepped back to).
  int get slidePage => !_on ? 0 : (_now.slide == Slide.full ? _now.page : _page);
  double get slideAge => _back ? double.infinity : _age;

  /// Everything in focus: the opening, the camera pulling back from the
  /// slide on the laptop to the whole city (a shallow lens there would
  /// smear the city behind it).
  bool get deepFocus => slide != Slide.none;
  List<vm.Vector3> Function()? slideCorners;

  /// The stop on screen (of [section]'s), its card, and the beat within it
  /// (of how many).
  int get stop => _now.stop;
  TalkCard get card => section.card(stop);
  int get beat => _beat - section.beats.indexWhere((b) => b.stop == stop);
  int get beats => section.beats.where((b) => b.stop == stop).length;

  /// Got ready (the capture waits for it).
  Future<void>? get pending => _on ? section.pending : null;

  /// Every word the talk's cards and pins show (the web's fonts for them
  /// fetched before it starts, not as tofu halfway through).
  String get allText => [
    for (final s in sections) ...[
      s.title,
      for (var i = 0; i < s.stops.length; i++) ...() {
        final c = s.card(i);
        return [
          c.kicker,
          c.title,
          c.lede,
          for (final f in c.facts)
            switch (f) {
              FactRow(:final label, :final value, :final example) => '$label $value ${example ?? ''}',
              FactTable(:final columns, :final rows) => [...columns, for (final r in rows) ...r].join(' '),
              FactCode(:final code) => code,
              FactScale(:final left, :final right, :final points) => '$left $right ${points.map((p) => p.$1).join(' ')}',
              FactLetters(:final label, :final cells) => '$label ${cells.map((c) => '${c.$1} ${c.$2}').join(' ')}',
            },
        ];
      }(),
      for (final b in s.beats)
        for (final p in b.pins) p.name,
    ],
  ].join(' ');

  /// Starts the talk at section [at]'s first stop (or its stop called
  /// [stop], if it has one), the camera flown there from [from] (where it
  /// is).
  void start(PerspectiveCamera from, {int at = 0, String? stop}) {
    if (_on) return;
    _on = true;
    _page = 0;
    _section = at.clamp(0, sections.length - 1);
    _vel.setZero();
    _yawRate = _pitchRate = 0;
    _was2 = null;
    // (From the top: down out of the sky onto the title.)
    _cam = _section == 0 ? _sky : Shot(from.position.clone(), from.target.clone(), fov: from.fovRadiansY * 180 / math.pi);
    section.enter();
    final b = stop == null ? -1 : section.beats.indexWhere((x) => section.stops[x.stop].toLowerCase() == stop.toLowerCase());
    _go(_section, math.max(0, b));
  }

  /// Ends the talk: the camera goes back to the director, the world to the
  /// booth.
  void end() {
    if (!_on) return;
    _on = false;
    blank.value = false;
    section.leave();
    director.talkShot = null;
    notifyListeners();
  }

  /// The next beat, flown to (from a section's last, the next section);
  /// on the thanks, the questions now.
  void next() {
    if (!_on) return;
    if (_askAt case final a? when _dipAt == null) {
      _askAt = math.min(a, _age);
      _askPressed = true;
    } else if (_beat < section.beats.length - 1) {
      _go(_section, _beat + 1);
    } else if (_section < sections.length - 1) {
      _go(_section + 1, 0);
    }
  }

  /// The beat before, as it was left (a quick flight back).
  void back() {
    if (!_on) return;
    if (_beat > 0) {
      _go(_section, _beat - 1, back: true);
    } else if (_section > 0) {
      _go(_section - 1, sections[_section - 1].beats.length - 1, back: true);
    }
  }

  /// This section's first beat, or its last, as left (a quick flight).
  void first() {
    if (_on) _go(_section, 0, back: true);
  }

  void last() {
    if (_on) _go(_section, section.beats.length - 1, back: true);
  }

  /// Section [i]'s first beat, flown to.
  void jump(int i) {
    if (_on && i >= 0 && i < sections.length) _go(i, 0);
  }

  void _go(int s, int b, {bool back = false}) {
    // (Back from the questions: from where the booth's camera is.)
    final wasAsking = questions;
    if (questions) {
      final c = director.camera;
      _cam = Shot(c.position.clone(), c.target.clone(), fov: c.fovRadiansY * 180 / math.pi);
    }
    if (s != _section) {
      section.leave();
      _section = s;
      section.enter();
    }
    _beat = b;
    _age = 0;
    _askAt = _now.questions;
    _dipAt = null;
    _askPressed = false;
    _to = null;
    _flight = null;
    _liveEye = _liveTarget = null;
    // From where the camera is now (mid-flight, if it is), as it's moving
    // (not from the booth's camera, nor onto the slide: that's at once).
    _from = _cam;
    final carry = !wasAsking && _now.slide != Slide.full;
    _carry.setFrom(carry ? _vel : vm.Vector3.zero());
    _carryYaw = carry ? _yawRate : 0;
    _carryPitch = carry ? _pitchRate : 0;
    _back = back;
    section.arrive(b, cut: back);
    notifyListeners();
  }

  /// Advances the talk [dt] seconds (at scene time [t]): the section's
  /// world, the camera. Call before the site's update.
  void update(double t, double dt) {
    _script(t);
    if (!_on) return;
    _age += dt;
    // (A slide over the whole canvas a frame at least: not one passed over.)
    if (_now.slide == Slide.full) _page = _now.page;
    // (The section ready, its card's values with it, as the works' measured
    // word: shown again.)
    final ready = section.pending == null;
    if (cardShown != _cardWas || chapter != _chapterWas || ready != _readyWas) {
      _cardWas = cardShown;
      _chapterWas = chapter;
      _readyWas = ready;
      notifyListeners();
    }
    section.update(_beat, _age, t, dt);
    final ask = _askAt;
    if (_dipAt == null && ask != null && _age >= ask && (_askPressed || _age >= ask + _askWait || (askReady?.call(t + _dipDown) ?? true))) {
      _dipAt = _age;
      section.questions();
    }
    if (questions) {
      // Over to the booth: its director has the camera (cutting, in the
      // dip, to where its demo starts).
      if (director.talkShot != null) {
        director
          ..talkShot = null
          ..cutNext = true;
        notifyListeners();
      }
      return;
    }
    final b = _now;
    var to = b.live == null ? _to ??= _framed(b.shot, b.shift, b.pull) : _live(_framed(b.live!(), b.shift, b.pull), dt);
    final from = _from;
    // (Worked out as it sets off, from where the camera is to where it's
    // going; a step back, quickly. The slide: at once, behind it.)
    final flight = from == null
        ? null
        : _flight ??= Flight(
            from,
            to,
            _volumes ??= [for (final (c, h) in director.solids) Volume(c, h), ...volumes],
            fly: b.fly,
            back: _back,
            cut: b.slide == Slide.full,
          );
    final u = flight == null || flight.time <= 0 ? 1.0 : seg(_age, 0, flight.time);
    if (u >= 1 && b.live == null) {
      // Held: creeping in a little while it's on (a frame that breathes).
      final k = 0.04 * eo(seg(_age - (flight?.time ?? 0), 0, 30));
      to = Shot(to.eye + (to.target - to.eye) * k, to.target, fov: to.fov, settle: to.settle, drift: to.drift);
    }
    _cam = _carried(u >= 1 ? to : flight!.at(u, to));
    _moving(dt);
    if (_logCuts) _cutCheck(t, dt);
    director
      ..talkShot = _cam
      ..talkLabel = 'talk ${section.number} ${section.stops[stop]}${beats > 1 ? ' ${beat + 1}' : ''}';
  }

  /// [s] with how the camera was moving as the beat began, carried on and
  /// dying away (gone in a second or so).
  Shot _carried(Shot s) {
    const tau = 0.32;
    final k = _age * math.exp(-_age / tau);
    if (k < 1e-4 || (_carry.length2 < 1e-6 && _carryYaw.abs() + _carryPitch.abs() < 1e-4)) return s;
    final d = s.target - s.eye, far = d.length;
    final yaw = math.atan2(d.x, d.z) + _carryYaw * k, pitch = (math.asin((d.y / far).clamp(-1.0, 1.0)) + _carryPitch * k).clamp(-1.5, 1.5);
    final eye = s.eye + _carry * k;
    return Shot(eye, eye + vm.Vector3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * far, fov: s.fov, settle: s.settle, drift: s.drift);
  }

  /// How the camera's moving this frame (from the last).
  void _moving(double dt) {
    final now = _cam, was = _was2;
    _was2 = now;
    if (now == null || was == null || dt <= 1e-4) return;
    // (A jump, the camera handed over: no speed to carry.)
    if ((now.eye - was.eye).length / dt > 250) {
      _vel.setZero();
      _yawRate = _pitchRate = 0;
      return;
    }
    _vel.setFrom((now.eye - was.eye) / dt);
    double yawOf(Shot s) => math.atan2(s.target.x - s.eye.x, s.target.z - s.eye.z);
    double pitchOf(Shot s) => math.asin(((s.target.y - s.eye.y) / (s.target - s.eye).length).clamp(-1.0, 1.0));
    var dy = yawOf(now) - yawOf(was);
    dy -= 2 * math.pi * ((dy + math.pi) / (2 * math.pi)).floorToDouble();
    _yawRate = dy / dt;
    _pitchRate = (pitchOf(now) - pitchOf(was)) / dt;
  }

  /// Capture aid (a capture build): a hard cut logged with the beat it's
  /// in — the camera jumping (or turning, or zooming) in one frame several
  /// times as far as it did the frame before (a fast flight speeds up
  /// smoothly; a cut doesn't).
  static const _logCuts = String.fromEnvironment('BOOTH3D_TIMES') != '';
  Shot? _was;
  double _wasMove = 0, _wasTurn = 0;

  void _cutCheck(double t, double dt) {
    final was = _was, now = _cam!;
    _was = now;
    if (was == null || dt <= 0) return;
    final move = (now.eye - was.eye).length;
    final a = (was.target - was.eye).normalized(), b = (now.target - now.eye).normalized();
    final turn = math.acos(a.dot(b).clamp(-1.0, 1.0)) * 180 / math.pi;
    final zoom = (now.fov - was.fov).abs();
    if ((move > 0.8 && move > 4 * _wasMove + 0.4) || (turn > 5 && turn > 4 * _wasTurn + 2) || zoom > 3) {
      debugPrint('CUT t=${t.toStringAsFixed(2)} talk ${section.number} ${section.stops[stop]} beat $_beat age ${_age.toStringAsFixed(2)}: '
          '${move.toStringAsFixed(2)} m (was ${_wasMove.toStringAsFixed(2)}), ${turn.toStringAsFixed(1)}° (was ${_wasTurn.toStringAsFixed(1)}), '
          'fov ${zoom.toStringAsFixed(1)}°${_back ? ' (back)' : ''}');
    }
    _wasMove = move;
    _wasTurn = turn;
  }

  /// [s], a scene's own camera this frame, eased after: within a quarter
  /// second as it moves on, its cuts turned into quick moves.
  Shot _live(Shot s, double dt) {
    final eye = _liveEye, target = _liveTarget;
    if (eye == null || target == null || dt <= 0) {
      _liveEye = s.eye.clone();
      _liveTarget = s.target.clone();
      _liveFov = s.fov;
    } else {
      final k = 1 - math.exp(-dt / 0.25);
      eye.add((s.eye - eye) * k);
      target.add((s.target - target) * k);
      _liveFov += (s.fov - _liveFov) * k;
    }
    return Shot(_liveEye!.clone(), _liveTarget!.clone(), fov: _liveFov, settle: s.settle, drift: s.drift);
  }

  /// After the site's update (the captions it clears).
  void caption() {
    if (_on && _dipAt == null) section.caption(_beat, _age);
  }

  /// After the director's update (the camera this frame is known).
  void framed() {
    if (_on) frame.value++;
  }

  /// What's named in the city now, and how far it's shown (0..1): once
  /// the camera's (nearly) there.
  List<TalkPin> get pins => _on ? _now.pins : const [];
  double get pinsShown {
    if (!_on) return 0;
    final from = _from == null ? 0.0 : _now.pinsAt ?? (_flight?.time ?? _now.fly) * 0.85;
    return seg(_age, from, from + 0.6);
  }

  /// Seconds since the names began to come up (steps come one by one).
  double get pinsAge {
    if (!_on) return 0;
    final from = _from == null ? 0.0 : _now.pinsAt ?? (_flight?.time ?? _now.fly) * 0.85;
    return _age - from;
  }

  /// Where [p] is on the canvas (1600×900) through the camera this frame;
  /// null behind it.
  Offset? project(vm.Vector3 p) {
    final cam = director.camera;
    final f = (cam.target - cam.position)..normalize();
    final right = vm.Vector3(0, 1, 0).cross(f)..normalize();
    final up = f.cross(right);
    final d = p - cam.position;
    final z = d.dot(f);
    if (z < 0.1) return null;
    final ty = math.tan(cam.fovRadiansY / 2), tx = ty * 16 / 9;
    return Offset((0.5 + 0.5 * d.dot(right) / (z * tx)) * 1600, (0.5 - 0.5 * d.dot(up) / (z * ty)) * 900);
  }

  /// Where the talk starts from the top: high over the city, from beyond
  /// the avenue.
  static final _sky = Shot(vm.Vector3(0, 150, -230), vm.Vector3(0, 35, 60), fov: 46, drift: 0.6);

  /// [shot] pulled back [pull] times from what it looks at, then with what
  /// it looks at moved right of the middle by [shift] of the half width
  /// (the card's on the left): the camera slid left, square to its view.
  static Shot _framed(Shot shot, double shift, double pull) {
    // (Pulled back from what it looks at, by [pull]: room for all of it.)
    final s = pull == 1 ? shot : Shot(shot.target + (shot.eye - shot.target) * pull, shot.target, fov: shot.fov, settle: shot.settle, drift: shot.drift);
    final f = s.target - s.eye;
    final d = f.length;
    final right = vm.Vector3(0, 1, 0).cross(f)..normalize();
    final slide = shift * d * math.tan(s.fov * math.pi / 360) * 16 / 9;
    final by = right * -slide;
    return Shot(s.eye + by, s.target + by, fov: s.fov, settle: s.settle, drift: s.drift);
  }

  // ── A capture's script ────────────────────────────────────────────────────

  /// Capture aid: --dart-define=BOOTH3D_TALK=05@2,9,15,p20,end@30,… starts
  /// the talk at scene time 2 (at section 05, or "06/stroke fx@2" at that
  /// stop of it; without it, at the first), then presses next (or, with p,
  /// back; with b, blank; with a section, jumps there) at each time after.
  static const _scriptDef = String.fromEnvironment('BOOTH3D_TALK');
  static final _presses = [
    for (final s in _scriptDef.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) s,
  ];
  int _pressed = 0;

  /// A section by its number ('end': the last).
  int _sectionAt(String n) => n == 'end' ? sections.length - 1 : math.max(0, sections.indexWhere((s) => s.number == n));

  void _script(double t) {
    while (_pressed < _presses.length) {
      final p = _presses[_pressed];
      final at = p.contains('@') ? p.split('@').first : null;
      final when = double.parse((at == null ? p : p.split('@').last).replaceFirst(RegExp('^[pb]'), ''));
      if (t < when) return;
      if (_pressed == 0) {
        final where = at?.split('/');
        start(director.camera, at: where == null ? 0 : _sectionAt(where.first), stop: where != null && where.length > 1 ? where[1] : null);
      } else if (at != null) {
        jump(_sectionAt(at));
      } else if (p.startsWith('b')) {
        blank.value = !blank.value;
      } else if (p.startsWith('p')) {
        back();
      } else {
        next();
      }
      _pressed++;
    }
  }
}
