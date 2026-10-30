import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;

import 'narration_audio.dart';
import 'talk.dart';

/// Presentation mode: the talk told by itself, in the presenter's own
/// voice. Each beat's narration (assets/narration, a clip a beat, made by
/// tool/narration) plays as the beat comes up; when it's done, after a
/// breath, the next beat comes on: the whole talk, the title to the
/// thanks, in 30 minutes (narration.json gives each beat its time). Then
/// the questions, as in the talk.
///
/// Space pauses it (the voice and its clock) and carries on; → and ← go a
/// beat either way (its narration from the start); Esc stops it. A beat
/// with no narration yet ([TalkBeat.unvoiced]) holds its time, silent, and
/// the clips go on with the beats after it; one to hold no time at all is
/// passed over.
class Presentation extends ChangeNotifier {
  Presentation(this.talk, {this.silent = false, this.voice});

  final Talk talk;

  /// No voice (a capture: frames at scene times, the clock all the same).
  final bool silent;

  /// Which version of the narration (tool/narration/variants.py: its clips
  /// in assets/narration/[voice]/); null, the talk's own. One whose clips
  /// aren't in the app falls back to the talk's.
  final String? voice;
  String _dir = 'assets/narration/';

  late final NarrationAudio _audio = NarrationAudio();
  List<_Clip>? _clips;
  final _mp3 = <int, Future<Uint8List>>{};

  bool get on => _on;
  bool _on = false;

  bool get paused => _paused;
  bool _paused = false;

  /// The beat on (counted through the whole talk), how long it's been on
  /// by the presentation's clock (held while paused), whether its voice
  /// has started.
  int _beat = -1;
  double _age = 0;
  bool _spoken = false;

  /// How long the whole presentation takes, and how far through it is.
  double get length {
    if (_clips == null) return 0;
    var s = 0.0;
    for (var b = 0; b < talk.beatCount; b++) {
      s += _dwell(b);
    }
    return s;
  }

  double get elapsed {
    if (!_on || _clips == null || _beat < 0) return 0;
    var s = _age;
    for (var b = 0; b < _beat; b++) {
      s += _dwell(b);
    }
    return s;
  }

  /// The clip beat [b] (counted through the talk) speaks: the unvoiced
  /// beats before it skipped (unless the narration has a clip for every
  /// beat: then they've been voiced); null for one of them, or past the
  /// clips.
  int? _clipOf(int b) {
    if (_clips!.length >= talk.beatCount) return b < _clips!.length ? b : null;
    if (talk.beatAt(b).unvoiced != null) return null;
    var i = 0;
    for (var k = 0; k < b; k++) {
      if (talk.beatAt(k).unvoiced == null) i++;
    }
    return i < _clips!.length ? i : null;
  }

  /// How long beat [b] stays on.
  double _dwell(int b) {
    final c = _clipOf(b);
    return c != null ? _clips![c].dwell : talk.beatAt(b).unvoiced ?? 0;
  }

  /// Starts it from the title (the talk started afresh, the camera flown
  /// there from [from]).
  Future<void> start(PerspectiveCamera from) async {
    if (_on) return;
    final clips = _clips ??= await _load();
    if (clips.isEmpty) return;
    // (The first clip ready before the talk starts; none where the voice
    // isn't, as on the web: it plays silent.)
    await _clip(0).then<void>((_) {}, onError: (Object _) {});
    if (talk.on) talk.end();
    talk.start(from);
    _on = true;
    _paused = false;
    _beat = -1;
    notifyListeners();
  }

  /// Stops it (and the talk).
  void stop() {
    if (!_on) return;
    _on = false;
    _audio.stop();
    if (talk.on) talk.end();
    notifyListeners();
  }

  void togglePause() {
    if (!_on) return;
    _paused = !_paused;
    if (_paused) {
      _audio.pause();
    } else if (_spoken) {
      _audio.resume();
    }
    notifyListeners();
  }

  /// The next beat now, or the one before (its narration from the start).
  void next() {
    if (_on) _step();
  }

  void back() {
    if (!_on) return;
    _step(back: true);
    // (Back on the first beat: it isn't a new beat, so start it over.)
    _beat = -1;
  }

  /// The talk on a beat, or back one, and on past any it has nothing for
  /// (not narrated, held no time: the opening's 2D pages, until they're
  /// voiced), the same way.
  void _step({bool back = false}) {
    do {
      back ? talk.back() : talk.next();
    } while (_passed(talk.beatNumber) && talk.beatNumber > 0 && talk.beatNumber + 1 < talk.beatCount);
  }

  bool _passed(int b) => _clipOf(b) == null && talk.beatAt(b).unvoiced == 0;

  /// Each frame, before the world's update, by the frame's real [dt].
  void update(double dt) {
    if (!_on) return;
    if (!talk.on) {
      // (The talk ended some other way.)
      _on = false;
      _audio.stop();
      notifyListeners();
      return;
    }
    final clips = _clips!, b = talk.beatNumber, last = b + 1 >= talk.beatCount;
    final ci = _clipOf(b);
    if (b != _beat) {
      _beat = b;
      _age = 0;
      _spoken = false;
      _audio.stop();
      // (The next clip ready.)
      for (var k = b + 1; k < talk.beatCount; k++) {
        final n = _clipOf(k);
        if (n == null) continue;
        _clip(n).then<void>((_) {}, onError: (Object _) {});
        break;
      }
    }
    if (_paused || (ci == null && talk.beatAt(b).unvoiced == null)) return;
    _age += dt;
    if (ci != null && !_spoken && _age >= clips[ci].start) {
      _spoken = true;
      _say(ci);
    }
    if (_age >= _dwell(b) && !last) _step();
  }

  /// Plays clip [c] (the beat on's).
  Future<void> _say(int c) async {
    if (silent) return;
    final b = _beat;
    final Uint8List mp3;
    try {
      mp3 = await _clip(c);
    } catch (_) {
      return; // (No voice for it: silent.)
    }
    // (Still on it, not paused meanwhile.)
    if (_on && _beat == b && !_paused) await _audio.play(mp3);
  }

  Future<Uint8List> _clip(int c) => _mp3[c] ??= rootBundle.load('$_dir${_clips![c].file}').then((d) => d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));

  Future<List<_Clip>> _load() async {
    String? text;
    if (voice != null) {
      try {
        text = await rootBundle.loadString('assets/narration/$voice/narration.json');
        _dir = 'assets/narration/$voice/';
      } catch (_) {
        // (Not made yet: the talk's own.)
      }
    }
    final j = json.decode(text ?? await rootBundle.loadString('assets/narration/narration.json')) as Map<String, dynamic>;
    return [
      for (final c in (j['clips'] as List).cast<Map<String, dynamic>>())
        _Clip(c['file'] as String, (c['start'] as num).toDouble(), (c['dwell'] as num).toDouble()),
    ];
  }
}

/// A beat's narration: its file, when in the beat it starts, and how long
/// the beat stays on.
class _Clip {
  const _Clip(this.file, this.start, this.dwell);
  final String file;
  final double start, dwell;
}
