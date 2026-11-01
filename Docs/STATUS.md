# 当前状态

更新日期：2026-11-02（Asia/Shanghai）

**AWAITING_PERMISSION — S1 手动链路已实现，重建后 ad-hoc 身份需重授权；继续 S2/S3 独立开发。**

- 分支：`codex/scroll-capture-v1`，起点 `a922c13e5864c8e2281263a12d2af8c506f2b8a1`。PR #1 保留。
- 产品 Draft PR：https://github.com/yoCruzer/ScrollCapture/pull/2 （main）；PR #1 不变。
- 本机：Apple Silicon / macOS 27.0.1 (26A434) / Xcode 27.2 (27B52) / Swift 6.4.2；最低 macOS 15。
- 构建：`bash Scripts/build-app.sh`；启动：`open build/ScrollCapture.app`。
- Bundle ID：`com.yocruzer.ScrollCapture`；无开发签名证书，使用 ad-hoc 签名和固定路径；重建后重检 TCC。

| 阶段 | 状态 | 证据 |
|---|---|---|
| S0 | 实现/实采完成，待独立 review | release .app、codesign verify、GUI、ScreenCaptureKit 520×468 合成窗口、PNG 保存 |
| S1 | 实现完成 / 真实多视口待验 | 5 项配准定向测试通过；新构建 TCC 拒绝 |
| S2 | IN_PROGRESS | 条带/覆盖、回滚与分片 |
| S3 / F06 | NOT_STARTED | 未完成 |
| S4 | NOT_STARTED | 无 |

测试：`swift test --disable-sandbox`，2 tests / 0 failures（PNG 往返方向、无效输入）。首次沙箱内 dSYM 生成被拒，提权后构建通过。初次 TCC 拒绝保留为失败记录；用户授权重启后实际采集/保存成功。产品 SHA 将在下一个检查点绑定；不是文档 SHA 验收。

私有本地证据：`artifacts/s0/ScrollCapture.png`（仅合成窗口，gitignored）。真实屏幕/私聊/窗口标题不上传。当前无本 App 多视口证据，尚不能 READY。Chrome 参考不计入本 App 验收。

S0 独立 review 两项 P1 已修：异步旧操作与构建溯源。首版 .app 曾错误标记文档 SHA clean，旧 GUI/截图仅计提交前工作树观察；最终需干净产品 SHA 重建复核。
