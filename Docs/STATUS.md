# 当前状态

更新日期：2026-11-26（Asia/Shanghai）

**AWAITING_PERMISSION**。Owner 在 M3 Pro 上报告「预览」滚动测试图始终 0 次拼接。本机使用旧交付 App 和系统「预览」复现白底长 PNG 首帧后即提示位移不唯一。实际滚动后长度仍冻结在 741 px、0 次拼接。对照的彩色纹理 PNG 可新增 156 px。旧候选结论已撤回。

修复源码 `2ec99504203cb4323e0f28bd4fff6b0a916f75e6`。相同首帧重绘仅作为无新证据处理；稀疏取样同分时复核完全相同的重叠并排除所有可接受的替代位移。短暂视觉失败冻结长度，在两秒内从最后确认位置核对新帧。过期、队列丢帧和尺寸变化仍暂停。

- 本机 macOS 27.0.1 arm64 / Xcode 27.2 / Swift 6.4.2，release 30/30 通过。白底长图离线回放从 741 px 到 1541 px，共 166 次拼接，34 帧被拒，最终独立原图对比最大通道误差 0。独立 review 与剩余边界见 [REVIEW](REVIEW.md)。
- M3 Pro 使用 `build/ScrollCapture-2ec9950-arm64.zip`（SHA256 `77ea2ddc6c93737b459dd22e503bceb7a550acfedf489e083bcf16591c44808d`）。Intel 使用 `build/ScrollCapture-2ec9950-intel.zip`（SHA256 `f1b39ba131a959efc3aa9a951e915f12e69274250fd0b0ff6e2af9a166bb5e1d`）。两包解压后验证签名、架构、macOS 15.0 最低版本及 clean 源码身份。
- 产品源码的 [独立 CI](https://github.com/yoCruzer/ScrollCapture/actions/runs/45724426824) 覆盖回归、构建和签名。
- 本机新 App 已启动，读取窗口时提示需要重新授权。新版「预览」真实采集、M3 Pro 原图复测及 Intel 实机操作待验，F06 自动未通过。操作见 [人工测试 SOP](OWNER_TEST_SOP.md)。

## 2026-11-22 历史手动候选

**READY_FOR_OWNER_DEVICE_GATE（手动候选）**。测试前审查修复版源码为 `b916dcdb6c74f756ad5fa8d1154e27486bf83509`。用户重新授予本机 arm64 App 录屏权限后，真实受控窗口手动采集已通过。F06 自动仍未通过。

- 本机交付 `build/ScrollCapture.app`，压缩包 `build/ScrollCapture-b916dcd-arm64.zip`，ZIP SHA256 `f00e2efe9ba7fb657aa348bd37e2a6e5c7b46e05b945caecce19f689fb6dbfc9`。
- Intel 笔记本请传输 `build/ScrollCapture-b916dcd-intel.zip`，ZIP SHA256 `f1acd503313ccea3677d579f8c210dea1b789dd7d4b94941ecde88418b372a6b`。两包分别验证 arm64/x86_64、Mach-O 最低系统 15.0、签名和 clean 来源。Intel 真机启动、显示效果与 TCC 等待 Owner 反馈。
- 本机 release 27 项通过（23 核心、4 流程），环境 macOS 27.0.1、Xcode 27.2、Swift 6.4.2。审查范围、复现和剩余风险见 [REVIEW](REVIEW.md)，设备步骤见 [SOP](OWNER_TEST_SOP.md)。

- 新版真实 GUI 使用 718×513 选区。独立宿主 y=0/118/236/354 后确认 867 像素，快滚到 946 触发暂停，回到 354 继续到 472。最终 4 次拼接，保存 718×985 PNG；独立原图 (18,22) 处对比 0 坏行、最大通道误差 0。录屏授权与开发侧操作不计作 Owner 人工通过。

- [CI 45006195951](https://github.com/yoCruzer/ScrollCapture/actions/runs/45006195951) 已完成，回归、App 构建与签名检查均成功。

## fd91e23 历史交付记录

**READY_FOR_OWNER_DEVICE_GATE — 新手体验改版已完成，真实GUI、原生多视口/恢复及独立像素复核通过。F06仍未通过，不是完整V1、不是OWNER_VERIFIED。**

2026-11-20：新增 [Owner人工真机测试SOP](OWNER_TEST_SOP.md)，按A–F执行手动核心检查，再补实际应用；自动作为独立可选诊断。此次仅说明文档，产品仍为fd91e23，不重建、不重复测试、不改变门禁结论。

## 2026-11-15 新手体验改进

- 问题与处理清单：[UX_REVIEW](UX_REVIEW.md)。三步导航、分阶段操作、预览画布、权限引导、选区确认后导出、放弃确认、裁剪说明、长图分片提示、实验自动的持久停止反馈。
- 修改范围为App界面/协调状态及4项流程测试；CaptureCore、LiveStream、ScrollDriver、ScreenSource未修改。旧版逐像素证据保留，不冒充新二进制GUI证据。
- `swift test -c release --disable-sandbox`：24/24通过（20核心+4流程）；环境macOS27.0.1 / Xcode27.2 / Swift6.4.2，arm64。
- 独立只读review发现3项P2并修复：最终尺寸冻结、自动停止状态、旧清理提示覆盖。增量复核无新阻断。
- 初次新界面实际启动、首屏布局和权限拒绝引导已检查；该次是提交前工作树构建，不能作为最终SHA的采集证据。
- 用户已为实际新版App重新授权；最终干净产品源码：`fd91e23c553f031b10cc864471cfa6c12131af95`，`working_tree_dirty=no`。后续仅文档提交不重编译受测产品。
- 新App：`build/ScrollCapture.app`；压缩包：`build/ScrollCapture-fd91e23.zip`。二进制SHA256：`963e8abc7584fea7b41e11667d707c0d618950b11bb7cc1143ceeca83b212aa0`；压缩包SHA256：`3692115c10bc703f7ee5d4a9b9e3501bbf23ccba694a421968ec134327e9c0fd`。旧版备份为`build/ScrollCapture-303c331.app`，不要混淆版本授权。
- 新版实际GUI：最小宽度900的首屏/选择/结果页可操作；原生PNG宿主窗口760×592，拖选718×513，单张裁上10/下20得到718×483；复制成功反馈、100%预览、保存PNG、放弃确认取消/确认、重新进入框选均通过。
- 新版真实手动：原生宿主实际y=0/118/236/354，已确认867；快滚到946缺口暂停、长度仍867；回354继续到472得到718×985、4次拼接。HUD主动暂停与异常恢复说明、完成返回预览与PNG保存通过。
- 独立reviewer以标准库PNG解码/CRC验证、全文首行搜索和完整RGBA比较：裁剪图718×483在不可变oracle(18,32)唯一匹配，1,387,176字节零差异；滚动恢复图718×985在(18,22)唯一匹配，2,828,920字节零差异。偏移一行的负对照均失败。报告留本地忽略目录，reviewer没有独立重演GUI。
- [CI 43698477095](https://github.com/yoCruzer/ScrollCapture/actions/runs/43698477095)：核心/流程回归、App构建、签名均成功。未重复旧研究矩阵或把CI当GUI证据。
- 本轮NOT_RUN：新版Safari全流程、超8MP真实分片、自动真实推进、完整VoiceOver/深色模式/不同显示比例。核心实现未变的旧基线保留，下方数字不记为新版执行。
- Owner下一步：打开当前新版App，按[新版三步操作](BUILD_AND_VALIDATE.md#新版三步操作)用非敏感实际内容检查范围、慢滚、首尾、暂停恢复与保存。F06真实推进仍需独立解决，不把体验改版当成自动验收通过。

以下为**旧版303c331的历史交付证据**，其READY结论不自动适用于本轮新二进制。

## 旧版交付候选

- 产品源码：`303c331b45740055801c0f11f6ff12534fa5460e`，分支 `codex/scroll-capture-v1`。
- 产品 [Draft PR #2](https://github.com/yoCruzer/ScrollCapture/pull/2) 指向 main；启动文档 [Draft PR #1](https://github.com/yoCruzer/ScrollCapture/pull/1) 保留。
- 起点：启动文档 HEAD `a922c13e5864c8e2281263a12d2af8c506f2b8a1`，没有从空 main 开始。
- App：`build/ScrollCapture.app`，Bundle ID `com.yocruzer.ScrollCapture`，arm64，最低 macOS 15。构建：`bash Scripts/build-app.sh`；启动：`open build/ScrollCapture.app`。
- 干净产品构建，资源记录 `working_tree_dirty=no`；二进制 SHA256：`76561293064a674eade6809c6a183c9e1ae2cfe669dcf543ff843b4a5afebf9d`。
- ad-hoc 本机签名，无开发证书/公证。重编译后旧授权实测失效；用户已重新授权；相同二进制退出重启后权限有效。保留此受测二进制，避免无谓重建。

## 阶段与证据

| 阶段 | 实现/检查 | 尚缺证据 |
|---|---|---|
| S0 工程/单张 | 303c331真实GUI、SCK窗口快照、区域、PNG/复制、构建签名、重启权限复核通过 | Owner其他设备 |
| S1 手动 | 原生3接缝723×868、Safari4接缝732×1241，独立真值全图逐像素零误差 | 更多真实应用人工兼容性 |
| S2 恢复/资源 | Safari真实丢重叠暂停/回滚恢复、裁剪零误差；取消/退出原始条带清零；分片定向测试通过 | GUI超8MP分片、scale/TCC撤销设备检查 |
| S3 / F06 | 控制实现/3项策略测试通过；真实尝试安全停止但未观察自动覆盖 | **F06未完成/未通过**，B01+B03仍缺通过证据，见KNOWN_ISSUES |
| S4 | [独立review](REVIEW.md)、20项集中回归、CI成功，实际App启动/退出/重启与核心L3证据齐备 | 停在Owner设备门禁，不自动合并/发布 |

## 已完成验证

- 本机 Apple Silicon / macOS27.0.1 (26A434) / Xcode27.2 (27B52) / Swift6.4.2 / SDK27.2。
- `swift test -c release --disable-sandbox`：20/20、0失败，用例0.120s。含24接缝独立真值、±1px、重复内容、长周期/稀疏标志歧义、半像素拒绝、缺口/回滚/逆滚、固定遮挡、资源/取消、分片/裁剪逐像素重组、保存失败/重试、自动策略。
- 整个构建测试命令5.99s，RSS峰值554631168 bytes（含编译器，不是App常驻内存）；1280×720配准0.01117s。
- `bash Scripts/build-app.sh`、`codesign --verify --strict`成功；候选实际GUI启动成功；初次TCC拒绝保留，用户重新授权后真实采集、退出及重启复核通过。
- [CI run 41326467704](https://github.com/yoCruzer/ScrollCapture/actions/runs/41326467704)：macOS15.8.2 / Xcode16.4 / Swift6.1.2，20/20，App构建与签名检查通过；测试合并tree `9b977890cd883c6299da10df7396e718aa51b068`，head为303c331。不是GUI/TCC证据。
- reviewer增量复核303c331：此前P1/阻断P2代码层面关闭，无新阻断；真实多视口/F06在review中NOT_RUN。
- 独立图像比较工具修正初始化API后，自比0差异为PASS、不同真值468坏行为FAIL；仅验收脚本变化，不改变303c331产品二进制。

## 保留的失败与限制

初版bundle误标文档SHA为clean，现已修复；S0截图仅计提交前工作树观察，不冒充准确源码验收。CI首轮41325743879因SDK15缺SCK并发标注编译失败，后续兼容修复通过；失败记录保留。TCC旧授权不能替代新二进制。

仅可靠支持可见重叠内的垂直整数像素平移；完全重复整屏/超视口周期/跨无重叠跳跃/亚像素重采样无法普遍判别。固定栏须框选排除，不做遮挡覆盖假设。Intel、Retina/多显示器、真实聊天应用人工验收仍NOT_TESTED。内置字体重绘oracle失败与自动反馈限制见[KNOWN_ISSUES](KNOWN_ISSUES.md)。Chrome 56053a0/490e0ce不是本App验收证据。

## 核心真实证据（同一303c331二进制）

| 用例 | 独立真值/实际操作 | 结果 |
|---|---|---|
| 原生手动 | 独立NSScrollView显示不可变合成PNG；实际y=0/118/236/354，选区[16,50,723,514] | 723×868、3接缝，0坏行、每通道最大误差0 |
| Safari手动+恢复 | 独立canvas PNG；scrollY=0/143/286/429→1379缺口→429回滚→572 | 732×1241、4接缝，缺口时边界冻结1098；最终全图误差0 |
| GUI裁剪/保存/复制 | Safari结果上下裁10/20像素、保存PNG；完整图复制成功反馈 | 732×1211，与oracle x16/y35逐像素误差0 |
| 临时资源/退出 | 正在采集时取消与退出；检查App自有目录计数 | 1目录/2510256 bytes→0目录/0 bytes；退出进程消失，重启权限有效 |
| 内置原生字体oracle | 5接缝488×1008，对照完整NSView离屏重绘 | FAIL保留，字体像素差异；不作为通过证据 |
| 自动B01/B03 | 实际尝试没有新增自动覆盖；工具诊断看到真实前台仍为Codex | 未通过，不计F06完成，不放宽目标保护 |

私有证据在gitignored `artifacts/final-303c331` 与 `artifacts/native-*`。公开只保留合成源、数字摘要和hash。实际采集期间RSS一次采样189216KiB，不是峰值。交付压缩包 `build/ScrollCapture-303c331.zip` SHA256：`8732a345a838336917adacf2670cd9a6fd58e2560901db001d7ac05bb9003990`。

## Owner集中门禁

1. 直接打开当前 `build/ScrollCapture.app`（无需重建）。用非敏感内容做普通截图、正文框选、3段慢滚、暂停/回滚恢复、首尾与重复行、保存/复制/裁剪复核。
2. 在**实际macOS桌面**而非聊天中的后台预览，切到目标App前台；完成3个手动接缝后启用自动，把真实鼠标置于正文；核对是否至少3次新增、是否可接管/失焦停止。原生与Safari都通过前F06保持未完成。若仍不滚动，保留现状继续诊断，不取消目标保护。
3. 补Retina/多显示器、采集中撤销权限、超8MP真实分片与实际聊天客户端的非敏感样本；不可用记NOT_TESTED，不改变账号环境。

完整步骤见 [BUILD_AND_VALIDATE](BUILD_AND_VALIDATE.md)。只有Owner明确确认后才可标OWNER_VERIFIED；本轮停在READY_FOR_OWNER_DEVICE_GATE，保留Draft PR，不合并或发布。

最终独立证据复核另用Python标准库PNG解码器确认三张实际图RGBA逐字节零差异，且产品/压缩包身份一致；结论支持手动候选Owner门禁，F06仍未通过。证据说明见REVIEW。

交付检查点e041c0b的[最终CI run41329723056](https://github.com/yoCruzer/ScrollCapture/actions/runs/41329723056)核心回归、App构建、签名全部成功。末次仅文档证据追加，不重跑未受影响的产品检查。
