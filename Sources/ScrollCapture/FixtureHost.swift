import AppKit
import CaptureCore

/// Only synthetic content. Expected raster is generated independently of registration/cropping.
@MainActor
final class FixtureHost {
    static let shared = FixtureHost()
    var window: NSWindow?
    var scroll: NSScrollView?
    func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 520, height: 440),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "ScrollCapture 合成验收窗口"
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 440))
        scroll.hasVerticalScroller = false; scroll.drawsBackground = true
        let document = FixtureView(frame: NSRect(x: 0, y: 0, width: 520, height: 4400))
        scroll.documentView = document; window.contentView = scroll
        self.window = window; self.scroll = scroll
        window.makeKeyAndOrderFront(nil)
    }
}

final class FixtureView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); dirtyRect.fill()
        for row in max(0, Int(dirtyRect.minY / 20))..<min(220, Int(dirtyRect.maxY / 20) + 1) {
            let rect = NSRect(x: 0, y: row * 20, width: 520, height: 20)
            NSColor(calibratedRed: CGFloat((row * 37) % 193) / 255,
                    green: CGFloat((row * 71 + 41) % 191) / 255,
                    blue: CGFloat((row * 23 + 97) % 197) / 255, alpha: 1).setFill()
            rect.fill()
            let text = "行 \(String(format: "%03d", row))  ·  ScrollCapture 合成正文  ·  \(row % 7 == 0 ? "合法重复内容" : "独立行标识")"
            (text as NSString).draw(at: NSPoint(x: 12, y: row * 20 + 2), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
        }
    }
}
