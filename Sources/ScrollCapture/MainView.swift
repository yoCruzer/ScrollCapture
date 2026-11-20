import AppKit
import SwiftUI

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var actualSize = false
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var confirmDiscard = false
    @State private var showCrop = false

    private var hasResult: Bool { model.bitmap != nil && !model.selecting && !model.running }
    private var step: Int { hasResult ? 3 : (model.bitmap != nil || model.running ? 2 : 1) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 248)
                Divider()
                workspace
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("放弃当前截图？", isPresented: $confirmDiscard) {
            Button("保留截图", role: .cancel) {}
            Button("放弃并新建", role: .destructive) { reset() }
        } message: {
            Text("尚未保存的内容将被清除。你可以先保存或复制，再开始下一张。")
        }
        .onChange(of: model.selecting) { if model.selecting { actualSize = false; showCrop = false } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "viewfinder").font(.system(size: 23, weight: .medium)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("ScrollCapture").font(.title3.weight(.semibold))
                Text("把长内容，留在一张图里").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { if model.bitmap != nil || model.running { confirmDiscard = true } else { reset() } } label: {
                Label("新建截图", systemImage: "plus")
            }.disabled(model.busy || model.gateRunning)
            Button { showHelp.toggle() } label: { Image(systemName: "questionmark.circle") }
                .accessibilityLabel("使用帮助").help("使用帮助")
                .popover(isPresented: $showHelp) { helpContent }
            Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                .accessibilityLabel("设置与工具").help("设置与工具")
                .popover(isPresented: $showSettings) { settingsContent }
        }.padding(.horizontal, 22).padding(.vertical, 16)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    stepRow(1, "选择窗口", "找到要保存的内容")
                    stepRow(2, "选择范围", "单张截图或滚动长图")
                    stepRow(3, "检查与保存", "检查首尾，再导出图片")
                }
                Divider()
                if step == 1 { targetControls }
                else if model.running { captureControls }
                else if model.selecting { selectionControls }
                else { resultControls }
                Spacer(minLength: 12)
                Label("图像仅在本机处理", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }
        .background(.background.opacity(0.35))
    }

    private func stepRow(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(number == step ? Color.accentColor : Color.secondary.opacity(0.12))
                if number < step { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.secondary) }
                else { Text("\(number)").font(.caption.bold()).foregroundStyle(number == step ? .white : .secondary) }
            }.frame(width: 27, height: 27)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(number == step ? .semibold : .regular))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
            .accessibilityLabel("第 \(number) 步，\(title)\(number == step ? "，当前步骤" : "")")
    }

    private var targetControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("截取哪个窗口？").font(.headline)
            if !model.windows.isEmpty {
                Picker("目标窗口", selection: Binding(get: { model.selected }, set: { model.selectWindow($0) })) {
                    Text("请选择窗口").tag(UInt32(0))
                    ForEach(model.windows, id: \.windowID) { window in
                        Text("\(window.owningApplication?.applicationName ?? "App") · \(window.title ?? "未命名窗口")").tag(window.windowID)
                    }
                }.labelsHidden().disabled(model.busy)
                    .accessibilityLabel("目标窗口")
                Button { Task { await model.capture() } } label: {
                    Label("预览并选择范围", systemImage: "arrow.right").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.selected == 0 || model.busy)
            }
            Button(model.windows.isEmpty ? "选择窗口…" : "刷新窗口列表") { Task { await model.refresh() } }
                .disabled(model.busy)
            Text("先打开目标内容，保持窗口可见。下一步可拖选要截取的范围。")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.permissionNeeded {
                Divider()
                Label("需要屏幕录制权限", systemImage: "lock.circle").font(.headline)
                Text("在系统设置中允许 ScrollCapture，然后退出并重新打开本应用。")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("打开权限设置") { model.openScreenRecordingSettings() }
                Text("普通截图与手动滚动不需要辅助功能权限。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectionControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("在预览中拖选范围").font(.headline)
            Text("滚动长图请只框选正文，避开顶部导航、固定工具栏和滚动条。")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Label(model.region == nil ? "当前：整个窗口" : "已选择正文区域", systemImage: "crop")
                .font(.callout)
            Button { Task { await model.start() } } label: {
                Label("开始滚动截图", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.busy || model.region == nil)
            if model.region == nil {
                Text("先拖选正文，即可开始滚动截图。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button(model.region == nil ? "截取整个窗口" : "截取所选区域") { model.regionScreenshot() }
                .disabled(model.busy)
            Divider()
            Button("重新选择窗口") { reset() }.disabled(model.busy)
            Button("清除选区") { model.region = nil }.disabled(model.region == nil || model.busy)
        }
    }

    private var captureControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.paused ? "采集已暂停" : "正在采集", systemImage: model.paused ? "pause.circle" : "record.circle")
                .font(.headline).foregroundStyle(model.paused ? Color.orange : Color.accentColor)
            Text("\(model.confirmedHeight) px").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
            Text("已确认的连续长度 · \(model.seams) 次拼接").font(.caption).foregroundStyle(.secondary)
            Text(model.paused ? (model.unresolved ? "向上滚回刚才截到的内容，再点继续。也可以直接完成，保存已确认部分。" : "回到目标窗口，点继续后缓慢向下滚动。") : "切回目标窗口，鼠标放在正文内，缓慢向下滚动。")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Button { Task { await model.finish() } } label: {
                Label("完成并预览", systemImage: "checkmark").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.gateRunning)
            Button(model.paused ? "继续采集" : "暂停采集") { model.togglePause() }.disabled(model.gateRunning)
            Divider()
            Text("自动滚动 · 实验功能").font(.callout.weight(.semibold))
            Text("尚未通过实际自动采集验收。建议使用手动滚动；尝试自动前需手动完成 3 次拼接。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(model.automatic ? "切回手动" : "尝试自动滚动") {
                if model.automatic { model.stopAutomatic(); model.automaticNotice = "已切回手动，可继续缓慢滚动。" }
                else { model.startAutomatic() }
            }.disabled(model.paused || model.seams < 3 || model.gateRunning)
            Button("放弃本次截图…", role: .destructive) { confirmDiscard = true }.disabled(model.gateRunning)
        }
    }

    private var resultControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.unresolved ? "已保留局部结果" : "截图已就绪", systemImage: model.unresolved ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.headline)
            Text(model.resultSummary).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { model.beginSave() } label: {
                Label(model.resultRequiresParts ? "保存全部分片…" : "保存 PNG…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
            Button("复制完整结果") { Task { await model.copy() } }.disabled(model.busy || model.resultRequiresParts)
            if model.resultRequiresParts {
                Text("图片较长，将按顺序保存为多张无损 PNG；预览仅显示第一片。整图过大，无法复制。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if model.exporting { Button("取消导出") { model.cancelExport() } }
            Divider()
            DisclosureGroup("裁掉顶部 / 底部", isExpanded: $showCrop) {
                VStack(alignment: .leading, spacing: 10) {
                    cropField("顶部", value: $model.trimTop)
                    cropField("底部", value: $model.trimBottom)
                    Text("输入要去掉的像素数，至少保留 1 行。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("应用裁剪") { Task { await model.trimResult() } }
                        .disabled(model.busy || !model.canTrimResult)
                }.padding(.top, 10)
            }.font(.callout)
        }
    }

    private func cropField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            TextField(title, value: value, format: .number).textFieldStyle(.roundedBorder)
                .accessibilityLabel("裁掉\(title)像素数").disabled(model.busy)
            Text("px").foregroundStyle(.secondary)
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.running ? "当前可见画面" : model.selecting ? "拖选正文范围" : hasResult ? "结果预览" : "从一个窗口开始")
                    .font(.headline)
                Spacer()
                if hasResult {
                    Picker("预览缩放", selection: $actualSize) {
                        Text("适合窗口").tag(false)
                        Text("100%").tag(true)
                    }.pickerStyle(.segmented).frame(width: 160)
                }
                if model.busy { ProgressView().controlSize(.small).accessibilityLabel("正在处理") }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .textBackgroundColor))
                if let bitmap = model.bitmap {
                    if model.selecting {
                        RegionPreview(raster: bitmap, region: $model.region).padding(16).disabled(model.busy || model.gateRunning)
                    } else if let image = try? bitmap.image() {
                        if actualSize && hasResult {
                            ScrollView([.horizontal, .vertical]) { Image(decorative: image, scale: 1).interpolation(.none) }.padding(16)
                        } else {
                            GeometryReader { proxy in
                                Image(decorative: image, scale: 1).resizable().scaledToFit()
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }.padding(16)
                        }
                    }
                } else { welcome }
            }.overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.06)))
            if let bitmap = model.bitmap {
                HStack {
                    Image(systemName: model.selecting ? "crop" : "photo")
                    if model.selecting, let r = model.region {
                        Text("选区 \(Int(r.width)) × \(Int(r.height)) px")
                    } else {
                        Text("\(bitmap.width) × \(model.running || model.selecting ? bitmap.height : model.resultHeight) px")
                    }
                    Spacer()
                    Text(model.selecting ? "拖动可重新框选" : model.running ? "完成后查看拼接结果" : "请检查首尾与内容衔接")
                }.font(.caption).foregroundStyle(.secondary)
            }
            if let notice = model.automaticNotice {
                Label(notice, systemImage: "info.circle").font(.callout).fixedSize(horizontal: false, vertical: true)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: model.unresolved ? "exclamationmark.triangle" : "info.circle")
                Text(model.status).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }.font(.callout).foregroundStyle(model.unresolved ? Color.orange : Color.secondary)
        }.padding(22)
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 46, weight: .light)).foregroundStyle(.tint)
            Text("一张截图，或一整段内容").font(.title2.weight(.semibold))
            Text("选好窗口后，拖选正文范围。\n截取当前画面，或慢慢滚动拼成长图。")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.windows.isEmpty {
                Button("选择窗口…") { Task { await model.refresh() } }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
            } else {
                Label("从左侧选择要截取的窗口", systemImage: "arrow.left").font(.callout).foregroundStyle(.secondary)
            }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置与工具").font(.headline)
            Picker("唤起快捷键", selection: $model.shortcut) {
                Text("⌃⌥⌘S").tag(0); Text("⌃⌥⌘D").tag(1); Text("关闭").tag(2)
            }
            Button("打开屏幕录制权限设置") { model.openScreenRecordingSettings() }
            Divider()
            DisclosureGroup("开发与验收工具") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("打开合成测试窗口") { FixtureHost.shared.show(); showSettings = false }
                    Button("运行受控原生验收") { showSettings = false; Task { await model.nativeGate() } }
                    Text("仅供开发检查；内置字体对照尚未通过严格像素验收。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 8)
            }.disabled(model.bitmap != nil || model.busy || model.running || model.gateRunning)
        }.padding(20).frame(width: 320)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("第一次使用").font(.headline)
            Text("1. 选择窗口，预览后拖选正文。\n2. 选“截取所选区域”，或开始滚动截图。\n3. 回到目标窗口慢慢向下滚；结束时点“完成并预览”。\n4. 检查首尾和重复内容，再保存或复制。")
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("如果采集暂停").font(.callout.bold())
            Text("向上滚回已经截到的内容，再点继续。无法恢复时，完成并保存已确认的局部结果。")
            Text("固定导航栏请排除在选区外。整屏重复或滚动太快可能无法可靠拼接；结束采集不代表已经到达文档底部。")
                .foregroundStyle(.secondary)
            Text("自动滚动仍是实验功能，尚未通过实际自动采集验收。")
                .font(.caption).foregroundStyle(.secondary)
        }.font(.callout).padding(22).frame(width: 350)
    }

    private func reset() { model.cancel(); actualSize = false; showCrop = false }
}
