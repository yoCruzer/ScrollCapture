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

## 2026-11-02 — S4 审查闭环（候选冻结前）
- 独立审查c658504：自动用提交时钟误认旧帧、忽略浮层、受控验收流程跨会话污染、退出未等待原始条带清理。均已修复：host采集时钟、全部非透明窗口层、验收独占gateID/跨await检查/绑定engine、terminateLater等待会话和导出清理。
- 独立稀疏唯一标志probe指出采样次佳与完整残差集合不同；最终对所有可见竞争位移跑同一完整残差，任何替代解通过即暂停，并新增反例。
- CI run 41325743879 在 macOS15.8.2 / Xcode16.4 / Swift6.1.2 编译失败：旧SDK没有SCK Sendable标注。采用SDK兼容preconcurrency导入及主线程completion bridge，等待start完成后stop，继续新检查点验证；原失败不删除。
- 新增纯合成Safari夹具与独立NSBitmapImageRep像素比较脚本，不导入生产CaptureCore。构建与集中Owner步骤写入BUILD_AND_VALIDATE。

## 2026-11-02 — 冻结候选真实原生证据
- 用户为303c331重新添加屏幕录制/辅助功能并重启，SCK权限有效。
- 内置NativeGate首次创建窗口后立即查询未找到目标而失败；在已渲染窗口上重试成功采集5接缝、488×1008、宿主位置0/120/240/360/480/600，但严格像素oracle失败：3523通道>2、最大21、均值0.29369；差异局限字体抗锯齿区域。保留FAIL，不改阈值冒充PASS。
- 为排除离屏字体重绘差异，新增独立Tools/NativeOracleHost.swift：原生NSScrollView显示不可变sRGB合成PNG，不导入CaptureCore；不修改已授权产品二进制。
- 303c331生产手动链路：窗口760×592，框选[16,50,723,514]；真实鼠标滚轮宿主实际y=0→118→236→354（输入量不作位移）；3接缝，GUI完成/保存723×868。
- 独立NSBitmapImageRep比较对应oracle x16/y18：badRows=0、channelsOver2=0、max/mean error=0。实际PNG与oracle仅存本机artifacts/final-303c331，公开Git只记录数字/合成源。
- 真实捕获期间RSS一次采样189216KiB（非峰值）；此前命令RSS包含编译器，不能混用。
- 自动模式在电脑工具操作中因目标/鼠标保护安全停止；工具不支持只移动鼠标，已请求Owner只协助点HUD后将真实指针放入受控正文，再由Codex核对位移与输出。尚不计F06通过。

## 2026-11-02 — Safari真实手动/恢复与导出
- 冻结303c331，Safari窗口1622×950、正文选区[16,235,732,669]；独立页面scrollY依次0/143/286/429，生产确认1098px、3接缝。
- 真实快滚跳到1379：明确“缺少可靠重叠”并暂停，确认长度仍1098，不硬拼。回滚429、显式恢复、再到572，只追加143，完成732×1241、4接缝。
- GUI保存PNG后用独立canvas真值x16/y25比较全部像素：0坏行、0误差。复制按钮报告完整结果；上下裁剪10/20后保存732×1211，对应真值y35同样0坏行、0误差。
- 真实取消后App自有临时会话目录从1个/2510256 bytes变为0个/0 bytes，未删除未知目录。
- 当前已具备原生+Safari真实手动L3多视口证据；F06仍单独待验。首次Owner协助自动后宿主位置未变化，不计通过。第二次明确先激活目标再启动，避免把失焦安全停止误认为自动成功。

## 2026-11-02 — 第一轮交付门禁
- Owner报告Safari自动“没有看到滚动”；生产确认高度未新增，F06明确未通过。只读工具复现诊断发现系统前台仍为Codex，后台UI点击不改变真实前台，目标保护拒绝输入；不能据此宣称所有Owner失败根因已排除。保留保护，列F06-01与停止消息UX-02限制。
- 在活动会话中⌘Q：进程结束，App自有临时目录0/原始条带0bytes；重新打开同一303c331并刷新成功，授权保持。
- 本轮核心手动L3、恢复、独立review、准确二进制/本机回归/CI/交付说明齐备，按文档停READY_FOR_OWNER_DEVICE_GATE（手动候选）；非OWNER_VERIFIED、非完整V1，F06必须进一步设备验证。
- 打包build/ScrollCapture-303c331.zip；产品源码/资源/build脚本与303c331无差异，后续仅验收工具和记录变化，复用准确未受影响的20项测试/CI与L3证据，不重建触发TCC。
