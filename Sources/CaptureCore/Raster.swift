import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum CaptureError: Error, LocalizedError, Sendable {
    case invalidImage, geometryChanged, ambiguous, noOverlap, resourceLimit, storage
    public var errorDescription: String? {
        switch self {
        case .invalidImage: "无法读取画面"
        case .geometryChanged: "窗口尺寸或显示比例变化，请结束当前结果并重新框选"
        case .ambiguous: "位移不唯一：请回滚到已确认位置，或保存局部结果"
        case .noOverlap: "缺少可靠重叠：请缓慢回滚补采，或保存局部结果"
        case .resourceLimit: "已达到资源上限，请保存当前结果"
        case .storage: "写入失败，结果已保留，可重试"
        }
    }
}

/// Canonical, top-to-bottom, non-premultiplied opaque RGBA8 in sRGB.
public struct Raster: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let bytes: [UInt8]
    public init(width: Int, height: Int, bytes: [UInt8]) throws {
        guard width > 0, height > 0, width <= 16_384, height <= 65_536,
              width * height <= 40_000_000, bytes.count == width * height * 4 else { throw CaptureError.resourceLimit }
        self.width = width; self.height = height; self.bytes = bytes
    }
    public init(image: CGImage) throws {
        let w = image.width, h = image.height
        guard w > 0, h > 0, w <= 16_384, h <= 65_536, w * h <= 40_000_000 else { throw CaptureError.resourceLimit }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ok = data.withUnsafeMutableBytes { p -> Bool in
            guard let ctx = CGContext(data: p.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h)); return true
        }
        guard ok else { throw CaptureError.invalidImage }
        try self.init(width: w, height: h, bytes: data)
    }
    public func image() throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw CaptureError.invalidImage }
        return image
    }
    public func crop(x: Int = 0, y: Int, width w: Int? = nil, height h: Int) throws -> Raster {
        let w = w ?? width
        guard x >= 0, y >= 0, w > 0, h > 0, x + w <= width, y + h <= height else { throw CaptureError.invalidImage }
        var result = [UInt8](); result.reserveCapacity(w * h * 4)
        for row in y..<(y+h) { result.append(contentsOf: bytes[((row*width+x)*4)..<((row*width+x+w)*4)]) }
        return try Raster(width: w, height: h, bytes: result)
    }
    public func png() throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw CaptureError.storage }
        CGImageDestinationAddImage(dest, try image(), nil)
        guard CGImageDestinationFinalize(dest) else { throw CaptureError.storage }
        return data as Data
    }
}
