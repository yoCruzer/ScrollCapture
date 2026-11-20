import AppKit
import ApplicationServices
import ScreenCaptureKit
import CaptureCore

@MainActor
final class ScrollDriver {
    static let eventTag: Int64 = 0x5343524F4C4C
    private var task: Task<Void,Never>?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var id = UUID()
    func stop() {
        id = UUID(); task?.cancel(); task = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }; globalMonitor = nil
    }
    static func permission() -> Bool { CGPreflightPostEventAccess() }
    static func requestPermission() { _ = CGRequestPostEventAccess() }

    func start(window: SCWindow, region: CGRect, scale: CGFloat,
               progress: @escaping @MainActor () -> (height:Int,time:Double,valid:Bool),
               stopped: @escaping @MainActor (String) -> Void) {
        stop(); let token = id
        let mask: NSEvent.EventTypeMask = [.scrollWheel,.leftMouseDown,.rightMouseDown,.keyDown]
        let userInput: @MainActor (NSEvent) -> Void = { [weak self] event in
            guard event.cgEvent?.getIntegerValueField(.eventSourceUserData) != Self.eventTag else { return }
            self?.stop(); stopped("检测到用户接管，已切回手动。")
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching:mask) { event in
            MainActor.assumeIsolated { userInput(event) }; return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching:mask) { event in
            MainActor.assumeIsolated { userInput(event) }
        }
        task = Task { [weak self] in
            // User positions the pointer; the app never moves it.
            do { try await Task.sleep(for:.seconds(3)) } catch { return }
            guard let self, token == self.id else { return }
            var policy = AutoPolicy(now:CMClockGetTime(CMClockGetHostTimeClock()).seconds)
            while !Task.isCancelled, token == self.id {
                let state = progress()
                guard state.valid, Self.permission() else { self.stop(); stopped("自动控制已停止，请检查采集状态和辅助功能权限。"); return }
                do {
                    let targets = try await ScreenSource.windows()
                    guard token == self.id, !Task.isCancelled else { return }
                    let safe = Self.safeTarget(window:window,targets:targets,region:region,scale:scale)
                    switch policy.evaluate(now:CMClockGetTime(CMClockGetHostTimeClock()).seconds,height:state.height,acceptedAt:state.time,safeTarget:safe) {
                    case .wait: break
                    case .stop(let reason): self.stop(); stopped("\(reason)；已切回手动。"); return
                    case .send:
                        guard progress().valid, token == self.id, Self.safeTarget(window:window,targets:targets,region:region,scale:scale),
                              let pid = window.owningApplication?.processID,
                              let event = CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:1,
                                                  wheel1:-Int32(min(120,max(16,Int(region.height/scale/5)))),wheel2:0,wheel3:0),
                              let cursor = CGEvent(source:nil)?.location else { self.stop(); stopped("输入目标无法验证，已切回手动。"); return }
                        event.location = cursor
                        event.setIntegerValueField(.eventSourceUserData,value:Self.eventTag)
                        event.postToPid(pid)
                    }
                } catch { self.stop(); stopped("目标不可用，已切回手动。"); return }
                do { try await Task.sleep(for:.milliseconds(100)) } catch { return }
            }
        }
    }
    static func safeTarget(window: SCWindow, targets: [SCWindow], region: CGRect, scale: CGFloat) -> Bool {
        guard scale > 0, let pid = window.owningApplication?.processID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let fresh = targets.first(where: { $0.windowID == window.windowID }), fresh.frame == window.frame,
              fresh.owningApplication?.processID == pid,
              let cursor = CGEvent(source:nil)?.location else { return false }
        let rect = CGRect(x:window.frame.minX+region.minX/scale,y:window.frame.minY+region.minY/scale,width:region.width/scale,height:region.height/scale)
        guard rect.insetBy(dx:2,dy:2).contains(cursor),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return false }
        // Window IDs, not titles: reject another window of the same process under the pointer.
        for info in list {
            // Floating panels/menus above the target can intercept input too; do not skip layers.
            guard (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation:bounds), frame.contains(cursor) else { continue }
            return (info[kCGWindowNumber as String] as? UInt32) == window.windowID
        }
        return false
    }
}
