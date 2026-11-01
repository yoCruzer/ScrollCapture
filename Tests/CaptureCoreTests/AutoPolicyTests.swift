import XCTest
@testable import CaptureCore

final class AutoPolicyTests: XCTestCase {
    func testOnlyNewCommittedPixelsPermitNextInput() {
        var p = AutoPolicy(now:0)
        XCTAssertEqual(p.evaluate(now:0,height:200,acceptedAt:-1,safeTarget:true),.send)
        XCTAssertEqual(p.evaluate(now:1,height:200,acceptedAt:0.8,safeTarget:true),.wait)
        XCTAssertEqual(p.evaluate(now:1.1,height:240,acceptedAt:-1,safeTarget:true),.wait)
        XCTAssertEqual(p.evaluate(now:1.2,height:240,acceptedAt:1,safeTarget:true),.wait)
        XCTAssertEqual(p.evaluate(now:1.6,height:240,acceptedAt:1,safeTarget:true),.send)
    }
    func testNoProgressNeverMeansBottomAndFocusFailsImmediately() {
        var p = AutoPolicy(now:0)
        _ = p.evaluate(now:0,height:200,acceptedAt:-1,safeTarget:true)
        if case .stop(let reason) = p.evaluate(now:3,height:200,acceptedAt:2,safeTarget:true) { XCTAssertTrue(reason.contains("未确认")) } else { XCTFail() }
        if case .stop = p.evaluate(now:1,height:400,acceptedAt:0.5,safeTarget:false) {} else { XCTFail() }
    }
    func testBoundedStepsAndDuration() {
        var p = AutoPolicy(now:0)
        for i in 0..<80 { XCTAssertEqual(p.evaluate(now:Double(i),height:200+i,acceptedAt:Double(i)-0.5,safeTarget:true),.send) }
        if case .stop = p.evaluate(now:80,height:280,acceptedAt:79.5,safeTarget:true) {} else { XCTFail() }
        var q = AutoPolicy(now:0)
        if case .stop = q.evaluate(now:120,height:100,acceptedAt:0,safeTarget:true) {} else { XCTFail() }
    }
}
