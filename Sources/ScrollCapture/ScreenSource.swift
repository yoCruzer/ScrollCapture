import AppKit
import ScreenCaptureKit
import CaptureCore

@MainActor
enum ScreenSource {
    static func windows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows.filter { $0.windowLayer == 0 && $0.frame.width >= 100 && $0.frame.height >= 100 }
            .sorted { ($0.owningApplication?.applicationName ?? "") < ($1.owningApplication?.applicationName ?? "") }
    }
    static func configuration(_ filter: SCContentFilter) -> SCStreamConfiguration {
        let c = SCStreamConfiguration()
        c.width = Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded())
        c.height = Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded())
        c.showsCursor = false; c.ignoreShadowsSingleWindow = true
        c.captureResolution = .best
        c.pixelFormat = kCVPixelFormatType_32BGRA
        c.colorSpaceName = CGColorSpace.sRGB
        c.minimumFrameInterval = CMTime(value: 1, timescale: 5)
        c.queueDepth = 3
        return c
    }
    static func screenshot(_ window: SCWindow) async throws -> Raster {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = configuration(filter)
        guard config.width > 0, config.height > 0, config.width <= 16_384, config.height <= 16_384,
              config.width * config.height <= 8_000_000 else { throw CaptureError.resourceLimit }
        return try await Raster(image: SCScreenshotManager.captureImage(contentFilter: filter, configuration: config))
    }
}
