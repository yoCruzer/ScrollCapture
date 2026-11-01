import AppKit
import SwiftUI
import ScreenCaptureKit
import CaptureCore
import Carbon

@MainActor
final class AppModel: ObservableObject {
    @Published var windows: [SCWindow] = []
    @Published var selected: UInt32 = 0
    @Published var status = "选择一个非敏感窗口开始；所有图像仅在本机处理。"
    @Published var bitmap: Raster?
    @Published var busy = false
    @Published var running = false
    @Published var paused = false
    @Published var selecting = false
    @Published var unresolved = false
    @Published var region: CGRect?
    @Published var confirmedHeight = 0
    @Published var seams = 0
    @Published var automatic = false
    @Published var shortcut = UserDefaults.standard.integer(forKey:"shortcut")
    @Published var trimTop = 0
    @Published var trimBottom = 0
    @Published var exporting = false
    private var exportRange: Range<Int>?
    private var exportTask: Task<Void,Never>?
    private(set) var snapshot: Raster?
    private var snapshotWindow: SCWindow?
    private var generation = UUID()
    private var permit = CommitPermit()
    private var attempt = 0
    private var session: CaptureSession?
    private var source: LiveStream?
    private var captureTask: Task<Void,Never>?
    private let hud = CaptureHUD()
    private let scrollDriver = ScrollDriver()
    private var activeWindow: SCWindow?
    private var activeRegion: CGRect?
    private var activeScale: CGFloat = 1
    private var acceptedAt: Double = 0
    private let hotKey = HotKey()
    private var lastTime = -Double.infinity
    private var lastSequence: UInt64 = 0
    private var metadata: (CGRect, Double, Double)?
    private var watchdog: Task<Void,Never>?
    private var recoveryAttempts = 0

