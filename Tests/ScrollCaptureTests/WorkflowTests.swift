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
