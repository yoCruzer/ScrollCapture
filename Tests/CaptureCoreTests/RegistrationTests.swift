import XCTest
@testable import CaptureCore

final class RegistrationTests: XCTestCase, @unchecked Sendable {
    func testBoundedHDSearch() throws {
        let a = try viewport(at:0,height:720,width:1280), b = try viewport(at:240,height:720,width:1280)
        let start = ContinuousClock.now
        XCTAssertEqual(try Registration.estimate(previous:a,next:b).dy,240)
        print("HD_SEARCH_1280x720 elapsed=\(start.duration(to:.now))")
    }
    // Independent coordinate oracle: each world row is generated directly, never by production crop.
    func viewport(at y: Int, height: Int = 160, width: Int = 64, periodic: Bool = false) throws -> Raster {
        var bytes: [UInt8] = []
        for row in y..<(y+height) {
            for x in 0..<width {
                var v = UInt64((periodic ? row % 16 : row) * 1097 + x * 733 + 17)
                v = (v ^ (v >> 7)) &* 0x9e3779b97f4a7c15
                bytes += [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 12), UInt8(truncatingIfNeeded: v >> 24), 255]
            }
        }
        return try Raster(width: width, height: height, bytes: bytes)
    }
    func testTwentySeamsAndMicroMotionAgainstIndependentTruth() async throws {
        let session = try CaptureSession()
        for i in 0...24 { _ = try await session.accept(viewport(at: i*31)) }
        _ = try await session.accept(viewport(at: 745))
        _ = try await session.accept(viewport(at: 744))
        _ = try await session.accept(viewport(at: 746))
        let result = try await session.read(y: 0, height: 906)
        XCTAssertEqual(result, try viewport(at: 0, height: 906))
    }
    func testSlowScrollOnWhiteListUsesInkBetweenSampleColumns() async throws {
        // Independent world coordinates. Short list entries occupy a narrow column
        // on a wide white canvas, between the old 32 horizontal sample points.
        func list(at origin: Int, height: Int) throws -> Raster {
            let width = 1024
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                let worldY = origin + y
                for x in 0..<128 where (10..<30).contains(x % 32) && worldY % 14 < 10 {
                    let ink = ((worldY * 1097 + x * 733) ^ (worldY * 29 + x * 31)) &* 127
                    let index = (y * width + x) * 4
                    for channel in 0..<3 { pixels[index + channel] = UInt8(truncatingIfNeeded: ink) }
                }
            }
            return try Raster(width: width, height: height, bytes: pixels)
        }
        let session = try CaptureSession()
        let positions = [0, 1, 5, 18, 19, 25, 39]
        for origin in positions {
            let coverage = try await session.accept(list(at: origin, height: 160))
            XCTAssertEqual(coverage.height, origin + 160)
        }
        await session.seal()
        let result = try await session.read(y: 0, height: 199)
        XCTAssertEqual(result, try list(at: 0, height: 199))
    }

    func testAmbiguousPeriodicAndSolidDoNotGuess() throws {
        XCTAssertThrowsError(try Registration.estimate(previous: viewport(at: 0, periodic: true), next: viewport(at: 32, periodic: true)))
        let solid = try Raster(width: 64, height: 160, bytes: [UInt8](repeating: 255, count: 64*160*4))
        XCTAssertThrowsError(try Registration.estimate(previous: solid, next: solid))
    }
    func testGapThenRollbackAndReversePreservesPrefix() async throws {
        let session = try CaptureSession()
        _ = try await session.accept(viewport(at: 0))
        _ = try await session.accept(viewport(at: 70))
        do { _ = try await session.accept(viewport(at: 600)); XCTFail("must reject gap") } catch {}
        var size = await session.dimensions(); XCTAssertEqual(size.height,230)
        _ = try await session.accept(viewport(at: 30))
        _ = try await session.accept(viewport(at: 80))
        _ = try await session.accept(viewport(at: 150))
        size = await session.dimensions(); XCTAssertEqual(size.height,310)
        let result = try await session.read(y:0,height:310)
        XCTAssertEqual(result, try viewport(at:0,height:310))
    }
    func testFixedOverlayFailsClosed() throws {
        let a = try viewport(at: 0), b = try viewport(at: 50)
        var bytes = b.bytes
        bytes.replaceSubrange(0..<(64*20*4), with: a.bytes[0..<(64*20*4)])
        XCTAssertThrowsError(try Registration.estimate(previous:a,next:Raster(width:64,height:160,bytes:bytes)))
    }
    func testSizeChangeAndResourceFailurePreserveLedger() async throws {
        let session = try CaptureSession(maxPixels: 64*200)
        _ = try await session.accept(viewport(at:0))
        do { _ = try await session.accept(viewport(at:50)); XCTFail() } catch {}
        do { _ = try await session.accept(viewport(at:0,width:65)); XCTFail() } catch {}
        let size = await session.dimensions(); XCTAssertEqual(size.height,160)
        await session.cancel()
        do { _ = try await session.accept(viewport(at:0)); XCTFail() } catch {}
    }
}
