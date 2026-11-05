import AppKit
import Foundation

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let inset = size * 0.06
    let bound = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1).setFill()
    NSBezierPath(roundedRect: bound, xRadius: size * 0.22, yRadius: size * 0.22).fill()

    let screen = NSRect(x: size * 0.22, y: size * 0.28, width: size * 0.56, height: size * 0.40)
    NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
    NSBezierPath(roundedRect: screen, xRadius: size * 0.02, yRadius: size * 0.02).fill()

    NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.35, alpha: 1).setFill()
    let dot = max(2, size * 0.035)
    func led(_ x: CGFloat, _ y: CGFloat) {
        NSBezierPath(ovalIn: NSRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)).fill()
    }
    let left = 8, top = 14, right = 8
    for i in 0..<left {
        let t = CGFloat(i) / CGFloat(max(left - 1, 1))
        led(size * 0.18, size * (0.30 + t * 0.40))
    }
    for i in 0..<top {
        let t = CGFloat(i) / CGFloat(max(top - 1, 1))
        led(size * (0.22 + t * 0.56), size * 0.74)
    }
    for i in 0..<right {
        let t = CGFloat(i) / CGFloat(max(right - 1, 1))
        led(size * 0.82, size * (0.70 - t * 0.40))
    }
    image.unlockFocus()
    return image
}

func drawMenuTemplate(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let size = CGFloat(pixels)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    NSColor.black.setStroke()
    NSColor.black.setFill()
    let path = NSBezierPath()
    path.lineWidth = size * 0.10
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    let l = size * 0.18
    let r = size * 0.82
    let t = size * 0.78
    let b = size * 0.28
    path.move(to: NSPoint(x: l, y: b))
    path.line(to: NSPoint(x: l, y: t))
    path.line(to: NSPoint(x: r, y: t))
    path.line(to: NSPoint(x: r, y: b))
    path.stroke()

    let d = size * 0.11
    for i in 0..<5 {
        let x = l + (r - l) * CGFloat(i) / 4
        NSBezierPath(ovalIn: NSRect(x: x - d / 2, y: t - d / 2, width: d, height: d)).fill()
    }
    for i in 1...3 {
        let y = t - (t - b) * CGFloat(i) / 4
        NSBezierPath(ovalIn: NSRect(x: l - d / 2, y: y - d / 2, width: d, height: d)).fill()
        NSBezierPath(ovalIn: NSRect(x: r - d / 2, y: y - d / 2, width: d, height: d)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ image: NSImage, to path: String, pixels: Int) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in entries {
    try writePNG(drawAppIcon(size: CGFloat(px)), to: iconset.appendingPathComponent(name).path, pixels: px)
}

for (name, px) in [("MenuBarIcon.png", 22), ("MenuBarIcon@2x.png", 44)] {
    let path = root.appendingPathComponent("Resources/\(name)")
    try drawMenuTemplate(pixels: px).representation(using: .png, properties: [:])!
        .write(to: path)
}

print("ok")
