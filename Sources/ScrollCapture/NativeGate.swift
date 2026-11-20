import AppKit
import CaptureCore
import CryptoKit

extension AppModel {
    /// Production stream/coordinator/ledger; independent full-document NSView rendering oracle.
    func nativeGate() async {
        guard !busy, !running, !gateRunning else { return }
        cancel()
        let token = UUID(); gateID = token; gateRunning = true
        defer { if gateID == token { gateRunning = false } }
        var evidenceDirectory: URL?
        do {
            let host = FixtureHost.shared; host.show()
            guard let window = host.window, let scroll = host.scroll, let document = scroll.documentView else { throw CaptureError.invalidImage }
            scroll.contentView.scroll(to:.zero); scroll.reflectScrolledClipView(scroll.contentView)
            document.displayIfNeeded()
            guard let rep = document.bitmapImageRepForCachingDisplay(in:document.bounds) else { throw CaptureError.invalidImage }
            document.cacheDisplay(in:document.bounds,to:rep)
            guard let oracleImage = rep.cgImage else { throw CaptureError.invalidImage }
            let content = try await ScreenSource.windows()
            try gateCheck(token)
            guard let target = content.first(where: { $0.windowID == UInt32(window.windowNumber) }) else { throw CaptureError.invalidImage }
            selectWindow(target.windowID,fromGate:true); windows = content
            await capture(fromGate:true)
            try gateCheck(token)
            guard let snapshot else { throw CaptureError.invalidImage }
            let scale = CGFloat(snapshot.width)/window.frame.width
            let top = (window.frame.height-scroll.frame.height)*scale
            region = CGRect(x:16*scale,y:top+16*scale,width:(scroll.frame.width-32)*scale,height:(scroll.frame.height-32)*scale).integral
            let selectedRegion = region!
            let output = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("artifacts/native-\(UUID().uuidString)",isDirectory:true)
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            evidenceDirectory = output
            await start(fromGate:true)
            try gateCheck(token)
            guard let engine = session else { throw CaptureError.invalidImage }
            try await gateWait(token) { self.confirmedHeight > 0 || self.paused }
            guard !paused, running else { throw CaptureError.noOverlap }
            var positions: [Double] = [Double(scroll.contentView.bounds.minY)]
            for step in 1...5 {
                let before = seams
                scroll.contentView.scroll(to:NSPoint(x:0,y:step*120)); scroll.reflectScrolledClipView(scroll.contentView)
                try await gateWait(token) { self.seams > before || self.paused }
                guard !paused, running else { throw CaptureError.noOverlap }
                positions.append(Double(scroll.contentView.bounds.minY))
            }
            try gateCheck(token)
            await finish(fromGate:true)
            try gateCheck(token)
            let size = await engine.dimensions()
            try gateCheck(token)
            let result = try await engine.read(y:0,height:size.height)
            try gateCheck(token)
            let expectedRect = CGRect(x:16*scale,y:16*scale,width:selectedRegion.width,height:selectedRegion.height+600*scale)
            guard let expectedCG = oracleImage.cropping(to:expectedRect) else { throw CaptureError.invalidImage }
            let expected = try Raster(image:expectedCG)
            var maximum = 0, different = 0, sum: Int64 = 0
            if expected.width == result.width && expected.height == result.height {
                for i in result.bytes.indices where i % 4 != 3 {
                    let delta = abs(Int(result.bytes[i])-Int(expected.bytes[i])); maximum = max(maximum,delta); sum += Int64(delta)
                    if delta > 2 { different += 1 }
                }
            } else { different = Int.max }
            let passed = expected.width == result.width && expected.height == result.height && different == 0
            try result.png().write(to:output.appendingPathComponent("actual.png"),options:.atomic)
            try expected.png().write(to:output.appendingPathComponent("expected.png"),options:.atomic)
            let source = Bundle.main.url(forResource:"source-sha",withExtension:"txt").flatMap { try? String(contentsOf:$0,encoding:.utf8) } ?? "unknown"
            let report: [String:Any] = ["case":"native-controlled-production-stream","passed":passed,"source":source,
                "width":result.width,"height":result.height,"expectedWidth":expected.width,"expectedHeight":expected.height,
                "seams":seams,"hostPositions":positions,"scale":scale,"maxChannelError":maximum,"channelsOver2":different,
                "meanChannelError":Double(sum)/Double(result.width*result.height*3),"oracle":"independent full NSView render, known host scroll coordinates",
                "actualSHA256":SHA256.hash(data:Data(result.bytes)).map { String(format:"%02x",$0) }.joined(),
                "expectedSHA256":SHA256.hash(data:Data(expected.bytes)).map { String(format:"%02x",$0) }.joined()]
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("report.json"),options:.atomic)
            status = "受控原生验收 \(passed ? "通过" : "失败")：\(result.width)×\(result.height)，\(seams) 接缝；本地证据 \(output.lastPathComponent)"
        } catch {
            guard gateID == token else { return }
            if let evidenceDirectory {
                let failure: [String:Any] = ["case":"native-controlled-production-stream","passed":false,"error":error.localizedDescription,"confirmedHeight":confirmedHeight,"seams":seams]
                try? JSONSerialization.data(withJSONObject:failure,options:[.prettyPrinted,.sortedKeys]).write(to:evidenceDirectory.appendingPathComponent("failure.json"),options:.atomic)
            }
            if running { unresolved = true; await finish(fromGate:true) }
            guard gateID == token, gateRunning else { return }
            status = "受控原生验收未通过：\(error.localizedDescription)；\(status)"
        }
        showMain()
    }
    private func gateCheck(_ token: UUID) throws {
        guard gateRunning, gateID == token else { throw CancellationError() }
    }
    private func gateWait(_ token: UUID, _ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            try gateCheck(token)
            if predicate() { return }
            try await Task.sleep(for:.milliseconds(100))
        }
        throw CaptureError.noOverlap
    }
}
