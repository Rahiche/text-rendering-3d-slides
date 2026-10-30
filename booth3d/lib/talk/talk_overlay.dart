import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:text_slides/booth/ui/ink.dart';
import 'package:text_slides/deck/theme.dart';

import '../tuning.dart';
import '../world/ease.dart' show seg, smooth;
import 'talk.dart';
import 'talk_section.dart';
import 'intro_slides.dart';

/// The talk's slide over the city: the stop's card on the left (what
/// happens there, with the talk's real values) over a shade, and the
/// section's way along the bottom, this stop lit.
///
///   05 · ONE WORD'S JOURNEY                    4 / 11
///   デコード
///   Unicode analysis
///   ICU walks the code points: where a letter …
///   ┌ F  l  u  t  t  e  r ┐
///   └ U+0046 …           ┘
///
///   ●──●──●──●──◉──○──○──○──○──○──○
///   MAP WIDGET STRING ENGINE UNICODE …
class TalkOverlay extends StatelessWidget {
  const TalkOverlay({super.key, required this.talk, this.animate = true});

  final Talk talk;

  /// Cross-fade the cards (not in a capture: frames are taken at once).
  final bool animate;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ListenableBuilder(
      listenable: talk,
      builder: (context, _) {
        if (!talk.on || !Tuning.overlay) return const SizedBox.shrink();
        final stop = talk.stop, section = talk.section;
        return Stack(
          children: [
            // The questions: the city dips through the deck's navy and
            // comes back as the booth's demo (the change hidden in it). And
            // up out of the archive's hall: dark through its ceiling.
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: talk.frame,
                builder: (context, _, _) {
                  final d = math.max(talk.dip, talk.underDip);
                  return d <= 0 ? const SizedBox.shrink() : ColoredBox(color: BP.bg.withValues(alpha: d));
                },
              ),
            ),
            // The city's bright by day: a shade behind the card.
            if (talk.cardShown)
              Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 880,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BP.bg.withValues(alpha: 0.5), BP.bg.withValues(alpha: 0.28), BP.bg.withValues(alpha: 0)],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // How far through the whole talk: a section a stretch, along the top.
            if (!talk.questions) Positioned(left: 0, right: 0, top: 0, height: 4, child: CustomPaint(painter: _ProgressPainter(talk))),
            Positioned.fill(child: CustomPaint(painter: _PinPainter(talk))),
            // A chapter's opening, large in the middle until its card's up.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: animate ? const Duration(milliseconds: 520) : Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: talk.chapter
                    ? _Chapter(
                        key: ValueKey(('chapter', talk.sectionIndex, stop)),
                        card: talk.card,
                        section: section,
                        glyphs: stop == 0,
                        animate: animate,
                      )
                    : const SizedBox.shrink(key: ValueKey('no chapter')),
              ),
            ),
            Positioned(
              left: BP.margin,
              top: 56,
              width: 600,
              child: AnimatedSwitcher(
                duration: animate ? const Duration(milliseconds: 380) : Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(-0.04, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: !talk.cardShown
                    ? const SizedBox(key: ValueKey('none'))
                    : _Card(
                  key: ValueKey((talk.sectionIndex, stop)),
                  talk: talk,
                  card: talk.card,
                  section: section,
                  beat: talk.beat,
                  animate: animate,
                ),
              ),
            ),
            // (And under the way along the bottom.)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [BP.bg.withValues(alpha: 0), BP.bg.withValues(alpha: 0.7)],
                  ),
                ),
              ),
            ),
            // (Not for the title and the end: the bar along the top says
            // where the talk is.)
            if (section.stops.length > 2 && section.number.isNotEmpty)
              Positioned(left: BP.margin, right: BP.margin, bottom: 26, height: 52, child: _Route(stops: section.stops, stop: stop)),
            // The questions' lower third, over the whole finale (Dash's
            // delivery, the thanks going up, then kept).
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: talk.questions ? _Questions(card: talk.card, animate: animate) : const SizedBox.shrink(),
              ),
            ),
            // The presenter's slide: over everything as the talk opens; then
            // on the laptop it was on, as the camera pulls back from it.
            Positioned.fill(child: CustomPaint(painter: _SlidePainter(talk))),
            // Blanked: the deck's navy over everything, the room's eyes on
            // the speaker.
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: talk.blank,
                builder: (context, blank, _) => AnimatedOpacity(
                  opacity: blank ? 1 : 0,
                  duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
                  curve: Curves.easeInOut,
                  child: const ColoredBox(color: BP.bg),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The presenter's slide (intro_slides.dart): over the whole canvas, its
/// sketches drawing in; or, as the camera pulls back from the laptop it's
/// on (the last of them, all drawn), over the laptop's screen where the
/// camera sees it (its corners projected, the slide warped onto them:
/// crisp, where the screen's own pixels would be soft), fading as it gets
/// small and the screen's own picture carries it on.
class _SlidePainter extends CustomPainter {
  _SlidePainter(this.talk) : super(repaint: talk.frame);

  final Talk talk;

  /// The slides as they go on the laptop, all drawn, each recorded once (at
  /// the canvas' size).
  static final _pictures = <int, ui.Picture>{};

  @override
  void paint(Canvas canvas, Size size) {
    final mode = talk.slide;
    if (mode == Slide.none) return;
    if (mode == Slide.full) {
      IntroSlides.paint(canvas, size, talk.slidePage, talk.slideAge);
      return;
    }
    final picture = _pictures[talk.slidePage] ??= () {
      final rec = ui.PictureRecorder();
      IntroSlides.paint(Canvas(rec), size, talk.slidePage, double.infinity);
      return rec.endRecording();
    }();
    final corners = talk.slideCorners?.call();
    if (corners == null) return;
    final q = [for (final p in corners) talk.project(p)];
    if (q.contains(null)) return;
    final [a, b, c, d] = [for (final p in q) p!];
    // (Faded by how tall it is on the canvas.)
    final shown = smooth(0.3, 0.62, ((d.dy - a.dy) + (c.dy - b.dy)) / 2 / size.height);
    if (shown <= 0.004) return;
    canvas
      ..save()
      ..transform(_onto(size, a, b, c, d));
    if (shown < 0.996) canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, shown));
    canvas.drawPicture(picture);
    if (shown < 0.996) canvas.restore();
    canvas.restore();
  }

  /// The perspective taking the canvas' corners to [a], [b], [c], [d] (top
  /// left, top right, bottom right, bottom left), as a canvas transform:
  /// the unit square onto the corners (x' = (m00 x + m01 y + a.x) / (m20 x
  /// + m21 y + 1), and y' alike), the canvas onto the unit square.
  static Float64List _onto(Size s, Offset a, Offset b, Offset c, Offset d) {
    final dx1 = b.dx - c.dx, dx2 = d.dx - c.dx, dx3 = a.dx - b.dx + c.dx - d.dx;
    final dy1 = b.dy - c.dy, dy2 = d.dy - c.dy, dy3 = a.dy - b.dy + c.dy - d.dy;
    final den = dx1 * dy2 - dx2 * dy1;
    final g = (dx3 * dy2 - dx2 * dy3) / den, h = (dx1 * dy3 - dx3 * dy1) / den;
    final m00 = (b.dx - a.dx + g * b.dx) / s.width, m01 = (d.dx - a.dx + h * d.dx) / s.height;
    final m10 = (b.dy - a.dy + g * b.dy) / s.width, m11 = (d.dy - a.dy + h * d.dy) / s.height;
    final m20 = g / s.width, m21 = h / s.height;
    // (Column by column.)
    return Float64List.fromList([m00, m10, 0, m20, m01, m11, 0, m21, 0, 0, 1, 0, a.dx, a.dy, 0, 1]);
  }

  @override
  bool shouldRepaint(_SlidePainter old) => old.talk != talk;
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.talk,
    required this.card,
    required this.section,
    required this.beat,
    required this.animate,
  });

  final Talk talk;
  final TalkCard card;
  final TalkSection section;

  /// Which of its stop's beats is on (the rows it lights follow them).
  final int beat;

  /// Its parts come in one after another (not in a capture).
  final bool animate;

  /// Capture aid: --dart-define=BOOTH3D_CARD_GHOST=true draws the card
  /// faint and outlined, over what it would hide.
  static const _ghost = bool.fromEnvironment('BOOTH3D_CARD_GHOST');

  @override
  Widget build(BuildContext context) {
    if (_ghost) {
      return Opacity(
        opacity: 0.3,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF3B30), width: 4)),
          child: _body(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      // Frosted: the city behind it, blurred, through a tinted pane.
      child: Tuning.cardBlur ? BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: _body()) : _body(),
    );
  }

  Widget _body() => Container(
    padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
    decoration: BoxDecoration(
      color: BP.panel.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: BP.line.withValues(alpha: 0.2)),
    ),
    child: _Stagger(
      animate: animate,
      children: [
        // Just the section's name: no number, no count (the way along the
        // bottom shows where the talk is).
        Text(section.title.toUpperCase(), style: UT.mono(16, color: BP.amber, weight: 600, ls: 1.8)),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.kicker.isNotEmpty) ...[Text(card.kicker, style: UT.label(20, color: BP.inkDim, weight: 500)), const SizedBox(height: 2)],
              Text(card.title, style: UT.name(card.opener ? 60 : 54, color: BP.ink, weight: 600, height: 1.04)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(card.lede, style: UT.label(24, color: BP.inkDim, weight: 400, height: 1.36)),
        ),
        for (final f in card.facts) Padding(padding: const EdgeInsets.only(top: 18), child: _fact(f, _labelWidth())),
      ],
    ),
  );

  static final _labelStyle = UT.mono(15, color: BP.inkDim, weight: 600, ls: 1.1);

  /// A label that's a glyph (the row's subject: A, ب, 字, ✓) large, as it
  /// looks; any other in small capitals.
  static final _glyphStyle = UT.name(30, color: BP.ink, weight: 500, height: 1.0);
  static bool _isGlyph(String label) => label.characters.length == 1;
  static TextSpan _labelSpan(String label) => _isGlyph(label) ? TextSpan(text: label, style: _glyphStyle) : TextSpan(text: _caps(label), style: _labelStyle);

  /// The rows' labels' column: as wide as the widest label and a gap (not
  /// under 150).
  double _labelWidth() {
    var w = 0.0;
    for (final f in card.facts) {
      if (f is! FactRow) continue;
      final tp = TextPainter(text: _labelSpan(f.label), textDirection: TextDirection.ltr)..layout();
      w = math.max(w, tp.width);
      tp.dispose();
    }
    return math.max(150.0, w + 20);
  }

  /// Row [label]: its [value], and its [example] under it.
  Widget _row(String label, Widget value, String? example, double labelW) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      SizedBox(width: labelW, child: Text.rich(_labelSpan(label))),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            value,
            if (example != null) Padding(padding: const EdgeInsets.only(top: 5), child: _breaks(example)),
          ],
        ),
      ),
    ],
  );

  /// A row's value: lit, or counted up as the one to look at.
  Widget _value(String label, String value, bool accent) {
    if (card.follow != null) {
      // (Lit in turn, beat by beat: the light moves down the card.)
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _lit(label, accent) ? BP.amber : BP.ink),
        duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, c, _) => Text(value, style: UT.mono(23, color: c ?? BP.ink, weight: 600)),
      );
    }
    if (accent) return _CountUp(value, style: UT.mono(23, color: BP.amber, weight: 600), animate: animate);
    return Text(value, style: UT.mono(23, color: BP.ink, weight: 600));
  }

  /// A row held back until its time: a dash, then its value counted up and
  /// lit (until the next row's out).
  Widget _timedValue(String value, bool shown, bool lit) => shown
      ? TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: lit ? BP.amber : BP.ink),
          duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, c, _) => _CountUp(value, style: UT.mono(23, color: c ?? BP.ink, weight: 600), animate: animate),
        )
      : Text('—', style: UT.mono(23, color: BP.inkFaint.withValues(alpha: 0.6), weight: 600));

  /// The bar beside the row to look at (moving down the card with the
  /// beats, when the card follows them, or with the rows' times).
  Widget _barred(bool lit, Widget row) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: -16,
        top: 2,
        bottom: 2,
        child: AnimatedOpacity(
          opacity: lit ? 1 : 0,
          duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
          curve: Curves.easeOutCubic,
          child: Container(width: 3, decoration: BoxDecoration(color: BP.amber, borderRadius: BorderRadius.circular(2))),
        ),
      ),
      row,
    ],
  );

  /// When the timed row after the one held back until [at] of beat
  /// [beat] comes out.
  (int, double)? _nextAt(int beat, double at) {
    (int, double)? next;
    bool before((int, double) a, (int, double) b) => a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);
    for (final f in card.facts) {
      if (f is! FactRow) continue;
      final a = f.at;
      if (a == null) continue;
      final r = (f.beat, a);
      if (before((beat, at), r) && (next == null || before(r, next))) next = r;
    }
    return next;
  }

  /// An example line, each | in it an amber mark where a line may break.
  static Widget _breaks(String s) {
    final style = UT.label(20, color: BP.inkDim, weight: 500);
    final parts = s.split('|');
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, p) in parts.indexed) ...[
            if (i > 0) TextSpan(text: ' | ', style: style.copyWith(color: BP.amber, fontWeight: FontWeight.w700)),
            TextSpan(text: p, style: style),
          ],
        ],
      ),
    );
  }

  /// A label in capitals, but code as it's written (s.length).
  static String _caps(String label) => label.contains(RegExp(r'[.(_]')) ? label : label.toUpperCase();

  static Widget _code(String code) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: BP.bg.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: BP.lineFaint),
    ),
    child: Text(code, style: UT.mono(19, color: BP.ink, weight: 500).copyWith(height: 1.45)),
  );

  /// Whether row [label] is the one to look at now: as the card follows
  /// its beats, else its own [accent].
  bool _lit(String label, bool accent) {
    final f = card.follow;
    if (f == null || f.isEmpty) return accent;
    return f[beat.clamp(0, f.length - 1)].split('|').contains(label);
  }

  Widget _fact(CardFact f, double labelW) => switch (f) {
    FactRow(:final label, :final value, :final accent, :final example, at: null) => _barred(
      _lit(label, accent),
      _row(label, _value(label, value, accent), example, labelW),
    ),
    FactRow(:final label, :final value, :final example, :final at?, :final beat) => _Timed(
      talk: talk,
      at: (beat, at),
      next: _nextAt(beat, at),
      builder: (shown, lit) => _barred(lit, _row(label, _timedValue(value, shown, lit), example, labelW)),
    ),
    FactTable(:final columns, :final rows, :final lit) => Table(
      columnWidths: const {0: FlexColumnWidth(1.35)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final (i, c) in columns.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  _caps(c),
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: UT.mono(15, color: i == lit ? BP.amber : BP.inkFaint, weight: 600, ls: 0.6),
                ),
              ),
          ],
        ),
        for (final r in rows)
          TableRow(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: BP.lineFaint.withValues(alpha: 0.7)))),
            children: [
              for (final (i, c) in r.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: i == 0
                      ? Text(c, style: UT.name(25, color: BP.ink, weight: 500, height: 1.15))
                      : Text(c, textAlign: TextAlign.right, style: UT.mono(20, color: i == lit ? BP.amber : BP.ink, weight: 600)),
                ),
            ],
          ),
      ],
    ),
    FactScale(:final left, :final right, :final points) => SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(painter: _ScalePainter(left, right, points)),
    ),
    FactCode(:final code, at: null) => _code(code),
    FactCode(:final code, :final at?, :final beat) => _Timed(
      talk: talk,
      at: (beat, at),
      next: null,
      builder: (shown, _) => AnimatedSize(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: shown ? _code(code) : const SizedBox(width: double.infinity),
      ),
    ),
    FactLetters(:final label, :final cells) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(_caps(label), style: UT.mono(15, color: BP.inkDim, weight: 600, ls: 1.2)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            for (final (i, (letter, value, lit)) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  decoration: BoxDecoration(
                    color: lit ? BP.amber.withValues(alpha: 0.13) : BP.bg.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: lit ? BP.amber.withValues(alpha: 0.7) : BP.lineFaint),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(letter, maxLines: 1, style: UT.name(34, color: lit ? BP.amber : BP.ink, weight: 500, height: 1.1)),
                      ),
                      if (value.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(value, maxLines: 1, style: UT.mono(15, color: lit ? BP.amber : BP.inkDim, weight: 600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  };
}

/// A chapter's opening: a rule, its title large, and its glyphs rising one
/// by one; in the middle, over a soft shade. (No number: the way along the
/// bottom shows where the talk is.)
class _Chapter extends StatelessWidget {
  const _Chapter({super.key, required this.card, required this.section, required this.glyphs, required this.animate});

  final TalkCard card;
  final TalkSection section;

  /// With the section's glyphs (its opening: not a later chapter in it).
  final bool glyphs;
  final bool animate;

  static const _glow = [Shadow(color: Color(0xCC081728), blurRadius: 28)];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        // (Tighter for the title and the end: their words in the air round
        // it stay clear.)
        radius: section.number.isEmpty ? 0.52 : 0.62,
        colors: [BP.bg.withValues(alpha: 0.62), BP.bg.withValues(alpha: 0.32), BP.bg.withValues(alpha: 0)],
        stops: const [0, 0.55, 1],
      ),
    ),
    child: Center(
      child: _Stagger(
        animate: animate,
        center: true,
        children: [
          Container(width: 140, height: 2, margin: const EdgeInsets.only(bottom: 26), color: BP.amber),
          if (card.kicker.isNotEmpty) ...[Text(card.kicker, style: UT.label(24, color: BP.inkDim, weight: 500).copyWith(shadows: _glow)), const SizedBox(height: 6)],
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: UT.name(92, color: BP.ink, weight: 600, height: 1.05).copyWith(shadows: _glow),
          ),
          if (section.number.isEmpty && card.lede.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  card.lede,
                  textAlign: TextAlign.center,
                  style: UT.label(24, color: BP.inkDim, weight: 400, height: 1.4).copyWith(shadows: _glow),
                ),
              ),
            ),
          if (glyphs && section.glyphs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 34),
              child: _Stagger(
                animate: animate,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, g) in section.glyphs.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(g, style: UT.name(46, color: i.isEven ? BP.line : BP.inkDim, weight: 500).copyWith(shadows: _glow)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// The thanks, small in the bottom left while the booth's demo plays
/// behind the questions (its captions on the right):
///
///   ありがとうございました
///   Thank you
///   ──  questions?
class _Questions extends StatelessWidget {
  const _Questions({required this.card, required this.animate});

  final TalkCard card;
  final bool animate;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 0,
        bottom: 0,
        width: 980,
        height: 420,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomLeft,
              radius: 1.0,
              colors: [BP.bg.withValues(alpha: 0.6), BP.bg.withValues(alpha: 0.3), BP.bg.withValues(alpha: 0)],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ),
      Positioned(
        left: BP.margin,
        bottom: 58,
        child: _Stagger(
          animate: animate,
          children: [
            if (card.kicker.isNotEmpty) Text(card.kicker, style: UT.label(22, color: BP.inkDim, weight: 500).copyWith(shadows: _Chapter._glow)),
            Text(card.title, style: UT.name(68, color: BP.ink, weight: 600, height: 1.1).copyWith(shadows: _Chapter._glow)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 56, height: 2, margin: const EdgeInsets.only(right: 16), color: BP.amber),
                  Text(card.lede, style: UT.label(26, color: BP.amber, weight: 500).copyWith(shadows: _Chapter._glow)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A value whose first number (10 or more) counts up as its card comes in.
/// A card's row held back until [at] (a beat of its stop's, and seconds
/// into it): whether it's out, and whether it's the latest out (until
/// [next]).
class _Timed extends StatefulWidget {
  const _Timed({required this.talk, required this.at, required this.next, required this.builder});

  final Talk talk;
  final (int, double) at;
  final (int, double)? next;
  final Widget Function(bool shown, bool lit) builder;

  @override
  State<_Timed> createState() => _TimedState();
}

class _TimedState extends State<_Timed> {
  late (bool, bool) _state = _now();

  (bool, bool) _now() {
    final next = widget.next;
    final shown = _out(widget.at);
    return (shown, shown && (next == null || !_out(next)));
  }

  /// Whether what's held back until [at] is out: in a beat before, or this
  /// one's that far in.
  bool _out((int, double) at) {
    final t = widget.talk;
    return t.beat > at.$1 || (t.beat == at.$1 && t.shown(at.$2));
  }

  @override
  void initState() {
    super.initState();
    widget.talk.frame.addListener(_tick);
  }

  void _tick() {
    final s = _now();
    if (s != _state) setState(() => _state = s);
  }

  @override
  void dispose() {
    widget.talk.frame.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_state.$1, _state.$2);
}

class _CountUp extends StatelessWidget {
  const _CountUp(this.value, {required this.style, required this.animate});

  final String value;
  final TextStyle style;
  final bool animate;

  static final _number = RegExp(r'\d[\d,]*');

  @override
  Widget build(BuildContext context) {
    final m = _number.firstMatch(value);
    final digits = m?.group(0);
    final n = digits == null ? null : int.tryParse(digits.replaceAll(',', ''));
    if (!animate || m == null || digits == null || n == null || n < 10) return Text(value, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: n.toDouble()),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(value.replaceRange(m.start, m.end, _grouped(v.round(), digits.contains(','))), style: style),
    );
  }

  /// [v] with thousands commas, if [commas].
  static String _grouped(int v, bool commas) {
    final s = '$v';
    if (!commas) return s;
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

/// The whole talk along the top: a stretch a section (as long as its
/// beats), those done lit, this one lit as far as it's got.
class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.talk);

  final Talk talk;

  @override
  void paint(Canvas canvas, Size size) {
    final secs = talk.sections;
    final total = secs.fold<int>(0, (a, s) => a + s.beats.length);
    const gap = 6.0;
    final w = size.width - gap * (secs.length - 1);
    var x = 0.0;
    for (final (i, s) in secs.indexed) {
      final len = w * s.beats.length / total;
      final r = Rect.fromLTWH(x, 0, len, size.height);
      canvas.drawRect(r, Paint()..color = BP.inkFaint.withValues(alpha: 0.28));
      final done = i < talk.sectionIndex ? 1.0 : (i == talk.sectionIndex ? (talk.beatIndex + 1) / s.beats.length : 0.0);
      if (done > 0) canvas.drawRect(Rect.fromLTWH(x, 0, len * done, size.height), Paint()..color = BP.amber.withValues(alpha: i == talk.sectionIndex ? 0.95 : 0.55));
      x += len + gap;
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => true;
}

/// A card's parts coming in one after another, each a little up and in,
/// as it's shown.
class _Stagger extends StatefulWidget {
  const _Stagger({required this.children, required this.animate, this.center = false});

  final List<Widget> children;
  final bool animate;

  /// Each part in the middle (a chapter's), else on the left.
  final bool center;

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger> with SingleTickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: Duration(milliseconds: 420 + 80 * widget.children.length));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _in.forward();
    } else {
      _in.value = 1;
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return Column(
      crossAxisAlignment: widget.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, child) in widget.children.indexed)
          () {
            final from = 0.55 * i / n;
            final a = CurvedAnimation(parent: _in, curve: Interval(from, math.min(1.0, from + 0.45), curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: child),
            );
          }(),
      ],
    );
  }
}

/// What's pinned to the city: a dot where it is, a line up from it and its
/// name, following the camera.
class _PinPainter extends CustomPainter {
  _PinPainter(this.talk) : super(repaint: talk.frame);

  final Talk talk;

  /// Where each name's box goes (from its dot), worked out once for the
  /// names up now, all of them at full size, and kept while they're up: none
  /// moves as the others come up one by one, or as the camera drifts. (Only
  /// if the camera's gone so far that two would meet is it worked out
  /// again.)
  static final _kept = Expando<_PinLayout>();

  /// How far apart the names are kept, and from the dots and lines.
  static const _gap = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = talk.pinsShown;
    if (shown <= 0.01) return;
    final pins = [
      for (final p in talk.pins)
        if (talk.project(p.at) case final o?) (o, p),
    ];
    final labels = [
      for (final (_, p) in pins)
        TextPainter(
          text: TextSpan(
            children: [
              TextSpan(text: p.name, style: UT.mono(20, color: BP.amber, weight: 700, ls: 1.4)),
              if (p.sub != null) TextSpan(text: '  ${p.sub}', style: UT.mono(16, color: BP.inkDim, weight: 500, ls: 0.6)),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final boxes = [for (final (i, (_, p)) in pins.indexed) Size(labels[i].width + 28 + (p.order == null ? 0.0 : 30.0), labels[i].height + 16)];
    final at = [for (final (o, _) in pins) o];
    final kept = _kept[talk] ??= _PinLayout();
    final below = [for (final (_, p) in pins) p.below];
    if (!identical(kept.pins, talk.pins) || kept.boxes.length != pins.length || !_holds(at, kept.boxes, below, size)) {
      kept
        ..pins = talk.pins
        ..boxes = _place(at, boxes, [for (final (_, p) in pins) p.side], below, size);
    }
    for (final (i, (o, TalkPin(:name, :order, :sub))) in pins.indexed) {
      // (A numbered step comes up after the one before it.)
      final k = order == null ? Curves.easeOutCubic.transform(shown) : Curves.easeOutCubic.transform(seg(talk.pinsAge, 0.34 * (order - 1), 0.34 * (order - 1) + 0.45));
      labels[i].dispose();
      if (k <= 0.01) continue;
      final amber = BP.amber.withValues(alpha: k);
      final label = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: name, style: UT.mono(20, color: BP.amber.withValues(alpha: k), weight: 700, ls: 1.4)),
            if (sub != null) TextSpan(text: '  $sub', style: UT.mono(16, color: BP.inkDim.withValues(alpha: k), weight: 500, ls: 0.6)),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final disc = order == null ? 0.0 : 30.0;
      // (Coming up out of its dot to where it's kept.)
      final rel = kept.boxes[i], mid = rel.center;
      final b = rel.shift(o - mid * (0.45 * (1 - k)));
      final end = Offset(o.dx.clamp(b.left + 16, b.right - 16), b.bottom < o.dy ? b.bottom : b.top);
      final from = o + (end - o) / math.max((end - o).distance, 1e-3) * 9;
      canvas
        ..drawCircle(o, 5, Paint()..color = amber)
        ..drawCircle(
          o,
          9 + 5 * (1 - k),
          Paint()
            ..color = BP.amber.withValues(alpha: 0.5 * k)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        )
        ..drawLine(
          from,
          end,
          Paint()
            ..color = amber
            ..strokeWidth = 1.6,
        );
      final rr = RRect.fromRectAndRadius(b, const Radius.circular(8));
      canvas
        ..drawRRect(rr, Paint()..color = BP.panel.withValues(alpha: 0.92 * k))
        ..drawRRect(
          rr,
          Paint()
            ..color = amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      if (order != null) {
        // The step's number, in an amber disc.
        final c = Offset(b.left + 14 + 11, b.center.dy);
        canvas.drawCircle(c, 12, Paint()..color = amber);
        final n = TextPainter(
          text: TextSpan(text: '$order', style: UT.mono(18, color: BP.panel.withValues(alpha: k), weight: 800)),
          textDirection: TextDirection.ltr,
        )..layout();
        n
          ..paint(canvas, c - Offset(n.width / 2, n.height / 2))
          ..dispose();
      }
      label
        ..paint(canvas, Offset(b.left + 14 + disc, b.top + 8))
        ..dispose();
    }
  }

  /// The card's right edge: the names keep right of it (all the time, so
  /// none moves as it comes in).
  static const _left = BP.margin + 620;

  /// Each name's box ([boxes], their sizes) from its dot ([at]): above its
  /// place (the lowest on screen, the nearest, placed first), as low as it
  /// fits: straight up, else a little to one side or the other (to its
  /// [sides] side, if it has one), else under it; well clear of the names
  /// already placed, of every place's dot, and of the lines to them (and its
  /// own line clear of the names); off the card. A name [below] its place
  /// goes under it straight away, under the card if that's where it is.
  static List<Rect> _place(List<Offset> at, List<Size> boxes, List<int> sides, List<bool> below, Size size) {
    final order = [for (var i = 0; i < at.length; i++) i]..sort((a, b) => at[b].dy.compareTo(at[a].dy));
    final out = List.filled(at.length, Rect.zero);
    final placed = <Rect>[];
    final lines = <(Offset, Offset)>[];
    for (final i in order) {
      final o = at[i], w = boxes[i].width, h = boxes[i].height;
      Rect? fit;
      for (var lift = below[i] ? 420.0 : 58.0; fit == null && lift < 640; lift += 6) {
        final dxs = switch (sides[i]) {
          < 0 => [-0.9 * w, -1.4 * w, -0.45 * w, -1.9 * w, 0.0],
          > 0 => [0.9 * w, 1.4 * w, 0.45 * w, 1.9 * w, 0.0],
          _ => [0.0, -0.45 * w, 0.45 * w, -0.9 * w, 0.9 * w, -1.4 * w, 1.4 * w],
        };
        for (final dx in dxs) {
          final under = lift >= 420;
          final b = under ? Rect.fromLTWH(o.dx - w / 2 + dx, o.dy + lift - 420 + 26, w, h) : Rect.fromLTWH(o.dx - w / 2 + dx, o.dy - lift - h, w, h);
          if ((b.left < _left && !below[i]) || b.left < 8 || b.right > size.width - 8 || b.top < 8 || b.bottom > size.height - 110) continue;
          final end = Offset(o.dx.clamp(b.left + 16, b.right - 16), under ? b.top : b.bottom);
          if (placed.any((r) => r.overlaps(b.inflate(_gap))) ||
              at.any((d) => d != o && b.inflate(_gap).contains(d)) ||
              lines.any((l) => _crosses(l.$1, l.$2, b.inflate(_gap / 2))) ||
              placed.any((r) => _crosses(o, end, r.inflate(_gap / 2)))) {
            continue;
          }
          fit = b;
          break;
        }
      }
      final b = fit ?? Rect.fromLTWH((o.dx - w / 2).clamp(_left, size.width - 8 - w), math.max(8, o.dy - 58 - h), w, h);
      placed.add(b);
      lines.add((o, Offset(o.dx.clamp(b.left + 16, b.right - 16), b.bottom < o.dy ? b.bottom : b.top)));
      out[i] = b.shift(-o);
    }
    return out;
  }

  /// Whether the boxes kept ([rel], from their dots [at]) still do: on the
  /// screen, none meeting another.
  static bool _holds(List<Offset> at, List<Rect> rel, List<bool> below, Size size) {
    final boxes = [for (var i = 0; i < at.length; i++) rel[i].shift(at[i])];
    for (var i = 0; i < boxes.length; i++) {
      final b = boxes[i];
      if ((b.left < _left - 40 && !below[i]) || b.left < -20 || b.right > size.width + 20 || b.top < -20 || b.bottom > size.height - 80) return false;
      for (var j = i + 1; j < boxes.length; j++) {
        if (b.overlaps(boxes[j].inflate(2))) return false;
      }
    }
    return true;
  }

  /// Whether the line [a]–[b] passes through [r].
  static bool _crosses(Offset a, Offset b, Rect r) {
    var t0 = 0.0, t1 = 1.0;
    final d = b - a;
    for (final (p, q) in [(-d.dx, a.dx - r.left), (d.dx, r.right - a.dx), (-d.dy, a.dy - r.top), (d.dy, r.bottom - a.dy)]) {
      if (p == 0) {
        if (q < 0) return false;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        t0 = math.max(t0, t);
      } else {
        t1 = math.min(t1, t);
      }
      if (t0 > t1) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.talk != talk;
}

/// The names' boxes as they were placed (from their dots), and for which
/// names.
class _PinLayout {
  List<TalkPin>? pins;
  List<Rect> boxes = const [];
}

/// A line between two ends, the points on it: each name by its dot,
/// above and below in turn (neighbours don't collide), the one to look at
/// in amber.
class _ScalePainter extends CustomPainter {
  _ScalePainter(this.left, this.right, this.points);
  final String left, right;
  final List<(String, double, bool)> points;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final y = size.height / 2, x0 = pad, x1 = size.width - pad;
    double at(double v) => x0 + (v + 1) / 2 * (x1 - x0);
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..color = BP.lineDim
        ..strokeWidth = 2,
    );
    for (final x in [x0, x1]) {
      canvas.drawLine(Offset(x, y - 7), Offset(x, y + 7), Paint()
        ..color = BP.lineDim
        ..strokeWidth = 2);
    }
    void text(String s, TextStyle style, Offset o, {double align = 0.5}) {
      final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
      tp
        ..paint(canvas, o - Offset(tp.width * align, 0))
        ..dispose();
    }

    text(left.toUpperCase(), UT.mono(14, color: BP.inkDim, weight: 600, ls: 1.0), Offset(x0, size.height - 18), align: 0);
    text(right.toUpperCase(), UT.mono(14, color: BP.inkDim, weight: 600, ls: 1.0), Offset(x1, size.height - 18), align: 1);
    final sorted = [...points]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (i, (name, v, lit)) in sorted.indexed) {
      final x = at(v), up = i.isEven;
      final col = lit ? BP.amber : BP.ink;
      canvas
        ..drawLine(Offset(x, y), Offset(x, up ? y - 20 : y + 20), Paint()
          ..color = col.withValues(alpha: 0.6)
          ..strokeWidth = 1.4)
        ..drawCircle(Offset(x, y), lit ? 8 : 5.5, Paint()..color = col);
      if (lit) {
        canvas.drawCircle(
          Offset(x, y),
          13,
          Paint()
            ..color = BP.amber.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      text(name, UT.name(lit ? 25 : 21, color: col, weight: lit ? 700 : 500, height: 1.0), Offset(x, up ? y - 46 : y + 24));
    }
  }

  @override
  bool shouldRepaint(_ScalePainter old) => false;
}

/// The way: a dot per stop on a line, those passed lit, this one ringed.
class _Route extends StatelessWidget {
  const _Route({required this.stops, required this.stop});

  final List<String> stops;
  final int stop;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RoutePainter(stops, stop));
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.stops, this.stop);

  final List<String> stops;
  final int stop;

  @override
  void paint(Canvas canvas, Size size) {
    final n = stops.length;
    const y = 12.0;
    final dx = n < 2 ? 0.0 : size.width / (n - 1);
    final dim = Paint()
      ..color = BP.inkFaint.withValues(alpha: 0.55)
      ..strokeWidth = 1.6;
    final lit = Paint()
      ..color = BP.amber.withValues(alpha: 0.75)
      ..strokeWidth = 2.2;
    canvas
      ..drawLine(Offset(dx * stop, y), Offset(size.width, y), dim)
      ..drawLine(const Offset(0, y), Offset(dx * stop, y), lit);
    for (var i = 0; i < n; i++) {
      final o = Offset(dx * i, y);
      if (i == stop) {
        canvas
          ..drawCircle(o, 9, Paint()..color = BP.bg)
          ..drawCircle(
            o,
            9,
            Paint()
              ..color = BP.amber
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          )
          ..drawCircle(o, 4.5, Paint()..color = BP.amber);
      } else {
        canvas.drawCircle(o, i < stop ? 4.5 : 4, Paint()..color = i < stop ? BP.amber : BP.bg);
        if (i > stop) {
          canvas.drawCircle(
            o,
            4,
            Paint()
              ..color = BP.inkFaint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
      }
      final label = TextPainter(
        text: TextSpan(
          text: stops[i].toUpperCase(),
          style: UT.mono(16, color: i == stop ? BP.amber : (i < stop ? BP.inkDim : BP.inkFaint), weight: i == stop ? 700 : 600, ls: 1.1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (o.dx - label.width / 2).clamp(-8.0, size.width - label.width + 8);
      label
        ..paint(canvas, Offset(lx, y + 15))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.stop != stop || !identical(old.stops, stops);
}
