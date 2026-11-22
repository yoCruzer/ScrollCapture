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
    @Published var automaticNotice: String?
    @Published var permissionNeeded = false
    @Published var shortcut = UserDefaults.standard.integer(forKey:"shortcut")
    @Published var trimTop = 0
    @Published var trimBottom = 0
    @Published private(set) var sealedWidth = 0
    @Published var exporting = false
    @Published var gateRunning = false
    var gateID = UUID()
    private var exportRange: Range<Int>?
    private var exportTask: Task<Void,Never>?
    private(set) var snapshot: Raster?
    private var snapshotWindow: SCWindow?
    private var generation = UUID()
    private var permit = CommitPermit()
    private var attempt = 0
    private(set) var session: CaptureSession?
    private var cleanupTask: Task<Void,Never>?
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
    private var resumeTime = -Double.infinity
    private var lastSequence: UInt64 = 0
    private var metadata: (CGRect, Double, Double)?
    private var watchdog: Task<Void,Never>?
    @Published private(set) var streamEnded = false
    private var recoveryAttempts = 0

    var canStartScrolling: Bool { (region?.width ?? 0) >= 32 && (region?.height ?? 0) >= 64 }
    var resultHeight: Int { session == nil ? (bitmap?.height ?? 0) : (exportRange?.count ?? confirmedHeight) }
    var hasResult: Bool { !running && !selecting && (bitmap != nil || sealedWidth > 0) }
    var resultRequiresParts: Bool { resultHeight > Raster.outputRows(width: sealedWidth > 0 ? sealedWidth : bitmap?.width ?? 0) }
    var canTrimResult: Bool {
        bitmap != nil && trimTop >= 0 && trimBottom >= 0 && trimTop < resultHeight && trimBottom < resultHeight - trimTop && (trimTop > 0 || trimBottom > 0)
    }
    var resultSummary: String {
        let width = sealedWidth > 0 ? sealedWidth : bitmap?.width ?? 0
        let dimensions = "\(width) × \(resultHeight) px"
        guard session != nil else { return "\(dimensions) · 单张截图" }
        return "\(dimensions) · \(unresolved ? "仅包含已确认的部分内容" : "本次采集的连续范围")。结束采集不代表到达文档底部。"
    }
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.title == "ScrollCapture" })?.makeKeyAndOrderFront(nil)
    }
    func selectionChanged() {
        guard !running else { return }
        generation = UUID(); busy = false; snapshot = nil; snapshotWindow = nil; region = nil; selecting = false
        sealedWidth = 0; bitmap = nil; unresolved = false; automaticNotice = nil
    }
    func selectWindow(_ id: UInt32, fromGate: Bool = false) { guard !busy, !running, !gateRunning || fromGate else { return }; selected = id; selectionChanged() }
    func configureShortcut() {
        hotKey.action = { [weak self] in self?.showMain() }
        let codes: [UInt32?] = [UInt32(kVK_ANSI_S),UInt32(kVK_ANSI_D),nil]
        guard codes.indices.contains(shortcut) else { shortcut = 0; return }
        if !hotKey.configure(keyCode:codes[shortcut]) { status = "快捷键注册失败，请选择另一个组合。" }
        UserDefaults.standard.set(shortcut,forKey:"shortcut")
    }
    func refresh() async {
        guard !busy, !running, !gateRunning else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let result = try await ScreenSource.windows()
            guard token == generation else { return }
            windows = result; permissionNeeded = false
            if !result.contains(where: { $0.windowID == selected }) { selected = 0 }
            status = result.isEmpty ? "没有找到可截取的窗口。请打开目标内容，再刷新列表。" : "从左侧选择窗口，再点“预览并选择范围”。"
        } catch {
            if token == generation {
                permissionNeeded = !CGPreflightScreenCaptureAccess()
                status = permissionNeeded ? "请先允许 ScrollCapture 录制屏幕，再退出并重新打开。" : "无法读取窗口列表，请重试：\(error.localizedDescription)"
            }
        }
    }
    func capture(fromGate: Bool = false) async {
        guard !busy, !running, !gateRunning || fromGate, let window = windows.first(where: { $0.windowID == selected }) else { return }
        let token = generation, target = selected; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image = try await ScreenSource.screenshot(window)
            guard token == generation, target == selected else { return }
            bitmap = image; snapshot = image; snapshotWindow = window; region = nil; session = nil; selecting = true
            automaticNotice = nil; permissionNeeded = false; confirmedHeight = 0; seams = 0
            exportRange = nil; trimTop = 0; trimBottom = 0
            unresolved = false; status = "拖选范围，再选择单张截图或滚动截图。"
        } catch {
            if token == generation {
                permissionNeeded = !CGPreflightScreenCaptureAccess()
                status = permissionNeeded ? "屏幕录制权限不可用，请打开权限设置，允许后退出并重新打开。" : error.localizedDescription
            }
        }
    }
    func cropped(_ image: Raster, region: CGRect?) throws -> Raster {
        guard let region else { return image }
        return try image.crop(x: Int(region.minX), y: Int(region.minY), width: Int(region.width), height: Int(region.height))
    }
    func regionScreenshot() {
        guard !busy, !running, !gateRunning, let snapshot else { return }
        do { bitmap = try cropped(snapshot,region:region); session = nil; selecting = false; status = "截图已就绪，检查画面后保存或复制。" }
        catch { status = error.localizedDescription }
    }
    func start(fromGate: Bool = false) async {
        guard !busy, !running, !gateRunning || fromGate, let snapshotWindow, let snapshot, snapshotWindow.windowID == selected else { return }
        guard canStartScrolling, let frozenRegion = region else {
            status = "请框选至少 32 × 64 像素的正文，再开始滚动截图。"
            return
        }
        let token = UUID(); generation = token; busy = true
        permit.invalidate(); permit = CommitPermit(); attempt += 1; recoveryAttempts = 0
        defer { if token == generation { busy = false } }
        do {
            let fresh = try await ScreenSource.windows()
            guard token == generation else { return }
            guard let owner = snapshotWindow.owningApplication?.processID,
                  let window = fresh.first(where: { $0.windowID == snapshotWindow.windowID }),
                  window.owningApplication?.processID == owner, window.frame == snapshotWindow.frame else { throw CaptureError.geometryChanged }
            let engine = try CaptureSession(); let live = try LiveStream(window:window)
            source = live; session = engine; resumeTime = -.infinity; lastTime = -Double.infinity; lastSequence = 0; metadata = nil
            try await live.start()
            guard token == generation else { await live.stop(); return }
            streamEnded = false; running = true; paused = false; unresolved = false; selecting = false; confirmedHeight = 0; seams = 0
            automaticNotice = nil
            exportRange = nil; trimTop = 0; trimBottom = 0
            activeWindow = window; activeRegion = frozenRegion
            activeScale = CGFloat(snapshot.width)/window.frame.width
            status = "将鼠标放在正文中缓慢向下滚动；当前范围由你结束，不推断文档到底。"
            hud.show(model:self)
            watchdog?.cancel()
            watchdog = Task { [weak self] in
                do { try await Task.sleep(for:.seconds(8)) } catch { return }
                guard let self, token == self.generation, self.running else { return }
                if self.confirmedHeight == 0 {
                    self.permit.invalidate(); self.attempt += 1
                    self.paused = true; self.unresolved = true
                    self.status = "8 秒内未收到有效帧，请检查权限/目标可见性，完成后重新开始。"
                }
                do { try await Task.sleep(for:.seconds(592)) } catch { return }
                guard token == self.generation, self.running else { return }
                self.unresolved = true
                await self.finish(limitReached: true)
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
                        if self.paused || frame.time < self.resumeTime { continue }
                        if dropped {
                            self.stopAutomatic()
                            self.permit.invalidate(); self.permit = CommitPermit(); self.attempt += 1
                            self.paused = true; self.unresolved = true
                            self.status = "处理队列丢帧，连续性需要重新确认；请回滚补采后继续。"
                            continue
                        }
                        if CMClockGetTime(CMClockGetHostTimeClock()).seconds - frame.time > 1.5 {
                            self.paused = true; self.unresolved = true; self.stopAutomatic()
                            self.status = "画面已过期，已暂停；请回滚到可信位置再继续。"; continue
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
                            let coverage = try await engine.accept(cropped,permit:framePermit, checkFreshness: {
                                guard CMClockGetTime(CMClockGetHostTimeClock()).seconds - frame.time <= 1.5 else {
                                    throw CaptureError.staleFrame
                                }
                            })
                            guard token == self.generation, !Task.isCancelled else { break }
                            guard frameAttempt == self.attempt, !self.paused else { continue }
                            self.confirmedHeight = coverage.height; self.seams = coverage.seams
                            // SCK presentation timestamps use the host monotonic clock; a pre-input
                            // frame processed late must not authorize the next automatic input.
                            if coverage.appended > 0 { self.acceptedAt = frame.time }
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
                    if token == self.generation {
                        self.stopAutomatic()
                        self.streamEnded = true; self.paused = true; self.unresolved = true
                        self.status = "采集已中断。请点“完成并预览”保留已确认的内容，再重新采集。"
                    }
                }
            }
        } catch {
            guard token == generation else { return }
            status = error.localizedDescription
            let oldSource = source
            source = nil; session = nil
            await oldSource?.stop()
        }
    }
    func togglePause() {
        guard running, !gateRunning, !streamEnded else { return }
        stopAutomatic()
        permit.invalidate(); permit = CommitPermit(); attempt += 1
        if paused {
            resumeTime = CMClockGetTime(CMClockGetHostTimeClock()).seconds
            recoveryAttempts += 1
            guard recoveryAttempts <= 32 else { status = "达到 32 次恢复上限，请完成并保存当前结果。"; return }
        }
        paused.toggle()
        status = paused ? "已暂停；继续时仍须与已确认画面重叠。" : "请缓慢回滚到已确认内容；可靠匹配后自动恢复。"
    }
    func finish(fromGate: Bool = false, limitReached: Bool = false) async {
        guard running, !gateRunning || fromGate, let session else { return }
        stopAutomatic()
        let token = UUID(); generation = token; running = false; busy = true
        permit.invalidate(); watchdog?.cancel(); watchdog = nil
        captureTask?.cancel(); captureTask = nil; hud.close()
        let oldSource = source
        await oldSource?.stop()
        guard token == generation else { return }
        source = nil
        await session.seal()
        do {
            let size = await session.dimensions()
            guard token == generation else { return }
            guard size.height > 0 else { throw CaptureError.invalidImage }
            sealedWidth = size.width; confirmedHeight = size.height
            let preview = try await session.read(y:0,height:Raster.previewRows(width: size.width, height: size.height))
            guard token == generation else { return }
            bitmap = preview; selecting = false; confirmedHeight = size.height
            status = "\(unresolved ? "局部结果 · 未确认尾部" : "连续采集 · 用户结束（未确认文档尾部）") · \(size.width) × \(size.height) px\(preview.height < size.height ? "；预览仅显示首片，保存包含全部分片" : "")"
            if limitReached { status = "达到 10 分钟上限。" + status }
        } catch { if token == generation { status = sealedWidth > 0 ? "预览读取失败，已确认的内容仍可尝试保存：" + error.localizedDescription : error.localizedDescription; bitmap = nil } }
        guard token == generation else { return }
        busy = false
        showMain()
    }
    func cancel() {
        gateID = UUID(); gateRunning = false
        exportTask?.cancel()
        stopAutomatic()
        generation = UUID(); captureTask?.cancel(); captureTask = nil
        permit.invalidate(); watchdog?.cancel(); watchdog = nil
        let oldSource = source, oldSession = session
        source = nil; session = nil; running = false; busy = false; paused = false; hud.close()
        bitmap = nil; snapshot = nil; snapshotWindow = nil; selecting = false
        sealedWidth = 0; region = nil; unresolved = false; confirmedHeight = 0; seams = 0; exportRange = nil
        trimTop = 0; trimBottom = 0; automaticNotice = nil
        let cleanupStatus = "正在清理上一次截图；可以选择窗口开始下一张。"
        status = cleanupStatus
        let token = generation, priorCleanup = cleanupTask
        cleanupTask = Task {
            await oldSession?.cancel(); await oldSource?.stop(); await priorCleanup?.value
            if token == generation, status == cleanupStatus { status = "选择窗口，开始下一张截图。" }
        }
        showMain()
    }
    func shutdown() async {
        cancel()
        await exportTask?.value
        await cleanupTask?.value
    }
    func stopAutomatic() {
        scrollDriver.stop()
        if automatic { automaticNotice = "自动滚动已停止。" }
        automatic = false
    }
    func trimResult() async {
        guard !busy, hasResult, !gateRunning, let bitmap else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let width: Int, height: Int
            if let session { let size = await session.dimensions(); width = size.width; height = size.height }
            else { width = bitmap.width; height = bitmap.height }
            guard trimTop >= 0, trimBottom >= 0, trimTop < height, trimBottom < height-trimTop else {
                status = "裁剪数值需为非负数，且至少保留 1 行画面。"; return
            }
            let base = session == nil ? 0..<height : (exportRange ?? 0..<height)
            guard trimTop < base.count, trimBottom < base.count-trimTop else {
                status = "裁剪总量超过当前图片高度，请减少顶部或底部的数值。"; return
            }
            let range = (base.lowerBound+trimTop)..<(base.upperBound-trimBottom)
            let preview: Raster
            if let session { preview = try await session.read(y:range.lowerBound,height:Raster.previewRows(width: width, height: range.count)) }
            else { preview = try bitmap.crop(y:range.lowerBound,height:range.count) }
            guard token == generation else { return }
            self.bitmap = preview; exportRange = session == nil ? nil : range
            trimTop = 0; trimBottom = 0
            status = "已裁剪到 \(width)×\(range.count) px；\(unresolved ? "局部结果 / 未确认尾部" : "用户选择范围 / 未确认文档尾部")"
        } catch { if token == generation { status = error.localizedDescription } }
    }
    func startAutomatic() {
        guard running, !paused, !unresolved, !automatic, !gateRunning, seams >= 3, let activeWindow, let activeRegion else {
            automaticNotice = "先在当前正文手动完成至少 3 次拼接，再尝试自动滚动。"; return
        }
        guard ScrollDriver.permission() else {
            ScrollDriver.requestPermission()
            automaticNotice = "自动滚动需要辅助功能权限，请在系统设置中允许 ScrollCapture；也可继续手动滚动。"; return
        }
        let token = generation
        automatic = true; status = "3 秒后开始自动；把鼠标放进正文，保持目标窗口前台。任意滚轮/点击/按键可接管。"
        automaticNotice = "正在尝试自动滚动：保持目标窗口在前台、鼠标位于正文。点击、按键或滚轮会切回手动。"
        scrollDriver.start(window:activeWindow,region:activeRegion,scale:activeScale,progress:{ [weak self] in
            guard let self else { return (0,0,false) }
            return (self.confirmedHeight,self.acceptedAt,self.running && !self.paused && self.automatic && token == self.generation)
        },stopped:{ [weak self] reason in
            guard let self, token == self.generation else { return }
            self.automatic = false; self.automaticNotice = reason; self.status = reason
        })
    }
    func beginSave() {
        guard !busy, !running, !selecting, !exporting, !gateRunning, hasResult else { return }
        exporting = true
        exportTask = Task { [weak self] in
            guard let self else { return }
            await self.save()
            self.exporting = false; self.exportTask = nil
        }
    }
    func cancelExport() { exportTask?.cancel() }
    private func save() async {
        guard !busy, hasResult else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image: Raster
            if let session {
                let size = await session.dimensions()
                let range = exportRange ?? 0..<size.height
                if range.count > Raster.outputRows(width: size.width) {
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
            } else if let bitmap { image = bitmap } else { throw CaptureError.invalidImage }
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
        guard !busy, hasResult, !gateRunning else { return }
        let token = generation; busy = true
        defer { if token == generation { busy = false } }
        do {
            let image: Raster
            if let session {
                let size = await session.dimensions()
                let range = exportRange ?? 0..<size.height
                guard range.count <= Raster.outputRows(width: size.width) else { status = "整图超过剪贴板预算，请保存有序分片；未复制。"; return }
                image = try await session.read(y:range.lowerBound,height:range.count)
            } else if let bitmap { image = bitmap } else { throw CaptureError.invalidImage }
            let png = try image.png()
            guard token == generation else { return }
            NSPasteboard.general.clearContents()
            status = NSPasteboard.general.setData(png,forType:.png) ? "已复制完整结果\(unresolved ? "（局部范围）" : "")" : "复制失败，仍可保存"
        } catch { if token == generation { status = error.localizedDescription } }
    }
}
