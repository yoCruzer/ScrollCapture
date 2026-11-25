import AppKit
import Foundation

// Render a scrollable document once. Preview displays this immutable PNG at actual size.
guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift Scripts/make-preview-fixture.swift output.png") }
let width = 760, height = 6000
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let words = ["wood", "copper", "linen", "graphite", "ink", "silver", "ochre", "paper", "glass", "stone", "clay"]
var seed: UInt64 = 9701
for row in 0..<(height / 27) {
    var line = String(format: "%03d   ", row)
    for _ in 0..<(5 + row % 7) {
        seed = seed &* 6364136223846793005 &+ 1
        line += words[Int((seed >> 32) % UInt64(words.count))] + " "
    }
    (line as NSString).draw(at: NSPoint(x: 32, y: height - (row + 1) * 27),
                            withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.black])
}
NSGraphicsContext.restoreGraphicsState()
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .withoutOverwriting)
