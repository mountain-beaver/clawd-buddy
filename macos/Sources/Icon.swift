import AppKit

/// Renders the app icon iconset: `ClawdBuddy make-icon <dir.iconset>`.
enum IconMaker {
    static func run(into dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let sizes: [(String, Int)] = [
            ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
            ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
            ("512x512", 512), ("512x512@2x", 1024),
        ]
        for (name, px) in sizes {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            let gc = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current = gc
            let ctx = gc.cgContext
            // draw in a flipped 1024 canvas
            ctx.translateBy(x: 0, y: CGFloat(px))
            ctx.scaleBy(x: CGFloat(px) / 1024, y: -CGFloat(px) / 1024)
            drawIcon(ctx)
            NSGraphicsContext.restoreGraphicsState()
            let data = rep.representation(using: .png, properties: [:])!
            try? data.write(to: URL(fileURLWithPath: "\(dir)/icon_\(name).png"))
        }
    }

    private static func drawIcon(_ ctx: CGContext) {
        // macOS icon grid: 824pt tile centred in the 1024 canvas
        let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
        let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

        ctx.saveGState()
        // shadow offsets ignore the flipped CTM, so negative is down
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        NSColor(srgbRed: 0.98, green: 0.976, blue: 0.96, alpha: 1).setFill()
        shape.fill()
        ctx.restoreGState()

        ctx.saveGState()
        shape.addClip()
        NSGradient(colors: [NSColor(srgbRed: 0.988, green: 0.984, blue: 0.97, alpha: 1),
                            NSColor(srgbRed: 0.937, green: 0.918, blue: 0.878, alpha: 1)])!
            .draw(in: tile, angle: 90)

        // floor shadow
        NSColor.black.withAlphaComponent(0.13).setFill()
        NSBezierPath(ovalIn: NSRect(x: 292, y: 712, width: 440, height: 46)).fill()

        // pixel sparkles
        ctx.setShouldAntialias(false)
        Palette.body.withAlphaComponent(0.55).setFill()
        for (x, y, s) in [(222.0, 250.0, 22.0), (790.0, 300.0, 16.0)] {
            NSRect(x: x, y: y - s, width: s, height: s * 3).fill()
            NSRect(x: x - s, y: y, width: s * 3, height: s).fill()
        }

        let u: CGFloat = 38
        BuddyView.drawWavingCrab(at: NSPoint(x: 512 - 7 * u, y: 330), unit: u, happy: false)
        ctx.restoreGState()

        NSColor.black.withAlphaComponent(0.06).setStroke()
        shape.lineWidth = 2
        shape.stroke()
    }
}
