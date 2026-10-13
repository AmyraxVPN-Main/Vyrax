// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import AppKit
let directory = CommandLine.arguments[1]
// A centered monochrome V; template images adapt to light/dark menu bars.
for scale in [1, 2] {
    let size = 18 * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:size, pixelsHigh:size,
        bitsPerSample:8, samplesPerPixel:4, hasAlpha:true, isPlanar:false,
        colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    func mark(_ points: [(Double, Double)]) {
        let path = NSBezierPath()
        for (index, point) in points.enumerated() {
            let mapped = NSPoint(x:CGFloat((1 + point.0 / 32 * 16) * Double(scale)),
                                 y:CGFloat((14 - point.1 / 20 * 10) * Double(scale)))
            if index == 0 { path.move(to:mapped) } else { path.line(to:mapped) }
        }
        path.close();NSColor.black.setFill();path.fill()
    }
    mark([(1,1),(11,1),(16,10),(21,1),(31,1),(18.6,19),(13.4,19)])
    mark([(13.4,1),(18.6,1),(16,5.6)])
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "trayTemplate.png" : "trayTemplate@2x.png"
    try bitmap.representation(using:.png, properties:[:])!.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name))
}