    func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.title == "ScrollCapture" })?.makeKeyAndOrderFront(nil)
    }
    func selectionChanged() {
        guard !running else { return }
        generation = UUID(); busy = false; snapshot = nil; snapshotWindow = nil; region = nil; selecting = false
    }
    func selectWindow(_ id: UInt32) { guard !busy, !running else { return }; selected = id; selectionChanged() }
    func configureShortcut() {
        hotKey.action = { [weak self] in self?.showMain() }
        let codes: [UInt32?] = [UInt32(kVK_ANSI_S),UInt32(kVK_ANSI_D),nil]
        guard codes.indices.contains(shortcut) else { shortcut = 0; return }
        if !hotKey.configure(keyCode:codes[shortcut]) { status = "快捷键注册失败，请选择另一个组合。" }
        UserDefaults.standard.set(shortcut,forKey:"shortcut")
    }
    func fullResultForGate() async throws -> Raster? {
        guard let session else { return bitmap }
        let size = await session.dimensions()
        return try await session.read(y:0,height:size.height)
    }
    func refresh() async {
        guard !busy, !running else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let result = try await ScreenSource.windows()
            guard token == generation else { return }
            windows = result; status = "选择窗口，获取画面；再框选可滚动的正文。"
        } catch { if token == generation { status = "需要屏幕录制权限。请在系统设置中允许 ScrollCapture，然后退出并重新打开。" } }
    }
    func capture() async {
        guard !busy, !running, let window = windows.first(where: { $0.windowID == selected }) else { return }
        let token = generation, target = selected; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image = try await ScreenSource.screenshot(window)
            guard token == generation, target == selected else { return }
            bitmap = image; snapshot = image; snapshotWindow = window; region = nil; session = nil; selecting = true
            exportRange = nil; trimTop = 0; trimBottom = 0
            unresolved = false; status = "窗口画面 \(image.width) × \(image.height) px；拖选正文或直接保存。"
        } catch { if token == generation { status = error.localizedDescription } }
    }
    func cropped(_ image: Raster, region: CGRect?) throws -> Raster {
        guard let region else { return image }
        return try image.crop(x: Int(region.minX), y: Int(region.minY), width: Int(region.width), height: Int(region.height))
    }
    func regionScreenshot() {
        guard !busy, !running, let snapshot else { return }
        do { bitmap = try cropped(snapshot,region:region); session = nil; selecting = false; status = "区域截图完成" }
        catch { status = error.localizedDescription }
    }
    func start() async {
        guard !busy, !running, let snapshotWindow, let snapshot, snapshotWindow.windowID == selected else { return }
        let token = UUID(); generation = token; busy = true
        permit.invalidate(); permit = CommitPermit(); attempt += 1; recoveryAttempts = 0
        defer { if token == generation { busy = false } }
        let frozenRegion = region
        do {
            let fresh = try await ScreenSource.windows()
            guard token == generation else { return }
            guard let window = fresh.first(where: { $0.windowID == snapshotWindow.windowID }), window.frame == snapshotWindow.frame else { throw CaptureError.geometryChanged }
            let engine = try CaptureSession(); let live = try LiveStream(window:window)
            source = live; session = engine; lastTime = -Double.infinity; lastSequence = 0; metadata = nil
            try await live.start()
            guard token == generation else { await live.stop(); return }
            running = true; paused = false; unresolved = false; selecting = false; confirmedHeight = 0; seams = 0
            exportRange = nil; trimTop = 0; trimBottom = 0
            activeWindow = window; activeRegion = frozenRegion ?? CGRect(x:0,y:0,width:snapshot.width,height:snapshot.height)
            activeScale = CGFloat(snapshot.width)/window.frame.width
            status = "将鼠标放在正文中缓慢向下滚动；当前范围由你结束，不推断文档到底。"
            hud.show(model:self)
            watchdog?.cancel()
            watchdog = Task { [weak self] in
                do { try await Task.sleep(for:.seconds(8)) } catch { return }
                guard let self, token == self.generation, self.running else { return }
                if self.confirmedHeight == 0 {
                    self.paused = true; self.unresolved = true
                    self.status = "8 秒内未收到有效帧，请检查权限/目标可见性，完成后重新开始。"
                }
                do { try await Task.sleep(for:.seconds(592)) } catch { return }
                guard token == self.generation, self.running else { return }
                self.unresolved = true
                await self.finish()
                self.status = "达到 10 分钟会话上限；已保留确认范围，请保存。"
            }
            if window.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier {
                FixtureHost.shared.window?.makeKeyAndOrderFront(nil)
            } else {
                NSApp.windows.first(where: { $0.title == "ScrollCapture" })?.orderOut(nil)
                if let pid = window.owningApplication?.processID { NSRunningApplication(processIdentifier:pid)?.activate() }
            }
            captureTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await frame in live.frames {
                        guard !Task.isCancelled, token == self.generation else { break }
                        guard frame.time.isFinite, frame.time > self.lastTime else { continue }
                        self.lastTime = frame.time
                        let dropped = self.lastSequence > 0 && frame.sequence != self.lastSequence + 1
                        self.lastSequence = frame.sequence
                        if self.paused { continue }
                        if dropped {
                            self.permit.invalidate(); self.permit = CommitPermit(); self.attempt += 1
                            self.paused = true; self.unresolved = true
                            self.status = "处理队列丢帧，连续性需要重新确认；请回滚补采后继续。"
                            continue
                        }
                        let frameAttempt = self.attempt, framePermit = self.permit
                        do {
                            let targets = try await ScreenSource.windows()
                            guard token == self.generation, !Task.isCancelled else { break }
                            guard frameAttempt == self.attempt, !self.paused else { continue }
                            guard let target = targets.first(where: { $0.windowID == window.windowID }), target.frame == window.frame,
                                  target.owningApplication?.processID == window.owningApplication?.processID,
                                  frame.raster.width == snapshot.width, frame.raster.height == snapshot.height else { throw CaptureError.geometryChanged }
                            if let metadata = self.metadata {
                                guard metadata.0 == frame.contentRect, metadata.1 == frame.scale, metadata.2 == frame.contentScale else { throw CaptureError.geometryChanged }
                            } else { self.metadata = (frame.contentRect,frame.scale,frame.contentScale) }
                            let cropped = try self.cropped(frame.raster,region:frozenRegion)
                            let coverage = try await engine.accept(cropped,permit:framePermit)
                            guard token == self.generation, !Task.isCancelled else { break }
                            guard frameAttempt == self.attempt, !self.paused else { continue }
                            self.confirmedHeight = coverage.height; self.seams = coverage.seams
                            if coverage.appended > 0 { self.acceptedAt = ProcessInfo.processInfo.systemUptime }
                            self.bitmap = cropped
                            self.unresolved = false
                            self.status = coverage.appended > 0 ? "已验证新增 \(coverage.appended) px；继续缓慢滚动。" : "画面已定位，尚无新增覆盖；静止不表示到底。"
                        } catch {
                            guard token == self.generation else { break }
                            guard frameAttempt == self.attempt else { continue }
                            self.paused = true; self.unresolved = true; self.status = error.localizedDescription
                            self.stopAutomatic()
                        }
                    }
                } catch {
                    if token == self.generation { self.paused = true; self.unresolved = true; self.status = "采集已中断，请完成保存局部结果，再重新采集。" }
                }
            }
        } catch {
            if token == generation { status = error.localizedDescription; if let source { await source.stop() }; source = nil; session = nil }
        }
    }
    func togglePause() {
        guard running else { return }
        stopAutomatic()
        permit.invalidate(); permit = CommitPermit(); attempt += 1
        if paused {
            recoveryAttempts += 1
            guard recoveryAttempts <= 32 else { status = "达到 32 次恢复上限，请完成并保存当前结果。"; return }
        }
        paused.toggle()
        status = paused ? "已暂停；继续时仍须与已确认画面重叠。" : "请缓慢回滚到已确认内容；可靠匹配后自动恢复。"
    }
    func finish() async {
        guard running, let session else { return }
        stopAutomatic()
        let token = UUID(); generation = token; running = false; busy = true
        permit.invalidate(); watchdog?.cancel(); watchdog = nil
        captureTask?.cancel(); captureTask = nil; hud.close()
        if let source { await source.stop() }; source = nil
        guard token == generation else { return }
        await session.seal()
        do {
            let size = await session.dimensions()
            guard size.height > 0 else { throw CaptureError.invalidImage }
            let preview = try await session.read(y:0,height:min(size.height,max(1,8_000_000/size.width)))
            guard token == generation else { return }
            bitmap = preview; selecting = false
            status = "\(unresolved ? "局部结果 · 未确认尾部" : "连续采集 · 用户结束（未确认文档尾部）") · \(size.width) × \(size.height) px\(preview.height < size.height ? "；预览仅显示首片，保存包含全部分片" : "")"
        } catch { if token == generation { status = error.localizedDescription; bitmap = nil } }
        if token == generation { busy = false }
        showMain()
    }
    func cancel() {
        exportTask?.cancel()
        stopAutomatic()
        generation = UUID(); captureTask?.cancel(); captureTask = nil
        permit.invalidate(); watchdog?.cancel(); watchdog = nil
        let oldSource = source, oldSession = session
        source = nil; session = nil; running = false; busy = false; paused = false; hud.close()
        bitmap = nil; snapshot = nil; snapshotWindow = nil; selecting = false
        status = "已取消，临时捕获已释放。"
        Task { await oldSource?.stop(); await oldSession?.cancel() }
        showMain()
    }
    func stopAutomatic() { scrollDriver.stop(); automatic = false }
    func trimResult() async {
        guard !busy, !running, !selecting, let bitmap else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let width: Int, height: Int
            if let session { let size = await session.dimensions(); width = size.width; height = size.height }
            else { width = bitmap.width; height = bitmap.height }
            guard trimTop >= 0, trimBottom >= 0, trimTop < height, trimBottom < height-trimTop else { throw CaptureError.invalidImage }
            let base = session == nil ? 0..<height : (exportRange ?? 0..<height)
            guard trimTop < base.count, trimBottom < base.count-trimTop else { throw CaptureError.invalidImage }
            let range = (base.lowerBound+trimTop)..<(base.upperBound-trimBottom)
            let preview: Raster
            if let session { preview = try await session.read(y:range.lowerBound,height:min(range.count,8_000_000/width)) }
            else { preview = try bitmap.crop(y:range.lowerBound,height:range.count) }
            guard token == generation else { return }
            self.bitmap = preview; exportRange = session == nil ? nil : range
            trimTop = 0; trimBottom = 0
            status = "已裁剪到 \(width)×\(range.count) px；\(unresolved ? "局部结果 / 未确认尾部" : "用户选择范围 / 未确认文档尾部")"
        } catch { if token == generation { status = error.localizedDescription } }
    }
    func startAutomatic() {
        guard running, !paused, !automatic, seams >= 3, let activeWindow, let activeRegion else {
            status = "先在当前正文手动验证至少 3 个接缝，再启用有界自动。"; return
        }
        guard ScrollDriver.permission() else {
            ScrollDriver.requestPermission()
            status = "自动控制需要允许 ScrollCapture 的辅助功能权限；手动采集不受影响。"; return
        }
        let token = generation
        automatic = true; status = "3 秒后开始自动；把鼠标放进正文，保持目标窗口前台。任意滚轮/点击/按键可接管。"
        scrollDriver.start(window:activeWindow,region:activeRegion,scale:activeScale,progress:{ [weak self] in
            guard let self else { return (0,0,false) }
            return (self.confirmedHeight,self.acceptedAt,self.running && !self.paused && self.automatic && token == self.generation)
        },stopped:{ [weak self] reason in
            guard let self, token == self.generation else { return }
            self.automatic = false; self.status = reason
        })
    }
    func beginSave() {
        guard !busy, !running, !exporting else { return }
        exporting = true
        exportTask = Task { [weak self] in
            guard let self else { return }
            await self.save()
            self.exporting = false; self.exportTask = nil
        }
    }
    func cancelExport() { exportTask?.cancel() }
    private func save() async {
        guard !busy, !running, let bitmap else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image: Raster
            if let session {
                let size = await session.dimensions()
                let range = exportRange ?? 0..<size.height
                if size.width*range.count > 8_000_000 {
                    try Task.checkCancellation()
                    guard token == generation else { return }
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                    panel.message = "选择存放目录；将创建新文件夹，按顺序保存全部 PNG 分片和范围说明。"
                    guard panel.runModal() == .OK, let parent = panel.url, token == generation else { return }
                    let name = "ScrollCapture-\(UUID().uuidString.prefix(8))\(unresolved ? "-partial" : "")"
                    let url = try await session.exportParts(parent:parent,name:name,partial:unresolved,range:range)
                    guard token == generation else { return }
                    status = "全部分片已保存；manifest.json 标明顺序、像素范围与完整性。"
                    NSWorkspace.shared.activateFileViewerSelecting([url]); return
                }
                image = try await session.read(y:range.lowerBound,height:range.count)
            } else { image = bitmap }
            guard token == generation else { return }
            try Task.checkCancellation()
            let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = unresolved ? "ScrollCapture-partial.png" : "ScrollCapture.png"
            guard panel.runModal() == .OK, let url = panel.url, token == generation else { return }
            try Task.checkCancellation()
            try image.png().write(to:url,options:.atomic)
            status = "已保存 PNG\(unresolved ? "（局部结果）" : "")"; NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch is CancellationError { if token == generation { status = "导出已取消，结果保留，可重试。" } }
        catch { if token == generation { status = "保存失败，结果保留，可重试：\(error.localizedDescription)" } }
    }
    func copy() async {
        guard !busy, !running, let bitmap else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image: Raster
            if let session {
                let size = await session.dimensions()
                let range = exportRange ?? 0..<size.height
                guard size.width*range.count <= 8_000_000 else { status = "整图超过剪贴板预算，请保存有序分片；未复制。"; return }
                image = try await session.read(y:range.lowerBound,height:range.count)
            } else { image = bitmap }
            let png = try image.png()
            guard token == generation else { return }
            NSPasteboard.general.clearContents()
            status = NSPasteboard.general.setData(png,forType:.png) ? "已复制完整结果\(unresolved ? "（局部范围）" : "")" : "复制失败，仍可保存"
        } catch { if token == generation { status = error.localizedDescription } }
    }
}
