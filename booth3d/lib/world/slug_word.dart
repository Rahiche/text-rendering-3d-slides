import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, PictureRecorder;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/gpu.dart' as gpu show MinMagFilter;
import 'package:flutter_scene/scene.dart';
import 'package:slug/slug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kit.dart' show boardGeometry;
import 'shapes.dart' show geometryOf;

/// A word two ways, laid out alike (Flutter's own layout: its pens and
/// baseline from a TextPainter, kerned, no ligatures, so each code point is
/// one glyph either way), for the talk's fair comparison (v_word.dart's
/// Slug turn):
///
/// * [text]: as text reaches a 3D scene today, rasterized once into a
///   texture (mipmapped, sampled smoothly) at a size that's sharp from where
///   the camera starts: come in close and the bitmap blurs;
/// * [slug]: the glyphs' outlines on the GPU in the scene's own pass
///   (assets/materials/slug.fmat, the Slug algorithm, packages/slug's
///   encoder): a quad per glyph, its coverage worked out for every pixel
///   from the curves, sharp from any distance and any side.
///
/// Both in the word's own frame: metres, x right with the word centred on
/// x = 0, its baseline on y = 0, facing −z, the slug a little behind the
/// text.
class SlugWord {
  SlugWord._(this.text, this.slug, this._textMat, this._slugMat, this._ink);

  final Node text, slug;
  final UnlitMaterial _textMat;
  final PreprocessedMaterial _slugMat;
  final vm.Vector4 _ink;

  /// How much of each is showing (0..1).
  set textAlpha(double a) {
    _textMat.baseColorFactor = vm.Vector4(_ink.x, _ink.y, _ink.z, _ink.w * a);
    text.visible = a > 0.002;
  }

  set slugAlpha(double a) {
    _slugMat.parameters.setVec4('ink', vm.Vector4(_ink.x, _ink.y, _ink.z, _ink.w * a));
    slug.visible = a > 0.002;
  }

  /// Builds [word] in [style] (its font from [fontAsset], a TrueType file:
  /// the Slug encoder reads its glyf outlines), [em] metres to the em, in
  /// [ink] (linear). [texturePx]: the text's texture, that many pixels
  /// across the word.
  static Future<SlugWord> build(
    String word, {
    required String fontAsset,
    required TextStyle style,
    required double em,
    required vm.Vector4 ink,
    int texturePx = 2048,
  }) async {
    // The layout, as Flutter sets the word.
    const px = 400.0;
    final flat = style.copyWith(fontSize: px, fontFeatures: const [FontFeature.disable('liga')]);
    final tp = TextPainter(
      text: TextSpan(text: word, style: flat),
      textDirection: TextDirection.ltr,
    )..layout();
    final upp = em / px, width = tp.width * upp;
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final pens = [for (var i = 0; i < word.length; i++) tp.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx];
    final inkBox = (tp.width, tp.height);
    tp.dispose();

    // The text: the same layout drawn into a texture, white (the ink is the
    // material's), on a quad over the layout's box.
    final k = texturePx / inkBox.$1, th = (inkBox.$2 * k).ceil();
    final tex = await _coverage(word, flat.copyWith(fontSize: px * k), texturePx, th);
    final textMat = UnlitMaterial(colorTexture: tex)
      ..baseColorFactor = ink.clone()
      ..alphaMode = AlphaMode.blend;
    final quadH = th / k * upp;
    final text = Node(
      name: 'slug word text',
      mesh: Mesh(boardGeometry(width, quadH, thick: 0.002), textMat),
      localTransform: trsOf(0, baseline * upp - quadH / 2, -0.01),
    )..castsShadows = false;

    // The slug: the glyphs encoded (curves banded into a data texture), a
    // quad each.
    final font = await SlugFont.load(fontAsset);
    final gids = [for (final cp in word.runes) font.glyphId(cp)];
    final (data, glyphs) = SlugAtlas.encode([for (final g in gids) (font, g)]);
    final curves = Texture2D.fromPixels(
      data.pixels,
      data.width,
      data.height,
      content: TextureContent.data,
      sampling: const TextureSampling(mipmaps: false, minFilter: gpu.MinMagFilter.nearest, magFilter: gpu.MinMagFilter.nearest),
    );
    final slugMat = await loadFmatMaterial('assets/materials/slug.fmat');
    slugMat.parameters
      ..setTexture('curve_data', curves.gpuTexture, sampler: curves.sampledSampler)
      ..setVec2('data_size', vm.Vector2(data.width.toDouble(), data.height.toDouble()))
      ..setVec4('ink', ink.clone());
    final perUnit = px / font.unitsPerEm * upp;
    final pos = <double>[], nor = <double>[], uv = <double>[], uv1 = <double>[], col = <double>[];
    final idx = <int>[];
    for (var i = 0; i < gids.length; i++) {
      final g = glyphs[(font.id, gids[i])];
      if (g == null) continue;
      // (Dilated a little: the outline's edge pixels are inside the quad.)
      final d = 0.02 * font.unitsPerEm, q = g.quantum;
      final x0 = g.originX - d, y0 = g.originY - d, x1 = g.originX + g.extentX * q + d, y1 = g.originY + g.extentY * q + d;
      final base = pos.length ~/ 3;
      for (final (fx, fy) in [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]) {
        pos.addAll([pens[i] * upp + fx * perUnit - width / 2, fy * perUnit, 0]);
        nor.addAll([0, 0, -1]);
        uv.addAll([(fx - g.originX) / q, (fy - g.originY) / q]);
        uv1.addAll([g.base.toDouble(), 0]);
        col.addAll([g.hBandCount.toDouble(), g.vBandCount.toDouble(), g.hBandScale, g.vBandScale]);
      }
      idx.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
    final mesh = MeshData(
      positions: Float32List.fromList(pos),
      vertexCount: pos.length ~/ 3,
      normals: Float32List.fromList(nor),
      texCoords: Float32List.fromList(uv),
      texCoords1: Float32List.fromList(uv1),
      colors: Float32List.fromList(col),
      indices: idx,
    );
    final slug = Node(name: 'slug word', mesh: Mesh(geometryOf(mesh), slugMat))..castsShadows = false;
    return SlugWord._(text, slug, textMat, slugMat, ink.clone());
  }

  static vm.Matrix4 trsOf(double x, double y, double z) => vm.Matrix4.translation(vm.Vector3(x, y, z));

  /// [word] in [style] as a glyph atlas keeps it: its coverage in alpha,
  /// white everywhere (the ink is the material's), so sampling it smoothly
  /// leaves no dark fringe; mipmapped.
  static Future<Texture2D> _coverage(String word, TextStyle style, int w, int h) async {
    final rec = ui.PictureRecorder();
    final tp = TextPainter(
      text: TextSpan(text: word, style: style.copyWith(color: const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp
      ..paint(Canvas(rec), Offset.zero)
      ..dispose();
    final image = await rec.endRecording().toImage(w, h);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
    image.dispose();
    final out = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
    for (var i = 0; i < w * h; i++) {
      out[i * 4 + 3] = rgba[i * 4 + 3];
    }
    return Texture2D.fromPixels(out, w, h);
  }
}
