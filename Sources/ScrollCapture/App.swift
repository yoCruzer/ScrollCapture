import AppKit
import SwiftUI

@main
struct ScrollCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("ScrollCapture", id: "main") {
            MainView(model: model).frame(minWidth: 900, minHeight: 640)
                .onAppear { delegate.model = model; model.configureShortcut() }
                .onChange(of: model.shortcut) { model.configureShortcut() }
        }
        .defaultSize(width: 1060, height: 760)
        MenuBarExtra("ScrollCapture", systemImage: "rectangle.dashed.badge.record") {
            Button("显示 ScrollCapture") { model.showMain() }
            Button("暂停 / 继续") { model.togglePause() }.disabled(!model.running || model.streamEnded)
            Button("完成") { Task { await model.finish() } }.disabled(!model.running)
            Button("显示采集控制") { model.showMain() }.disabled(!model.running)
            Button("自动滚动（实验功能）") { model.startAutomatic() }.disabled(!model.running || model.seams < 3 || model.paused || model.automatic)
            Divider()
            Button("退出") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
