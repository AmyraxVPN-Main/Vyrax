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
    let path = NSBezierPath()
    path.move(to:NSPoint(x:CGFloat(3*scale), y:CGFloat(14*scale)))
    path.line(to:NSPoint(x:CGFloat(9*scale), y:CGFloat(4*scale)))
    path.line(to:NSPoint(x:CGFloat(15*scale), y:CGFloat(14*scale)))
    path.lineWidth = CGFloat(2*scale)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    NSColor.black.setStroke(); path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "trayTemplate.png" : "trayTemplate@2x.png"
    try bitmap.representation(using:.png, properties:[:])!.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name))
}
