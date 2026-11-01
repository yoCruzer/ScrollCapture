import AppKit
import SwiftUI

@MainActor
final class CaptureHUD {
    private var panel: NSPanel?
    func show(model: AppModel) {
        close()
        let panel = NSPanel(contentRect: NSRect(x: 30, y: 80, width: 380, height: 126),
                            styleMask: [.nonactivatingPanel, .titled], backing: .buffered, defer: false)
        panel.title = "ScrollCapture · 滚动捕获"
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        panel.orderFrontRegardless(); self.panel = panel
    }
    func close() { panel?.orderOut(nil); panel = nil }
}

struct HUDView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已确认 \(model.confirmedHeight) px · \(model.seams) 个接缝").bold()
            Text(model.status).font(.caption).lineLimit(2)
            HStack {
                Button(model.paused ? "回滚后继续" : "暂停") { model.togglePause() }.disabled(model.gateRunning)
                Button("完成") { Task { await model.finish() } }.disabled(model.gateRunning)
                Button("取消") { model.cancel() }
                Button(model.automatic ? "回手动" : "有界自动") {
                    if model.automatic { model.stopAutomatic() } else { model.startAutomatic() }
                }.disabled(model.paused || model.seams < 3)
            }
        }.padding(12).frame(width: 356)
    }
}
