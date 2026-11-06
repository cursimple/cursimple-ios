import AppKit
import CoreGraphics

let source = "/Users/sheep/Public/git/cursimple-app/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
let outDir = "/Users/sheep/Public/git/cursimple-ios/CurSimple/Resources/Assets.xcassets"

guard let image = NSImage(contentsOfFile: source),
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage else {
    fatalError("cannot load source icon")
}

let w = cg.width
let h = cg.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
var pixels = [UInt8](repeating: 0, count: w * h * 4)
guard let scan = CGContext(
    data: &pixels, width: w, height: h,
    bitsPerComponent: 8, bytesPerRow: w * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("scan context") }
scan.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

var minX = w, maxX = 0, minY = h, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
        let white = r > 242 && g > 242 && b > 242
        if a > 16 && !white {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
print("bbox bottom-left: \(minX),\(minY) - \(maxX),\(maxY)")

let cropWidth = maxX - minX + 1
let cropHeight = maxY - minY + 1
// CGImage cropping uses top-left origin.
let cropY = h - 1 - maxY
guard let cropped = cg.cropping(to: CGRect(x: minX, y: cropY, width: cropWidth, height: cropHeight)) else {
    fatalError("crop")
}

let size = 1024
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.interpolationQuality = .high

// Fit with a small safe margin so the artwork is not clipped by the icon mask.
let margin: CGFloat = 44
let scale = min((CGFloat(size) - margin * 2) / CGFloat(cropWidth),
                (CGFloat(size) - margin * 2) / CGFloat(cropHeight))
let drawWidth = CGFloat(cropWidth) * scale
let drawHeight = CGFloat(cropHeight) * scale
let originX = (CGFloat(size) - drawWidth) / 2
let originY = (CGFloat(size) - drawHeight) / 2
ctx.draw(cropped, in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight))

guard let output = ctx.makeImage() else { fatalError("image") }
let bitmap = NSBitmapImageRep(cgImage: output)
guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("png") }

let iconDir = "\(outDir)/AppIcon.appiconset"
let markDir = "\(outDir)/AppMark.imageset"
try FileManager.default.createDirectory(atPath: iconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: markDir, withIntermediateDirectories: true)
try data.write(to: URL(fileURLWithPath: "\(iconDir)/AppIcon-1024.png"))
try data.write(to: URL(fileURLWithPath: "\(markDir)/AppMark.png"))
print("wrote \(cropWidth)x\(cropHeight) -> 1024")
