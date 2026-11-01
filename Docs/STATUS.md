# 当前状态

更新日期：2026-11-02（Asia/Shanghai）

**READY_FOR_OWNER_DEVICE_GATE — 手动候选核心L3证据齐备，等待Owner集中设备验收。F06自动模式未通过，不是完整V1；不是OWNER_VERIFIED。**

## 交付候选

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
