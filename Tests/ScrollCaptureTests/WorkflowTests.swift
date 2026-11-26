import XCTest
import CaptureCore
@testable import ScrollCapture

@MainActor
final class WorkflowTests: XCTestCase {
    private func sample() throws -> Raster {
        let bytes = (0..<8).flatMap { row in (0..<10).flatMap { column in
            [UInt8(row), UInt8(column), UInt8(127), UInt8(255)]
        } }
        return try Raster(width: 10, height: 8, bytes: bytes)
    }

    func testFirstScreenRepaintAndTransientGapRecoverFromConfirmedFrame() async throws {
        func frame(_ origin: Int) throws -> Raster {
            var pixels = [UInt8]()
            for y in origin..<(origin + 160) {
                for x in 0..<64 {
                    if y < 10 || (150..<160).contains(y) {
                        pixels += [255, 255, 255, 255]
                        continue
                    }
                    let value = (y * 1097 + x * 733) &* 2971
                    pixels += [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 9),
                               UInt8(truncatingIfNeeded: value >> 16), 255]
                }
            }
            return try Raster(width: 64, height: 160, bytes: pixels)
        }
        let model = AppModel(), engine = try CaptureSession()
        func observe(_ origin: Int) async throws {
            let raster = try frame(origin)
            do {
                let coverage = try await engine.accept(raster)
                model.showCoverage(coverage, frame: raster, time: 1)
            } catch { model.handleFrameFailure(error) }
        }

        try await observe(0)
        try await observe(0)
        XCTAssertFalse(model.paused)
        model.automatic = true
        try await observe(500)
        XCTAssertFalse(model.automatic)
        XCTAssertTrue(model.unresolved)
        XCTAssertFalse(model.paused, "Continue inspecting frames while the confirmed height is frozen")
        try await observe(0)
        XCTAssertTrue(model.unresolved, "Identical pixels cannot certify recovery")
        XCTAssertEqual(model.confirmedHeight, 160)
        try await observe(20)
        XCTAssertEqual(model.seams, 1)
        XCTAssertEqual(model.confirmedHeight, 180)
        XCTAssertFalse(model.unresolved)
        let tail = try await engine.read(y: 20, height: 160)
        XCTAssertEqual(tail, try frame(20))

        model.handleFrameFailure(CaptureError.geometryChanged)
        XCTAssertTrue(model.paused, "Geometry failures still require explicit intervention")
    }

    func testUnmatchedFramesCannotExtendRecoveryWindowOrReopenPause() {
        let model = AppModel()
        model.handleFrameFailure(CaptureError.ambiguous, now: 10)
        XCTAssertTrue(model.canInspectFrame(at: 11))
        model.handleFrameFailure(CaptureError.noOverlap, now: 11.9)
        XCTAssertFalse(model.canInspectFrame(at: 12))
        XCTAssertTrue(model.paused)
        XCTAssertTrue(model.unresolved)
        XCTAssertFalse(model.canInspectFrame(at: 50))
    }

    func testUnconfirmedSelectionCannotStartExport() async throws {
        let model = AppModel()
        model.bitmap = try sample(); model.selecting = true
        model.beginSave()
        XCTAssertFalse(model.exporting, "The selection preview must not silently export the entire window.")
        let previous = model.status
        await model.copy()
        XCTAssertEqual(model.status, previous)
    }

    func testChangingTargetInvalidatesVisiblePreview() throws {
        let model = AppModel()
        model.bitmap = try sample(); model.selecting = true
        model.region = CGRect(x: 1, y: 1, width: 4, height: 4)
        model.selectWindow(42)
        XCTAssertEqual(model.selected, 42)
        XCTAssertNil(model.bitmap)
        XCTAssertNil(model.region)
        XCTAssertFalse(model.selecting)
        model.busy = true
        model.selectWindow(43)
        XCTAssertEqual(model.selected, 42, "A busy operation still owns its target.")
    }

    func testAutomaticNoticeSurvivesFrameStatusAndRepeatedStops() {
        let model = AppModel()
        model.automatic = true; model.automaticNotice = "正在尝试自动滚动"
        model.stopAutomatic()
        XCTAssertFalse(model.automatic)
        XCTAssertEqual(model.automaticNotice, "自动滚动已停止。")
        model.automaticNotice = "目标失焦；已切回手动。"
        model.status = "画面已定位，尚无新增覆盖"
        model.stopAutomatic()
        XCTAssertEqual(model.automaticNotice, "目标失焦；已切回手动。")
    }

    func testConsecutiveCropsUseCurrentResultAndPreserveInvalidInput() async throws {
        let model = AppModel()
        model.bitmap = try sample()
        model.trimTop = 2; model.trimBottom = 1
        XCTAssertTrue(model.canTrimResult)
        await model.trimResult()
        XCTAssertEqual(model.resultHeight, 5)
        XCTAssertEqual(model.bitmap?.bytes.first, 2)
        model.trimTop = 1; model.trimBottom = 1
        await model.trimResult()
        XCTAssertEqual(model.resultHeight, 3)
        XCTAssertEqual(model.bitmap?.bytes.first, 3)
        let retained = model.bitmap
        model.trimTop = 2; model.trimBottom = 1
        XCTAssertFalse(model.canTrimResult)
        await model.trimResult()
        XCTAssertEqual(model.bitmap, retained, "Invalid crop must keep the last usable result.")
        model.trimTop = -1; model.trimBottom = 0
        XCTAssertFalse(model.canTrimResult)
        model.trimTop = Int.max
        XCTAssertFalse(model.canTrimResult)
    }
}
