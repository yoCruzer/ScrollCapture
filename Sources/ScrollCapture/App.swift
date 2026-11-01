import AppKit
import SwiftUI

@main
struct ScrollCaptureApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("ScrollCapture", id: "main") {
            MainView(model: model).frame(minWidth: 860, minHeight: 650)
                .onAppear { model.configureShortcut() }
                .onChange(of: model.shortcut) { model.configureShortcut() }
        }
        MenuBarExtra("ScrollCapture", systemImage: "rectangle.dashed.badge.record") {
            Button("显示 ScrollCapture") { model.showMain() }
            Button("暂停 / 继续") { model.togglePause() }.disabled(!model.running)
            Button("完成") { Task { await model.finish() } }.disabled(!model.running)
            Button("取消") { model.cancel() }.disabled(!model.running)
            Button("有界自动（先手动验证3个接缝）") { model.startAutomatic() }.disabled(!model.running || model.seams < 3)
            Divider()
            Button("退出") { model.cancel(); NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var actualSize = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("ScrollCapture").font(.largeTitle.bold())
                    Text("选窗口 → 框选正文 → 手动滚动 → 检查并保存").foregroundStyle(.secondary)
                }
                Spacer()
                Button("合成测试窗口") { FixtureHost.shared.show() }.disabled(model.running)
                Button("受控原生验收") { Task { await model.nativeGate() } }.disabled(model.running || model.busy)
            }
            HStack {
                Picker("窗口", selection: Binding(get:{model.selected},set:{model.selectWindow($0)})) {
                    Text("请选择").tag(UInt32(0))
                    ForEach(model.windows, id: \.windowID) { w in Text("\(w.owningApplication?.applicationName ?? "App") — \(w.title ?? "窗口")").tag(w.windowID) }
                }.disabled(model.busy || model.running)
                Button("刷新 / 检查权限") { Task { await model.refresh() } }.disabled(model.busy || model.running)
            }
            HStack {
                Button("获取窗口画面") { Task { await model.capture() } }.disabled(model.selected == 0 || model.busy || model.running)
                Button("区域截图") { model.regionScreenshot() }.disabled(model.snapshot == nil || model.busy || model.running)
                Button("开始手动滚动") { Task { await model.start() } }.disabled(model.snapshot == nil || model.busy || model.running)
                if model.running {
                    Button(model.paused ? "回滚后继续" : "暂停") { model.togglePause() }
                    Button("完成") { Task { await model.finish() } }
                    Button("取消") { model.cancel() }
                }
                if model.busy { ProgressView().controlSize(.small) }
            }
            Text(model.status).textSelection(.enabled).font(.callout)
                .foregroundStyle(model.unresolved ? .orange : .primary)
            if model.running { Text("已确认 \(model.confirmedHeight) px · \(model.seams) 个接缝 · 只扩展已验证的连续覆盖").font(.headline) }
            HStack {
                Button("保存 PNG / 分片") { model.beginSave() }.disabled(model.bitmap == nil || model.busy || model.running)
                if model.exporting { Button("取消导出") { model.cancelExport() } }
                Button("复制完整图") { Task { await model.copy() } }.disabled(model.bitmap == nil || model.busy || model.running)
                Toggle("100%", isOn: $actualSize).toggleStyle(.button)
                if let r = model.region { Text("选区 \(Int(r.minX)),\(Int(r.minY)) · \(Int(r.width))×\(Int(r.height)) px").font(.caption.monospaced()) }
                Button("选整个窗口") { model.region = nil }.disabled(model.running || model.busy)
            }
            HStack {
                Picker("唤起快捷键",selection:$model.shortcut) {
                    Text("⌃⌥⌘S").tag(0); Text("⌃⌥⌘D").tag(1); Text("关闭").tag(2)
                }.frame(width:200)
                Text("重复整屏 / 超长周期 / 亚像素重采样无法保证定位；请缓慢滚动并复核首尾。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.bitmap != nil && !model.selecting && !model.running {
                HStack {
                    Text("裁剪顶部 / 底部（像素）")
                    TextField("顶部",value:$model.trimTop,format:.number).frame(width:70)
                    TextField("底部",value:$model.trimBottom,format:.number).frame(width:70)
                    Button("应用裁剪") { Task { await model.trimResult() } }.disabled(model.busy)
                }
            }
            if let bitmap = model.bitmap {
                if model.selecting && !actualSize {
                    RegionPreview(raster: bitmap, region: $model.region)
                    Text("在画面上拖选正文，排除标题栏、固定栏、滚动条与动态区域。边界按实际像素吸附；全窗口也可普通截图。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        if let image = try? bitmap.image() {
                            if actualSize { Image(decorative: image, scale: 1).interpolation(.none) }
                            else { Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit().frame(maxWidth: 780, maxHeight: 420) }
                        }
                    }
                }
            } else { ContentUnavailableView("选择一个非敏感窗口", systemImage: "macwindow", description: Text("图像只在本机处理。首次采集需要为 ScrollCapture 授予屏幕录制权限。")) }
            Spacer(minLength: 0)
        }.padding(24)
    }
}
