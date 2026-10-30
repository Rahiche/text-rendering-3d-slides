import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// cover.swift <background.png> <out.png> <fonts dir>
// A 1600×800 cover: the frame scaled to the cover's height and set to the
// right, navy behind and fading over its left, the talk's kicker, title and
// line in its own fonts and colours, the title fitted to the room left of
// the scrolls.
let args = CommandLine.arguments
let bgPath = args[1], outPath = args[2], fontsDir = args[3]
let W: CGFloat = 1600, H: CGFloat = 800
let navy: UInt32 = 0x081728

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// A font from a file in the fonts folder at [size], its weight axis set
/// when it has one.
func font(_ file: String, _ size: CGFloat, weight: Double? = nil) -> CTFont {
  let url = URL(fileURLWithPath: fontsDir).appendingPathComponent(file) as CFURL
  let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor]
  var f = CTFontCreateWithFontDescriptor(descs[0], size, nil)
  if let weight, let axes = CTFontCopyVariationAxes(f) as? [[String: Any]],
     let wght = axes.first(where: { ($0[kCTFontVariationAxisNameKey as String] as? String)?.lowercased().contains("weight") ?? false }),
     let id = wght[kCTFontVariationAxisIdentifierKey as String] as? NSNumber {
    let d = CTFontDescriptorCreateCopyWithVariation(CTFontCopyFontDescriptor(f), id, CGFloat(weight))
    f = CTFontCreateWithFontDescriptor(d, size, nil)
  }
  return f
}

func line(_ s: String, _ f: CTFont, _ color: CGColor, kern: CGFloat = 0) -> CTLine {
  let attrs: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): f,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    NSAttributedString.Key(kCTKernAttributeName as String): kern,
  ]
  return CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
}

func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.setFillColor(rgb(navy))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// The frame at the cover's height, against its right edge.
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: bgPath) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let scale = H / CGFloat(img.height)
let fw = CGFloat(img.width) * scale, left = W - fw
ctx.draw(img, in: CGRect(x: left, y: 0, width: fw, height: H))

// The navy fade over its left part, gone before the scrolls.
let clearAt = left + 760 * scale
let fade = CGGradient(colorsSpace: space, colors: [rgb(navy, 1), rgb(navy, 0.92), rgb(navy, 0)] as CFArray, locations: [0, 0.68, 1])!
ctx.drawLinearGradient(fade, start: .zero, end: CGPoint(x: clearAt, y: 0), options: [])

func draw(_ l: CTLine, x: CGFloat, baselineFromTop y: CGFloat) {
  ctx.textPosition = CGPoint(x: x, y: H - y)
  CTLineDraw(l, ctx)
}

let x: CGFloat = 92, room = clearAt - x - 190
// The title, as big as fits the room (two lines).
var size: CGFloat = 104
var t1 = line("Inside Flutter's", font("SpaceGrotesk.ttf", size, weight: 700), rgb(0xE3F2FF), kern: -1.2)
var t2 = line("Text Pipeline", font("SpaceGrotesk.ttf", size, weight: 700), rgb(0xE3F2FF), kern: -1.2)
while max(width(t1), width(t2)) > room && size > 40 {
  size -= 2
  t1 = line("Inside Flutter's", font("SpaceGrotesk.ttf", size, weight: 700), rgb(0xE3F2FF), kern: -1.2)
  t2 = line("Text Pipeline", font("SpaceGrotesk.ttf", size, weight: 700), rgb(0xE3F2FF), kern: -1.2)
}
let top = H / 2 - size * 1.05
draw(line("名前の街 · NAME CITY", font("JetBrainsMono.ttf", 22, weight: 600), rgb(0xFFC66D), kern: 3), x: x, baselineFromTop: top - size * 0.55)
draw(t1, x: x - size * 0.04, baselineFromTop: top + size * 0.62)
draw(t2, x: x - size * 0.04, baselineFromTop: top + size * 1.7)
draw(line("Told in a 3D city built with Flutter", font("SpaceGrotesk.ttf", 28, weight: 400), rgb(0x8DB7DA)), x: x, baselineFromTop: top + size * 1.7 + 62)
print("title size \(size), room \(Int(room))")

let out = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
