// generates Resources/AppIcon.icns
// swiftc -o /tmp/make-icon Tools/make-icon.swift && /tmp/make-icon
import AppKit

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // 824pt body in 1024 canvas
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    // shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(white: 0, alpha: 0.35).cgColor)
    NSColor.black.setFill()
    shape.fill()
    cg.restoreGState()

    // gradient
    cg.saveGState()
    shape.addClip()
    let gradient = NSGradient(colors: [
        NSColor(red: 0.20, green: 0.21, blue: 0.27, alpha: 1),
        NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
    ])!
    gradient.draw(in: body, angle: -90)
    // top highlight
    NSColor(white: 1, alpha: 0.07).setStroke()
    let inner = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: 184, yRadius: 184)
    inner.lineWidth = 3
    inner.stroke()
    cg.restoreGState()

    // bars
    let heights: [CGFloat] = [0.26, 0.52, 0.82, 0.52, 0.26]
    let barWidth: CGFloat = 74
    let gap: CGFloat = 46
    let total = barWidth * 5 + gap * 4
    var x = (1024 - total) / 2
    let maxHeight: CGFloat = 520
    for h in heights {
        let height = maxHeight * h
        let rect = NSRect(x: x, y: 512 - height / 2, width: barWidth, height: height)
        let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: 24, color: NSColor(red: 0.6, green: 0.7, blue: 1, alpha: 0.35).cgColor)
        NSGradient(colors: [NSColor.white, NSColor(red: 0.80, green: 0.86, blue: 1, alpha: 1)])!
            .draw(in: path, angle: -90)
        cg.restoreGState()
        x += barWidth + gap
    }

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let iconset = "/tmp/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, pixels) in variants {
    try render(pixels: pixels).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
try render(pixels: 1024).write(to: URL(fileURLWithPath: "/tmp/AppIcon-preview.png"))
print("iconset written; run: iconutil -c icns \(iconset) -o Resources/AppIcon.icns")
