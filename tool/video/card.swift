import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The teaser's graphics, in the talk's fonts and colours.
//   card.swift lower <out.png> <fonts dir> <kicker> <title>
//       a 1920×1080 transparent lower third: kicker over title, bottom left
//   card.swift end <background.png> <out.png> <fonts dir>
//       a 1920×1080 end card: the frame, navy fading over its left, the
//       kicker, title and line, as the README's cover
let args = CommandLine.arguments
let mode = args[1]
let vertical = mode.hasPrefix("v")
let W: CGFloat = vertical ? 1080 : 1920, H: CGFloat = vertical ? 1920 : 1080
let navy: UInt32 = 0x081728

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func font(_ dir: String, _ file: String, _ size: CGFloat, weight: Double? = nil) -> CTFont {
  let url = URL(fileURLWithPath: dir).appendingPathComponent(file) as CFURL
  let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor]
  var f = CTFontCreateWithFontDescriptor(descs[0], size, nil)
  if let weight, let axes = CTFontCopyVariationAxes(f) as? [[String: Any]],
     let wght = axes.first(where: { ($0[kCTFontVariationAxisNameKey as String] as? String)?.lowercased().contains("weight") ?? false }),
     let id = wght[kCTFontVariationAxisIdentifierKey as String] as? NSNumber {
    f = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithVariation(CTFontCopyFontDescriptor(f), id, CGFloat(weight)), size, nil)
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
func draw(_ l: CTLine, x: CGFloat, baselineFromTop y: CGFloat) {
  ctx.textPosition = CGPoint(x: x, y: H - y)
  CTLineDraw(l, ctx)
}
func save(_ path: String) {
  let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
  CGImageDestinationFinalize(dest)
  print("wrote \(path)")
}

/// Lines of [s] in [f], broken at spaces to fit [maxW].
func wrap(_ s: String, _ f: CTFont, _ color: CGColor, maxW: CGFloat, kern: CGFloat = 0) -> [CTLine] {
  var lines: [CTLine] = [], cur = ""
  for word in s.split(separator: " ") {
    let tryS = cur.isEmpty ? String(word) : cur + " " + word
    if width(line(tryS, f, color, kern: kern)) > maxW && !cur.isEmpty {
      lines.append(line(cur, f, color, kern: kern)); cur = String(word)
    } else { cur = tryS }
  }
  if !cur.isEmpty { lines.append(line(cur, f, color, kern: kern)) }
  return lines
}

