import AppKit
import CaptureCore
import CryptoKit

extension AppModel {
    /// Production stream/coordinator/ledger; independent full-document NSView rendering oracle.
    func nativeGate() async {
        guard !busy, !running else { return }
        cancel()
        do {
            let host = FixtureHost.shared; host.show()
            guard let window = host.window, let scroll = host.scroll, let document = scroll.documentView else { throw CaptureError.invalidImage }
            scroll.contentView.scroll(to:.zero); scroll.reflectScrolledClipView(scroll.contentView)
            document.displayIfNeeded()
            guard let rep = document.bitmapImageRepForCachingDisplay(in:document.bounds) else { throw CaptureError.invalidImage }
            document.cacheDisplay(in:document.bounds,to:rep)
            guard let oracleImage = rep.cgImage else { throw CaptureError.invalidImage }
            let content = try await ScreenSource.windows()
            guard let target = content.first(where: { $0.windowID == UInt32(window.windowNumber) }) else { throw CaptureError.invalidImage }
            selectWindow(target.windowID); windows = content
            await capture()
            guard let snapshot else { throw CaptureError.invalidImage }
            let scale = CGFloat(snapshot.width)/window.frame.width
            let top = (window.frame.height-scroll.frame.height)*scale
            region = CGRect(x:16*scale,y:top+16*scale,width:(scroll.frame.width-32)*scale,height:(scroll.frame.height-32)*scale).integral
            let selectedRegion = region!
            let output = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("artifacts/native-\(UUID().uuidString)",isDirectory:true)
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            await start()
            try await gateWait { self.confirmedHeight > 0 || self.paused }
            guard !paused, running else { throw CaptureError.noOverlap }
            var positions: [Double] = [Double(scroll.contentView.bounds.minY)]
            for step in 1...5 {
                let before = seams
                scroll.contentView.scroll(to:NSPoint(x:0,y:step*120)); scroll.reflectScrolledClipView(scroll.contentView)
                try await gateWait { self.seams > before || self.paused }
                guard !paused, running else { throw CaptureError.noOverlap }
                positions.append(Double(scroll.contentView.bounds.minY))
            }
            await finish()
            guard let result = try await fullResultForGate() else { throw CaptureError.invalidImage }
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
            if running { unresolved = true; await finish() }
            status = "受控原生验收未通过：\(error.localizedDescription)；\(status)"
        }
        showMain()
    }
    private func gateWait(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for:.milliseconds(100))
        }
        throw CaptureError.noOverlap
    }
}
