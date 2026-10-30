import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart';
import 'package:stroke_fx/stroke_fx.dart';
import 'package:text_slides/deck/theme.dart';

import 'dash_colours.dart';

/// What flies round a fighter: frost's sparkles, embers rising, neon's
/// zips, ivy's leaves, jelly's bubbles, sakura's petals.
enum Sparkle { frost, embers, zaps, leaves, bubbles, petals }

/// How a fighter comes on: down from the sky, up from the street below, in
/// from a side, or dropped (to bounce).
enum Entry { sky, below, right, left, drop }

/// A fighter on Package Town's rooftop (v_package.dart): stroke_fx's
/// [effect] as a Dash in its colours, its [name] on the billboard behind it
/// and its [line] written there in the effect.
class Fighter {
  const Fighter(this.name, this.line, this.effect, this.colours, this.accent, this.sparkle, this.entry);

  final String name, line;
  final StrokeEffect Function() effect;
  final DashColours colours;

  /// Its name's colour on the billboard, and the stage's lights' while it's
  /// on.
  final Color accent;
  final Sparkle sparkle;
  final Entry entry;
}

/// stroke_fx's six on the roof, in the order they come on.
final fighters = <Fighter>[
  Fighter(
    'FROST DASH',
    'Stay frosty',
    Frost.new,
    (body: const Color(0xFF9ED8FF), belly: const Color(0xFFF4FBFF), dark: const Color(0xFF4A9AD0), glow: const Color(0xFF8FE6FF), glowStrength: 0.25, roughness: 0.15),
    const Color(0xFF9FE4FF),
    Sparkle.frost,
    Entry.sky,
  ),
  Fighter(
    'EMBER DASH',
    'Feel the burn',
    Ember.new,
    (body: const Color(0xFFE5481B), belly: const Color(0xFFFFC24A), dark: const Color(0xFF7E1A08), glow: const Color(0xFFFF5A12), glowStrength: 0.55, roughness: 0.5),
    const Color(0xFFFF8A3D),
    Sparkle.embers,
    Entry.below,
  ),
  Fighter(
    'NEON DASH',
    'Light me up',
    Neon.new,
    (body: const Color(0xFFFF3DB4), belly: const Color(0xFF7DF5FF), dark: const Color(0xFF7A1460), glow: const Color(0xFFFF4FD0), glowStrength: 0.7, roughness: 0.3),
    const Color(0xFFFF5FD2),
    Sparkle.zaps,
    Entry.right,
  ),
  Fighter(
    'IVY DASH',
    'I grow on you',
    Ivy.new,
    (body: const Color(0xFF3C9A4E), belly: const Color(0xFFD6F2B4), dark: const Color(0xFF1D5A2A), glow: null, glowStrength: 0, roughness: 0.65),
    const Color(0xFF2F7D3F),
    Sparkle.leaves,
    Entry.left,
  ),
  Fighter(
    'JELLY DASH',
    'Try and squish me',
    Jelly.new,
    (body: const Color(0xFF9B6BFF), belly: const Color(0xFFE6DAFF), dark: const Color(0xFF5A33B5), glow: const Color(0xFFB48CFF), glowStrength: 0.15, roughness: 0.05),
    const Color(0xFF7A4DE0),
    Sparkle.bubbles,
    Entry.drop,
  ),
  Fighter(
    'SAKURA DASH',
    'In full bloom',
    Sakura.new,
    (body: const Color(0xFFFFB4CC), belly: const Color(0xFFFFF5F8), dark: const Color(0xFFE7709B), glow: null, glowStrength: 0, roughness: 0.55),
    const Color(0xFFD94F86),
    Sparkle.petals,
    Entry.left,
  ),
];

/// The rooftop's billboard: the fighter on now ([state]: which, and the
/// seconds since its press), on its effect's own ground; its name sliding
/// in as it comes on, then its line written in its effect once it's landed
/// ([texts], the lines in the hand; [effects], one each).
class FightBoard extends StatelessWidget {
  const FightBoard(this.texts, this.effects, this.state, {super.key, this.pixelRatio = 1});

  final List<StrokeText> texts;
  final List<StrokeEffect> effects;
  final ValueListenable<(int, double)> state;

  /// The capture's (the effects' stroke-space images as sharp as it).
  final double pixelRatio;

  static const w = 1400.0, h = 600.0;

  /// When, after its press, a fighter's name slides in, it lands, and its
  /// line starts being written (as it's off to its perch, the camera
  /// closing in on the billboard).
  static const named = 0.9, lands = 1.2, writes = 1.6;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<(int, double)>(
    valueListenable: state,
    builder: (context, s, _) {
      final (k, since) = s;
      final f = fighters[k], e = effects[k];
      final x = ((since - named) / 0.45).clamp(0.0, 1.0), slide = 1 - math.pow(1 - x, 3).toDouble();
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: e.background)),
            Positioned.fill(
              top: 120,
              bottom: 20,
              child: CustomPaint(
                painter: StrokeFxPainter(text: texts[k], effect: e, time: ValueNotifier(math.max(0.0, since - writes)), devicePixelRatio: pixelRatio),
              ),
            ),
            Positioned(
              left: 56 - (1 - slide) * 700,
              top: 22,
              child: Opacity(
                opacity: slide,
                child: Text(
                  f.name,
                  style: TextStyle(fontFamily: BP.display, fontSize: 86, fontWeight: FontWeight.w800, letterSpacing: 4, color: f.accent),
                ),
              ),
            ),
            Positioned(
              right: 50,
              top: 46,
              child: Text(
                'stroke_fx',
                style: TextStyle(fontFamily: BP.mono, fontSize: 38, color: f.accent.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
