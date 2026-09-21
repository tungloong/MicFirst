#!/usr/bin/env swift
// Reproducible production export of the approved artwork; does not redraw it.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let sourcePath = "docs/design/app-icon/2026-09-21-porcelain-equalizer/porcelain-equalizer-original.png"
let releasePath = "docs/design/app-icon/releases/1.0"
let sourceURL = root.appendingPathComponent(sourcePath)
let sourceData = try Data(contentsOf: sourceURL)
guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
      let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    fatalError("Cannot load the approved icon")
}

func context(_ width: Int, _ height: Int) -> CGContext {
    guard let result = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        fatalError("Cannot allocate an RGBA context")
    }
    return result
}

let width = original.width
let height = original.height
let decoded = context(width, height)
decoded.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
let pixels = decoded.data!.assumingMemoryBound(to: UInt8.self)

// The generated PNG has alpha 1–8 exterior debris and alpha 252–253 interiors.
// Normalize only alpha, preserving straight RGB while updating premultiplied RGB.
let clearThreshold = 8
let opaqueThreshold = 240
for index in 0..<(width * height) {
    let offset = index * 4
    let oldAlpha = Int(pixels[offset + 3])
    let alpha: Int
    if oldAlpha <= clearThreshold {
        alpha = 0
    } else if oldAlpha >= opaqueThreshold {
        alpha = 255
    } else {
        alpha = ((oldAlpha - clearThreshold) * 255 + (opaqueThreshold - clearThreshold) / 2)
            / (opaqueThreshold - clearThreshold)
    }
    for channel in 0..<3 {
        pixels[offset + channel] = oldAlpha == 0 ? 0 : UInt8(min(alpha,
            (Int(pixels[offset + channel]) * alpha + oldAlpha / 2) / oldAlpha))
    }
    pixels[offset + 3] = UInt8(alpha)
}

var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= minX, maxY >= minY else { fatalError("Empty artwork") }
let bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let normalized = decoded.makeImage()!
let tile = normalized.cropping(to: bounds)!

// Match the accepted reference's ~80.5% tile footprint on a 1024px canvas.
// Bounds come from this artwork, not the previous product's icon dimensions.
let footprint = 824.0 / 1024.0
func render(_ size: Int) -> CGImage {
    let target = context(size, size)
    let scale = Double(size) * footprint / Double(max(tile.width, tile.height))
    let w = Double(tile.width) * scale, h = Double(tile.height) * scale
    target.interpolationQuality = .high
    target.draw(tile, in: CGRect(x: (Double(size) - w) / 2,
        y: (Double(size) - h) / 2, width: w, height: h))
    return target.makeImage()!
}

func write(_ image: CGImage, to relativePath: String) throws {
    let url = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot create \(relativePath)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write \(relativePath)") }
}

struct Catalog: Decodable {
    struct Slot: Decodable { let filename: String; let size: String; let scale: String }
    let images: [Slot]
}
let catalogPath = "MicFirst/Assets.xcassets/AppIcon.appiconset"
let catalog = try JSONDecoder().decode(Catalog.self,
    from: Data(contentsOf: root.appendingPathComponent(catalogPath + "/Contents.json")))
var exports: [[String: Any]] = []
for slot in catalog.images {
    guard let points = Int(slot.size.split(separator: "x")[0]),
          let scale = Int(slot.scale.dropLast()) else { fatalError("Invalid icon slot") }
    let size = points * scale
    let path = catalogPath + "/" + slot.filename
    try write(render(size), to: path)
    exports.append(["path": path, "pixels": size])
}
try write(render(1024), to: "docs/assets/micfirst-app-icon.png")
try write(render(256), to: "docs/assets/micfirst-app-icon-256.png")
try write(render(1024), to: releasePath + "/MicFirst-1.0-1024.png")

// iconutil consumes the same macOS slot filenames as the asset catalog.
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("micfirst-icon-" + UUID().uuidString)
let iconset = temporary.appendingPathComponent("MicFirst.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
for slot in catalog.images {
    try FileManager.default.copyItem(at: root.appendingPathComponent(catalogPath + "/" + slot.filename),
        to: iconset.appendingPathComponent(slot.filename))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent(releasePath + "/MicFirst.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }

let report: [String: Any] = [
    "source": sourcePath,
    "sourceSHA256": SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined(),
    "sourceSize": [width, height],
    "sourceAlphaBounds": [minX, minY, maxX + 1, maxY + 1],
    "clearAlphaAtOrBelow": clearThreshold,
    "opaqueAlphaAtOrAbove": opaqueThreshold,
    "tileLongestSideAt1024": 824,
    "preserveAspectRatio": true,
    "colorSpace": "sRGB",
    "icns": releasePath + "/MicFirst.icns",
    "exports": exports
]
let reportURL = root.appendingPathComponent(releasePath + "/export-report.json")
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL)
print("Exported \(catalog.images.count) AppIcon slots, documentation images and release master.")
print("Source alpha bounds: \(minX),\(minY) to \(maxX + 1),\(maxY + 1); target footprint: 824px / 1024px.")
