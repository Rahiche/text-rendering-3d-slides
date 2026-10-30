import 'dart:convert' show utf8;

import 'package:characters/characters.dart';
import 'package:text_slides/deck/font_data.dart';

import '../world/works_name.dart';
import 'talk_section.dart';

/// The talk's stops: the map, then a station a press (works_stations.dart:
/// each station's board in the hall says what comes in and what goes out).
const journeyStops = ['map', 'widget', 'engine', 'decode', 'fonts', 'shape', 'line', 'paint', 'outline', 'raster', 'draw'];

/// The cards for [word], with what the works measured of it ([name]: null
/// before it has) and its font ([font]: its cmap). Short: why each station
/// does what it does; the boards over the stations show the data.
List<TalkCard> journeyCards(String word, WorksName? name, FontData? font) {
  final letters = word.characters.toList();
  final n = letters.length, units = word.codeUnits.length, bytes = utf8.encode(word).length, points = word.runes.length;
  final measured = name != null && name.letters.length == n ? name.letters : null;
  final rendered = measured != null && name!.rendered;
  final width = measured == null ? null : measured.last.pen + measured.last.advance;
  String ems(double v) => v.toStringAsFixed(2);
  // The glyphs as shaped: the cmap's, the font's ligatures made one glyph
  // (Space Grotesk: t t → one).
  int? glyphs;
  if (font != null) {
    final ids = [for (final g in letters) font.glyphId(g.runes.first)];
    var count = 0;
    for (var i = 0; i < ids.length; count++) {
      i += font.ligatureAt(ids, i)?.$2 ?? 1;
    }
    glyphs = count;
  }
  final found = font == null ? null : letters.where((g) => font.has(g.runes.first)).length;
  final outline = font?.outline(font.glyphId(letters.first.runes.first));
  final px = name == null ? 16 : name.size.round();
  return [
    TalkCard(
      "One word's journey",
      "Text('$word') on its way to pixels, a station at a time: each one's output is the next one's input.",
      const [
        FactRow('framework', 'the widget · Dart'),
        FactRow('SkParagraph', 'bytes · fonts · shaping · lines'),
        FactRow('Impeller', 'raster · draw', accent: true),
      ],
    ),
    TalkCard(
      "Text('$word')",
      'A widget only describes: a string and a style. Its render object hands the text to the engine.',
      const [
        FactRow('builds', 'RichText → RenderParagraph'),
        FactRow('which owns', 'TextPainter → ui.Paragraph', accent: true),
      ],
    ),
    TalkCard(
      'Into the engine',
      "Dart's strings are UTF-16. SkParagraph, in C++, keeps the text as UTF-8.",
      [
        FactRow('in', '$units UTF-16 code units'),
        FactRow('out', '$bytes UTF-8 bytes', accent: true),
      ],
    ),
    TalkCard(
      'Decode, with ICU',
      'The bytes are read back as code points. ICU marks graphemes, line breaks, direction and script.',
      [
        FactRow('out', '$points code points'),
        const FactRow('runs', '1 · Latin, left to right', accent: true),
      ],
    ),
    TalkCard(
      'Find the glyphs',
      "Each code point is looked up in the fonts, in order: a font's cmap gives its glyph id.",
      [
        const FactRow('font', 'Space Grotesk'),
        FactRow('fallback', found == null ? '…' : (found == n ? 'not needed: $n of $n' : '${n - found} of $n'), accent: true),
      ],
    ),
    TalkCard(
      'Shape',
      'HarfBuzz turns the run into the glyphs to draw and how far each advances: t t join into one.',
      [
        FactRow('in', '$n glyph ids'),
        FactRow('out', glyphs == null ? '…' : '$glyphs glyphs + advances', accent: true),
      ],
    ),
    TalkCard(
      'Lay out the line',
      'The advances add up to the line; where it would run past the width, it breaks.',
      [
        FactRow('width', width == null ? '…' : '${ems(width)} em'),
        const FactRow('lines', '1: no break needed', accent: true),
      ],
    ),
    TalkCard(
      'Paint, recorded',
      'paint() draws nothing yet: it records the line into a display list, for the raster thread.',
      const [
        FactRow('records', 'drawTextBlob'),
        FactRow('pixels', 'none yet', accent: true),
      ],
    ),
    TalkCard(
      'The outline',
      "On the raster thread, each new glyph's outline is read from the font and scaled to the size.",
      [
        FactRow(letters.first, outline == null ? '…' : '${outline.contours.length} contour${outline.contours.length == 1 ? '' : 's'} · ${outline.pointCount} points'),
        FactRow('scaled to', '$px px', accent: true),
      ],
    ),
    TalkCard(
      'Rasterize',
      'Each outline becomes a coverage mask in the glyph atlas: rasterized once, then reused.',
      [
        FactRow('coverage', rendered ? '${measured.fold(0, (a, l) => a + l.full)} full · ${measured.fold(0, (a, l) => a + l.edge)} edge px' : '…'),
        const FactRow('atlas', 'once per glyph and size', accent: true),
      ],
    ),
    TalkCard(
      'Draw',
      'Each glyph is a quad into the atlas. The shader multiplies the text color by the coverage.',
      [
        FactRow('quads', glyphs == null ? '…' : '$glyphs · ${glyphs * 2} triangles'),
        const FactRow('draw calls', '1', accent: true),
        FactRow('on screen', rendered ? '${name.cols} × ${name.rows} px' : '…'),
      ],
    ),
  ];
}
