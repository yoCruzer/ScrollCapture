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

## 2026-11-02 — S2 恢复、资源与证据完整性
- 新增 CommitPermit、封存、PNG有序分片+manifest、失败重试与临时目录事务；资源上限见 DECISIONS D18。
- `swift test --disable-sandbox --filter RecoveryExportTests`：首次7/7，加入审查反例后8/8（3.071s）。包括合法重复保留、半像素拒绝、同帧零追加、失效许可、精确分片拼回真值、既有文件保护、错误路径重试、取消清理、极端坐标。
- 独立 review 固定94ddadd复现周期150/视口160/跳跃170被误认dy20的P1；已扩全重叠替代候选检测，真小位移与跳跃别名成对拒绝，前缀不变。无法观测的整屏重复边界见 D17，绝不宣称普遍唯一。
- review发现SCK contentRect字典类型可能导致全帧静默丢弃；已安全解码、加入contentScale、元数据错误显式中断及8秒无首帧提示。重建后真实采集待集中授权。
- Stream序号检测本地有界队列丢帧，暂停并要求回滚补采，不能把低帧率下的局部匹配视作绝对连续证据。

## 2026-11-02 — S3 有界自动与体验
- 真实CGEvent单步驱动：当前窗口手动通过3接缝后才可启用；3秒准备、不移动光标、前台PID+鼠标下窗口ID+冻结几何检查、辅助功能按需、120秒/80步/3秒无进展停止，真实覆盖增长后才允许下一步；任何用户滚轮/点击/按键接管。
- `swift test --disable-sandbox --filter AutoPolicyTests`：3/3，通过真实已提交像素/时间、无进展不等于到底、失焦立即停、步数/时长边界。真实B01/B03尚待最终候选授权，F06仍未完成。
- 可配置Carbon全局唤起快捷键、100%预览、上下像素裁剪、导出取消入口、原生受控验收按钮（生产stream/账本 vs 独立完整NSView渲染与宿主scroll坐标）。
- 构建前后比较源码hash清单及HEAD，避免编译中源码变化产生错误溯源。远端macOS CI在稳定检查点验证核心和.app构建，不充当GUI/TCC证据。
