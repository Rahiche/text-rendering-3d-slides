import 'dart:convert' show utf8;

import 'package:characters/characters.dart';
import 'package:text_slides/deck/font_data.dart';

import 'works_name.dart';

/// One step of the text pipeline as the talk's Glyph Works shows it on the
/// board over it: what it is, who does it, what comes in and what goes out
/// (each step's out the next one's in), and a note.
class WorksStation {
  const WorksStation(this.title, this.who, this.input, this.output, this.note);
  final String title, who, input, output, note;
}

/// A word's way through the pipeline, measured ([name]: the works' own
/// measurements of it, null until made; [font]: the font file it's set in,
/// for its cmap, ligatures and outlines), as the talk's stations show it:
/// the widget, into the engine, decoding, the fonts, shaping, the line,
/// painting, the outline, the rasterizer, the draw.
List<WorksStation> worksStations(String word, WorksName? name, FontData? font) {
  final letters = word.characters.toList();
  final n = letters.length;
  String hex(int v, int digits) => v.toRadixString(16).toUpperCase().padLeft(digits, '0');
  final units = [for (final u in word.codeUnits) hex(u, 4)].join(' ');
  final bytes = utf8.encode(word);
  final byteHex = [for (final b in bytes) hex(b, 2)].join(' ');
  final points = [for (final r in word.runes) 'U+${hex(r, 4)}'].join(' ');
  final ascii = bytes.length == word.runes.length;
  final measured = name != null && name.letters.length == n ? name.letters : null;
  final rendered = measured != null && name!.rendered;
  String em(double v) {
    final s = v.toStringAsFixed(2);
    return s.startsWith('0.') ? s.substring(1) : s;
  }

  // The cmap's glyph ids, and the glyphs as shaped: the font's ligatures
  // made one glyph (Space Grotesk: t t → one).
  final ids = font == null ? null : [for (final g in letters) font.glyphId(g.runes.first)];
  final shaped = <(int, int, int)>[]; // (glyph, its first letter, how many)
  if (font != null && ids != null) {
    for (var i = 0; i < ids.length;) {
      final lig = font.ligatureAt(ids, i);
      shaped.add((lig?.$1 ?? ids[i], i, lig?.$2 ?? 1));
      i += lig?.$2 ?? 1;
    }
  }
  final found = font == null ? null : letters.where((g) => font.has(g.runes.first)).length;
  final idList = ids == null ? '…' : [for (final g in ids) '#$g'].join(' ');
  final shapedList = shaped.isEmpty ? '…' : [for (final (g, _, _) in shaped) '#$g'].join(' ');
  final joined = [
    for (final (_, a, k) in shaped)
      if (k > 1) letters.sublist(a, a + k).join(' '),
  ];
  // As positioned: each glyph's advance from its pen to the next's, and
  // its pen in the line.
  final width = measured == null ? null : measured.last.pen + measured.last.advance;
  final advances = measured == null || shaped.isEmpty
      ? '…'
      : [
          for (final (_, a, k) in shaped) em((a + k < measured.length ? measured[a + k].pen : width!) - measured[a].pen),
        ].join(' ');
  final pens = measured == null || shaped.isEmpty ? '…' : [for (final (_, a, _) in shaped) em(measured[a].pen)].join(' ');
  final glyphs = shaped.length;
  final first = letters.first;
  final outline = font == null || ids == null ? null : font.outline(ids.first);
  final px = name == null ? 16 : name.size.round();
  final masks = rendered ? [for (final l in measured) '${l.text} ${l.w}×${l.h}'].take(4).join(' · ') : '…';
  return [
    WorksStation(
      'TEXT()',
      'the framework · Dart',
      "Text('$word')",
      'ui.Paragraph · ${word.codeUnits.length} UTF-16 units',
      units,
    ),
    WorksStation(
      'INTO THE ENGINE',
      'SkParagraph · C++',
      'UTF-16  $units',
      'UTF-8   $byteHex',
      ascii ? '${bytes.length} bytes: all ASCII, one byte each' : '${bytes.length} bytes for ${word.runes.length} code points',
    ),
    WorksStation(
      'DECODE · ICU',
      'SkParagraph · ICU',
      'UTF-8   $byteHex',
      points,
      '$n graphemes · 1 run: Latin, left to right',
    ),
    WorksStation(
      'FONT · CMAP',
      'the font collection',
      points,
      'glyph ids  $idList',
      found == null ? 'looked up in Space Grotesk' : (found == n ? 'Space Grotesk has all $n: no fallback' : '${n - found} of $n by fallback'),
    ),
    WorksStation(
      'SHAPING',
      'HarfBuzz',
      'glyph ids  $idList',
      '$glyphs glyphs  $shapedList',
      joined.isEmpty ? 'advances (em)  $advances' : '${joined.join(', ')} → one ligature · advances  $advances',
    ),
    WorksStation(
      'THE LINE',
      'SkParagraph · line breaking',
      '$glyphs glyphs · ${width == null ? '…' : em(width)} em of advances',
      '1 line · pens  $pens em',
      'it fits the width: no break needed',
    ),
    WorksStation(
      'PAINT',
      'paint() → a display list',
      'the laid-out line',
      'drawTextBlob($glyphs glyphs, pens, color)',
      'recorded, not drawn: no pixels yet',
    ),
    WorksStation(
      'OUTLINE',
      'the font scaler',
      "#${ids?.first ?? '…'}  '$first' at $px px",
      outline == null ? '…' : "'$first': ${outline.contours.length} contour${outline.contours.length == 1 ? '' : 's'}, ${outline.pointCount} points",
      outline == null
          ? 'scaled to $px px'
          : outline.contours.every((c) => c.every((p) => p.onCurve))
          ? 'straight lines only, scaled to $px px'
          : 'lines and quadratic curves, scaled to $px px',
    ),
    WorksStation(
      'RASTERIZE',
      'into the glyph atlas, once',
      '$glyphs outlines at $px px',
      '$glyphs coverage masks',
      masks,
    ),
    WorksStation(
      'DRAW',
      'Impeller · the GPU',
      '$glyphs quads + the atlas + the color',
      rendered ? '${name.cols} × ${name.rows} px on screen' : '… px on screen',
      '1 draw call · ${glyphs * 2} triangles',
    ),
  ];
}
