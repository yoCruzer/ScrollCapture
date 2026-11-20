import XCTest
@testable import CaptureCore
import ImageIO

final class RasterTests: XCTestCase {
    func testPNGAndCropPreserveTopToBottomPixels() throws {
        let pixels: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255]
        let raster = try Raster(width: 2, height: 2, bytes: pixels)
        let source = CGImageSourceCreateWithData(try raster.png() as CFData, nil)!
        let decoded = try Raster(image: CGImageSourceCreateImageAtIndex(source, 0, nil)!)
        XCTAssertEqual(decoded, raster)
        XCTAssertEqual(try raster.crop(y: 1, height: 1).bytes, Array(pixels[8...]))
    }
    func testInvalidRasterRejected() { XCTAssertThrowsError(try Raster(width: 100, height: 100, bytes: [])) }
}
