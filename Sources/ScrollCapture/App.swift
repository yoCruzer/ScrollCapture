import AppKit
import SwiftUI
import ScreenCaptureKit
import CaptureCore

@MainActor
final class AppModel: ObservableObject {
    @Published var windows: [SCWindow] = []
    @Published var selected: UInt32 = 0
    @Published var status = "选择一个非敏感窗口开始；所有图像仅在本机处理。"
    @Published var bitmap: Raster?
    @Published var busy = false
    func refresh() async {
        busy = true; defer { busy = false }
        do { windows = try await ScreenSource.windows(); status = "选择窗口，获取画面。窗口标题仅用于本机选择。" }
        catch { status = "需要屏幕录制权限。请在系统设置中允许 ScrollCapture，然后退出并重新打开。" }
    }
    func capture() async {
        guard let window = windows.first(where: { $0.windowID == selected }) else { return }
        busy = true; defer { busy = false }
        do { bitmap = try await ScreenSource.screenshot(window); status = "截图完成 · \(bitmap!.width) × \(bitmap!.height) 像素" }
        catch { status = error.localizedDescription }
    }
    func save() {
        guard let bitmap else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "ScrollCapture.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try bitmap.png().write(to: url, options: .atomic); status = "已保存 PNG"; NSWorkspace.shared.activateFileViewerSelecting([url]) }
        catch { status = "保存失败，可重试：\(error.localizedDescription)" }
    }
    func copy() {
        guard let bitmap else { return }
        do {
            let png = try bitmap.png(); let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            status = pasteboard.setData(png, forType: .png) ? "已复制完整截图" : "复制失败，结果仍可保存"
        } catch { status = error.localizedDescription }
    }
}

@main
struct ScrollCaptureApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("ScrollCapture") { MainView(model: model).frame(minWidth: 760, minHeight: 560) }
        MenuBarExtra("ScrollCapture", systemImage: "rectangle.dashed.badge.record") {
            Button("显示 ScrollCapture") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil) }
            Button("退出", action: { NSApp.terminate(nil) }).keyboardShortcut("q")
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ScrollCapture").font(.largeTitle.bold())
            Text("原生截图 · 本地处理").foregroundStyle(.secondary)
            HStack {
                Picker("窗口", selection: $model.selected) {
                    Text("请选择").tag(UInt32(0))
                    ForEach(model.windows, id: \.windowID) { w in Text("\(w.owningApplication?.applicationName ?? "App") — \(w.title ?? "窗口")").tag(w.windowID) }
                }
                Button("刷新 / 检查权限") { Task { await model.refresh() } }
            }
            HStack {
                Button("获取窗口画面") { Task { await model.capture() } }.disabled(model.selected == 0 || model.busy)
                Button("合成测试窗口") { FixtureHost.shared.show() }
                Button("保存 PNG", action: model.save).disabled(model.bitmap == nil)
                Button("复制", action: model.copy).disabled(model.bitmap == nil)
                if model.busy { ProgressView().controlSize(.small) }
            }
            Text(model.status).textSelection(.enabled)
            if let raster = model.bitmap, let image = try? raster.image() {
                Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { ContentUnavailableView("先选择窗口", systemImage: "macwindow", description: Text("首次采集需要为 ScrollCapture 授予屏幕录制权限。")) }
        }.padding(24)
    }
}