if mode == "vtitle" {
  // 1080×1920, transparent: the demo's kicker and title above where the
  // video sits, the talk's name along the bottom.
  let out = args[2], fonts = args[3], kicker = args[4], title = args[5]
  let x: CGFloat = 84
  draw(line(kicker, font(fonts, "JetBrainsMono.ttf", 36, weight: 600), rgb(0xFFC66D), kern: 3), x: x, baselineFromTop: 300)
  // (A newline in the title breaks it there; each part wraps to fit.)
  let tf = font(fonts, "SpaceGrotesk.ttf", 76, weight: 650)
  let tl = title.components(separatedBy: "\n").flatMap { wrap($0, tf, rgb(0xE3F2FF), maxW: W - 2 * x, kern: -0.8) }
  for (i, l) in tl.enumerated() { draw(l, x: x - 2, baselineFromTop: 400 + CGFloat(i) * 88) }
  draw(line("Inside Flutter's Text Pipeline", font(fonts, "SpaceGrotesk.ttf", 34, weight: 600), rgb(0xE3F2FF, 0.92)), x: x, baselineFromTop: H - 150)
  draw(line("名前の街 · a 3D city built with Flutter", font(fonts, "JetBrainsMono.ttf", 24, weight: 500), rgb(0x8DB7DA), kern: 1), x: x, baselineFromTop: H - 104)
  save(out)
} else if mode == "vend" {
  // 1080×1920: the frame's right part filling the lower half, fading up into
  // navy; the talk's kicker, title and line above it; the repo below.
  let bg = args[2], out = args[3], fonts = args[4]
  ctx.setFillColor(rgb(navy))
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: bg) as CFURL, nil)!
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
  // (A square from the frame's right, where the scrolls hang.)
  let side = CGFloat(img.height), crop = img.cropping(to: CGRect(x: CGFloat(img.width) - side * 1.05, y: 0, width: side, height: side))!
  let imgTop: CGFloat = 860, imgH = W
  ctx.draw(crop, in: CGRect(x: 0, y: H - imgTop - imgH, width: W, height: imgH))
  let fade = CGGradient(colorsSpace: space, colors: [rgb(navy, 1), rgb(navy, 0)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: H - imgTop), end: CGPoint(x: 0, y: H - imgTop - 300), options: [])
  ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: H - imgTop - imgH), end: CGPoint(x: 0, y: H - imgTop - imgH + 260), options: [])
  let x: CGFloat = 84
  draw(line("名前の街 · NAME CITY", font(fonts, "JetBrainsMono.ttf", 36, weight: 600), rgb(0xFFC66D), kern: 3.4), x: x, baselineFromTop: 330)
  let f = font(fonts, "SpaceGrotesk.ttf", 118, weight: 700)
  draw(line("Inside Flutter's", f, rgb(0xE3F2FF), kern: -1.4), x: x - 4, baselineFromTop: 470)
  draw(line("Text Pipeline", f, rgb(0xE3F2FF), kern: -1.4), x: x - 4, baselineFromTop: 590)
  draw(line("Told in a 3D city built with Flutter", font(fonts, "SpaceGrotesk.ttf", 42, weight: 400), rgb(0x8DB7DA)), x: x, baselineFromTop: 680)
  draw(line("github.com/Rahiche/text-rendering-3d-slides", font(fonts, "JetBrainsMono.ttf", 28, weight: 500), rgb(0x8DB7DA, 0.95), kern: 0.4), x: x, baselineFromTop: H - 120)
  save(out)
} else if mode == "lower" {
  let out = args[2], fonts = args[3], kicker = args[4], title = args[5]
  let k = line(kicker, font(fonts, "JetBrainsMono.ttf", 26, weight: 600), rgb(0xFFC66D), kern: 2.4)
  let t = line(title, font(fonts, "SpaceGrotesk.ttf", 58, weight: 650), rgb(0xE3F2FF), kern: -0.6)
  let x: CGFloat = 96, padX: CGFloat = 40, boxW = max(width(k), width(t)) + padX * 2, boxH: CGFloat = 168
  let box = CGRect(x: x - padX, y: 96, width: boxW, height: boxH) // (CG: from the bottom)
  ctx.addPath(CGPath(roundedRect: box, cornerWidth: 22, cornerHeight: 22, transform: nil))
  ctx.setFillColor(rgb(navy, 0.84))
  ctx.fillPath()
  ctx.addPath(CGPath(roundedRect: box, cornerWidth: 22, cornerHeight: 22, transform: nil))
  ctx.setStrokeColor(rgb(0xFFC66D, 0.35))
  ctx.setLineWidth(1.5)
  ctx.strokePath()
  draw(k, x: x, baselineFromTop: H - 96 - boxH + 58)
  draw(t, x: x - 2, baselineFromTop: H - 96 - boxH + 132)
  save(out)
} else {
  let bg = args[2], out = args[3], fonts = args[4]
  ctx.setFillColor(rgb(navy))
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: bg) as CFURL, nil)!
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
  let scale = H / CGFloat(img.height), fw = CGFloat(img.width) * scale, left = W - fw
  ctx.draw(img, in: CGRect(x: left, y: 0, width: fw, height: H))
  let clearAt = left + fw * 0.52
  let fade = CGGradient(colorsSpace: space, colors: [rgb(navy, 1), rgb(navy, 0.92), rgb(navy, 0)] as CFArray, locations: [0, 0.68, 1])!
  ctx.drawLinearGradient(fade, start: .zero, end: CGPoint(x: clearAt, y: 0), options: [])
  let x: CGFloat = 112
  var size: CGFloat = 112
  func titleLines(_ s: CGFloat) -> (CTLine, CTLine) {
    let f = font(fonts, "SpaceGrotesk.ttf", s, weight: 700)
    return (line("Inside Flutter's", f, rgb(0xE3F2FF), kern: -1.2), line("Text Pipeline", f, rgb(0xE3F2FF), kern: -1.2))
  }
  var (t1, t2) = titleLines(size)
  while max(width(t1), width(t2)) > clearAt - x - 220 && size > 48 {
    size -= 2
    (t1, t2) = titleLines(size)
  }
  let top = H / 2 - size * 1.05
  draw(line("名前の街 · NAME CITY", font(fonts, "JetBrainsMono.ttf", 28, weight: 600), rgb(0xFFC66D), kern: 3.4), x: x, baselineFromTop: top - size * 0.55)
  draw(t1, x: x - size * 0.04, baselineFromTop: top + size * 0.62)
  draw(t2, x: x - size * 0.04, baselineFromTop: top + size * 1.7)
  draw(line("Told in a 3D city built with Flutter", font(fonts, "SpaceGrotesk.ttf", 34, weight: 400), rgb(0x8DB7DA)), x: x, baselineFromTop: top + size * 1.7 + 72)
  draw(line("github.com/Rahiche/text-rendering-3d-slides", font(fonts, "JetBrainsMono.ttf", 24, weight: 500), rgb(0x8DB7DA, 0.9), kern: 0.6), x: x, baselineFromTop: H - 96)
  save(out)
}
