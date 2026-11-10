// Rebuild with: xcrun swift scripts/generate-icon.swift
import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("build/ClipDock.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
func draw(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = AffineTransform(scale: scale)
    (transform as NSAffineTransform).concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.58, blue: 0.98, alpha: 1), ending: NSColor(srgbRed: 0.18, green: 0.29, blue: 0.83, alpha: 1))!.draw(in: tile, angle: -75)
    NSColor.white.withAlphaComponent(0.34).setFill()
    NSBezierPath(roundedRect: NSRect(x: 238, y: 306, width: 416, height: 464), xRadius: 72, yRadius: 72).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 356, y: 222, width: 432, height: 460), xRadius: 72, yRadius: 72).fill()
    NSColor(srgbRed: 0.26, green: 0.44, blue: 0.9, alpha: 1).setFill()
    for (y, width) in [(520, 244), (426, 244), (332, 152)] {
        NSBezierPath(roundedRect: NSRect(x: 446, y: y, width: width, height: 28), xRadius: 14, yRadius: 14).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try draw(size: pointSize * scale).write(to: folder.appendingPathComponent("icon_\(pointSize)x\(pointSize)\(suffix).png"))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", folder.path, "-o", root.appendingPathComponent("ClipDock/Resources/ClipDock.icns").path]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(1) }
