import 'package:flutter/painting.dart';

/// The talk's first slide, as plain as slides come: a presentation app's
/// default title layout, white, its title and subtitle in the middle. The
/// talk opens on it over the whole canvas; it's on the presenter's laptop
/// in the city too (world/v_desk.dart), and the next press pulls back from
/// it: the slide was a screen in the city all along.
abstract final class TitleSlide {
  static const title = 'Text Rendering';
  static const subtitle = 'From code points to pixels, and how Flutter does it';

  /// Its type (the opening's other slides' too: intro_slides.dart): Arial,
  /// as a default theme has it, where there is one (Roboto on the web).
  static TextStyle style(double size, Color color) =>
      TextStyle(fontFamily: 'Arial', fontFamilyFallback: const ['Roboto'], fontSize: size, color: color, height: 1.0);

  /// Paints it into [size] (16:9), laid out as a 13.33 × 7.5 inch slide's
  /// title layout has it: the title at 60 pt sitting on the middle, the
  /// subtitle at 24 pt under it.
  static void paint(Canvas c, Size size) {
    final k = size.height / 900;
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    TextPainter text(String s, double px, Color color) =>
        TextPainter(text: TextSpan(text: s, style: style(px * k, color)), textAlign: TextAlign.center, textDirection: TextDirection.ltr)
          ..layout(maxWidth: size.width * 0.75);
    final t = text(title, 100, const Color(0xFF000000)), s = text(subtitle, 40, const Color(0xFF595959));
    t.paint(c, Offset((size.width - t.width) / 2, 455 * k - t.height));
    s.paint(c, Offset((size.width - s.width) / 2, 478 * k));
    t.dispose();
    s.dispose();
  }
}
