// Renders the app icon, icon/icon.png: a white display with sparkles on a
// blue rounded square, on the standard macOS icon grid.
//
//   swift icon/make-icon.swift
//
// make-app.sh turns the PNG into AppIcon.icns, so rerun this only to change
// the design. To use your own artwork, replace icon/icon.png with any
// 1024x1024 PNG.
import AppKit

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icons are an 824pt square with a 185pt corner radius on a 1024 canvas;
// the margin leaves room for the shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
    starting: NSColor(srgbRed: 0.24, green: 0.56, blue: 1.00, alpha: 1),
    ending: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.75, alpha: 1)
)!.draw(in: shape, angle: -90)

func symbol(_ name: String, _ pointSize: CGFloat, _ color: NSColor) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

// Drawn centred on a point.
func draw(_ image: NSImage, at center: NSPoint) {
    let s = image.size
    image.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
}

// The display, a little down and left to make room for the sparkles.
draw(symbol("display", 420, .white), at: NSPoint(x: tile.midX - 30, y: tile.midY - 40))

// Sparkles: a big one and a small one at the top right.
let gold = NSColor(srgbRed: 1.00, green: 0.93, blue: 0.62, alpha: 1)
draw(symbol("sparkle", 190, gold), at: NSPoint(x: tile.maxX - 175, y: tile.maxY - 175))
draw(symbol("sparkle", 95, gold), at: NSPoint(x: tile.maxX - 310, y: tile.maxY - 105))

NSGraphicsContext.current = nil
let out = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().appendingPathComponent("icon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
