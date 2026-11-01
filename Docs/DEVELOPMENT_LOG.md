# 开发进展

## 2026-11-01 — 初始文档
- 用户指定正式公开仓库 yoCruzer/ScrollCapture。
- 整理产品范围、架构、竞品与开源研究、Chrome V2 两个固定版本经验、验收矩阵和 S0–S4 执行计划。
- 文档独立 review 明确 READY 需要核心真实采集/GUI/受控多视口证据；研究实验不是额外串行门禁；测试宿主权限不能替代实际 App 权限。
- 当前只有文档，无原生实现、构建或运行验证。

每阶段追加实际变化、证据与下一步；当前状态以 STATUS.md 为准。
## 2026-11-01 — S0 工程与真实采集
- fetch/阅读启动文档 HEAD a922c13；干净工作区，无同目标远端分支；从该 HEAD 创建 codex/scroll-capture-v1，PR #1 保持 Draft/open。
- SwiftPM 原生 App、SwiftUI 菜单栏/窗口选择、ScreenCaptureKit 单张截图、PNG/剪贴板、合成 NSScrollView、固定 Bundle ID 构建脚本；无第三方依赖。
- 本机 release 构建、codesign 校验、GUI 启动成功；基础测试 2/2。实际 App 首次 TCC 拒绝，用户授权重启后实采 520×468，GUI 预览/保存成功，文件仅在 gitignored artifacts。
- 依据本机 SDK 与 Apple SCContentFilter 文档采用 desktopIndependentWindow，隔离 HUD 和无关窗口。最低 macOS 15。ad-hoc 签名跨构建授权稳定性需持续重检。

## 2026-11-02 — S1 手动链路检查点
- S0 精确产品提交 c3be097541d992c6d9ceda2e1767f519b7eb3683；产品 Draft PR #2 指向 main，PR #1 保留。
- 独立 S0 review 指出旧异步结果覆盖新目标、未跟踪源码漏记 dirty 两项 P1；会话 generation/目标复核/方法互斥及完整源码 hash 清单已修复。初版 bundle 曾错误标为文档 SHA clean；此前截图仅为提交前工作树观察，保留失败记录，不用于精确 SHA 验收。
- SCStream 有界队列、真实帧时间和几何、正文像素框选、非激活 HUD、窗口独立过滤、手动暂停/恢复/结束、连续覆盖条带存储。全重叠像素复核，不做固定栏 mask；用户需框选正文。
- `swift test --disable-sandbox --filter RegistrationTests`：5 tests / 0 failures，4.676s，涵盖 24 接缝/独立真值、±1px、周期/纯色歧义、丢重叠回滚、逆滚、固定栏失败、尺寸/资源/取消。中途首次编译因 HUD 提前于模型字段写入失败，完成模型后通过。
- release .app 重建成功；实际 GUI 可打开，但新 ad-hoc 二进制 TCC 被拒。S1 真实多视口 NOT_RUN，暂 AWAITING_PERMISSION；先继续独立 S2/S3，最终候选集中重授权。
