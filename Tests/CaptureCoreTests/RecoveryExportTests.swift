import XCTest
import ImageIO
@testable import CaptureCore

final class RecoveryExportTests: XCTestCase, @unchecked Sendable {
    let fixture = RegistrationTests()
    func testLongPeriodOutsideCommitSearchCannotAliasGapAsSmallStep() async throws {
        func periodic(_ start: Int) throws -> Raster {
            var bytes: [UInt8] = []
            for y in start..<(start+160) { bytes += try fixture.viewport(at:y % 150,height:1).bytes }
            return try Raster(width:64,height:160,bytes:bytes)
        }
        let s = try CaptureSession()
        _ = try await s.accept(periodic(0))
        do { _ = try await s.accept(periodic(20)); XCTFail("even a true small motion is ambiguous when another overlap aliases it") } catch {}
        do { _ = try await s.accept(periodic(170)); XCTFail("150-row alias must not hide a gap") } catch {}
        let size = await s.dimensions(); XCTAssertEqual(size.height,160)
    }
    func testLegalRepeatedBandsKeepDistinctPositions() async throws {
        func frame(_ start: Int, _ h: Int = 160) throws -> Raster {
            var bytes: [UInt8] = []
            for y in start..<(start+h) {
                // 12-row bands repeat, separated by unique evidence. Repetition is content, not duplication.
                let source = y % 80 < 12 ? y % 12 : y
                bytes += try fixture.viewport(at:source,height:1).bytes
            }
            return try Raster(width:64,height:h,bytes:bytes)
        }
        let s = try CaptureSession()
        for pos in stride(from:0,through:400,by:40) { _ = try await s.accept(frame(pos)) }
        let result = try await s.read(y:0,height:560)
        XCTAssertEqual(result,try frame(0,560))
    }
    func testFractionalInterpolationRejectsRatherThanAccumulateDrift() throws {
        let a = try fixture.viewport(at:0), b = try fixture.viewport(at:30), c = try fixture.viewport(at:31)
        let blended = zip(b.bytes,c.bytes).map { UInt8((UInt16($0)+UInt16($1))/2) }
        XCTAssertThrowsError(try Registration.estimate(previous:a,next:Raster(width:64,height:160,bytes:blended)))
    }
    func testDuplicateTexturedFrameAddsNothing() async throws {
        let s = try CaptureSession(), image = try fixture.viewport(at:0)
        _ = try await s.accept(image)
        let coverage = try await s.accept(image)
        XCTAssertEqual(coverage.appended,0); XCTAssertEqual(coverage.seams,0)
    }
    func testCancelledPermitCannotCommitOldFrame() async throws {
        let s = try CaptureSession(), permit = CommitPermit()
        _ = try await s.accept(fixture.viewport(at:0))
        permit.invalidate()
        do { _ = try await s.accept(fixture.viewport(at:50),permit:permit); XCTFail() } catch is CancellationError {} catch { XCTFail("wrong error") }
        let size = await s.dimensions(); XCTAssertEqual(size.height,160)
        let coverage = try await s.accept(fixture.viewport(at:50)); XCTAssertEqual(coverage.height,210)
        await s.seal()
        do { _ = try await s.accept(fixture.viewport(at:100)); XCTFail() } catch {}
    }
    func testPartsExactOrderAndExistingDestinationPreserved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false)
        defer { try? FileManager.default.removeItem(at:root) }
        let s = try CaptureSession(root:root)
        for y in stride(from:0,through:300,by:60) { _ = try await s.accept(fixture.viewport(at:y)) }
        await s.seal()
        let output = try await s.exportParts(parent:root,name:"result",partial:true,partPixels:64*100)
        let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:output.appendingPathComponent("manifest.json"))) as! [String:Any]
        XCTAssertEqual(manifest["height"] as? Int,460)
        XCTAssertEqual(manifest["integrity"] as? String,"partial-unconfirmed-tail")
        let parts = manifest["parts"] as! [[String:Any]]
        XCTAssertEqual(parts.count,5)
        var bytes: [UInt8] = []
        for (i,part) in parts.enumerated() {
            XCTAssertEqual(part["y"] as? Int,i*100)
            let data = try Data(contentsOf:output.appendingPathComponent(part["file"] as! String))
            let source = CGImageSourceCreateWithData(data as CFData,nil)!
            bytes += try Raster(image:CGImageSourceCreateImageAtIndex(source,0,nil)!).bytes
        }
        XCTAssertEqual(bytes,try fixture.viewport(at:0,height:460).bytes)
        do { _ = try await s.exportParts(parent:root,name:"result",partial:false); XCTFail() } catch {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:output.path).count,6)
        do { _ = try await s.exportParts(parent:root.appendingPathComponent("absent"),name:"failure",partial:false); XCTFail() } catch {}
        let retry = try await s.exportParts(parent:root,name:"retry",partial:false,partPixels:64*100)
        XCTAssertTrue(FileManager.default.fileExists(atPath:retry.appendingPathComponent("part-0005.png").path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:root.path).contains { $0.hasPrefix(".ScrollCapture-export-") })
    }
    func testExportCancellationLeavesNoDestinationOrStage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false)
        defer { try? FileManager.default.removeItem(at:root) }
        let s = try CaptureSession(root:root)
        _ = try await s.accept(fixture.viewport(at:0)); await s.seal()
        let task = Task { try await s.exportParts(parent:root,name:"cancelled",partial:false,partPixels:64) }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath:root.appendingPathComponent("cancelled").path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:root.path).contains { $0.hasPrefix(".ScrollCapture-export-") })
    }
    func testInvalidCropExtremeCoordinatesDoNotTrap() throws {
        let r = try fixture.viewport(at:0)
        XCTAssertThrowsError(try r.crop(x:Int.max,y:0,width:Int.max,height:2))
        XCTAssertThrowsError(try r.crop(y:Int.max,height:Int.max))
    }
}
