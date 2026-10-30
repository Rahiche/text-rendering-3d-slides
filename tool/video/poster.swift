import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// poster.swift <cover image> <out.jpg>
// The README's cover with a play button over the scrolls: it links to the
// teaser.
let args = CommandLine.arguments
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let W = img.width, H = img.height
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))

// A navy disc with an amber ring and a white triangle, right of the title.
let cx = CGFloat(W) * 0.69, cy = CGFloat(H) * 0.5, r = CGFloat(H) * 0.11
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 28, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45))
ctx.setFillColor(CGColor(srgbRed: 8 / 255, green: 23 / 255, blue: 40 / 255, alpha: 0.82))
ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 198 / 255, blue: 109 / 255, alpha: 0.9))
ctx.setLineWidth(r * 0.06)
ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
let t = r * 0.42
ctx.setFillColor(CGColor(srgbRed: 0.89, green: 0.95, blue: 1, alpha: 1))
ctx.move(to: CGPoint(x: cx - t * 0.62, y: cy - t))
ctx.addLine(to: CGPoint(x: cx - t * 0.62, y: cy + t))
ctx.addLine(to: CGPoint(x: cx + t * 1.05, y: cy))
ctx.closePath()
ctx.fillPath()

let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
CGImageDestinationFinalize(dest)
print("wrote \(args[2])")
