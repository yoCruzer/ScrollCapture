import AppKit
import SwiftUI

@MainActor
final class CaptureHUD {
    private var panel: NSPanel?
    func show(model: AppModel) {
        close()
        let panel = NSPanel(contentRect: NSRect(x: 30, y: 80, width: 420, height: 230),
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
    @State private var confirmDiscard = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(model.paused ? "已暂停" : model.unresolved ? "等待重新匹配" : model.automatic ? "自动 · 实验功能" : "手动滚动", systemImage: model.paused ? "pause.circle.fill" : "record.circle")
                    .foregroundStyle(model.paused ? Color.orange : Color.accentColor)
                Spacer()
                Text("\(model.confirmedHeight) px · \(model.seams) 次拼接").monospacedDigit()
            }.font(.callout.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.paused ? (model.unresolved ? "向上滚回已截取的内容，再点继续；也可完成并保存局部结果。" : "已暂停。准备好后点继续，再缓慢向下滚动。") : (model.unresolved ? "已保留上次确认的位置。" : "在目标窗口正文内向下滚动。"))
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text(model.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let notice = model.automaticNotice {
                        Text(notice).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(model.paused ? "继续采集" : "暂停") { model.togglePause() }.disabled(model.gateRunning || model.streamEnded)
                Button("完成并预览") { Task { await model.finish() } }.buttonStyle(.borderedProminent).disabled(model.gateRunning)
                Spacer()
                Menu {
                    Button(model.automatic ? "切回手动" : "尝试自动滚动（实验功能）") {
                        if model.automatic { model.stopAutomatic(); model.automaticNotice = "已切回手动，可继续缓慢滚动。" }
                        else { model.startAutomatic() }
                    }.disabled(model.paused || model.seams < 3 || model.gateRunning)
                    Button("显示主窗口") { model.showMain() }
                    Divider()
                    Button("放弃本次截图…", role: .destructive) { confirmDiscard = true }.disabled(model.gateRunning)
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("更多采集操作")
            }
        }.frame(width: 388, height: 198).padding(16)
            .alert("放弃本次截图？", isPresented: $confirmDiscard) {
                Button("继续保留", role: .cancel) {}
                Button("放弃截图", role: .destructive) { model.cancel() }
            } message: { Text("尚未保存的内容将被清除。要保留结果，请选择“完成并预览”。") }
    }
}
