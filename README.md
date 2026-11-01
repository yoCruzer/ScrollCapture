# ScrollCapture

面向 macOS 的原生截图与滚动长截图工具。正式仓库：[yoCruzer/ScrollCapture](https://github.com/yoCruzer/ScrollCapture)。

> 当前状态：启动文档已准备，原生应用尚未实现、构建或验收。研究结论和 Chrome 插件证据不是本 App 的通过记录。

## 第一轮交付
- 原生 `.app`、菜单栏入口、稳定 Bundle ID。
- 普通区域/窗口截图。
- 单个垂直区域的手动滚动截图：采集、反馈、暂停/恢复、完成、预览、PNG 保存/复制。
- 可靠拼接、重复内容保护、缺口恢复、局部结果、长图分片。
- 在已验证目标上实现有界自动滚动；自动控制失败安全停止并回手动。
- 定向测试、独立 review、真实构建与集中人工验收。

OCR、云同步、录屏、复杂标注、VCP 和商店发布延期。

## Codex 从这里开始
读取 AGENTS.md、Docs/PRODUCT_REQUIREMENTS.md、Docs/EXECUTION_PLAN.md、Docs/STATUS.md，再按需读架构、验收与研究文档。用 Docs/CODEX_START.md 的短 prompt 启动一个 `/goal`，按 S0–S4 连续推进。正常阶段自动继续；权限/环境阻塞集中说明，不阻塞独立工作。

## 文档导航
| 文档 | 用途 |
|---|---|
| [PRODUCT_REQUIREMENTS](Docs/PRODUCT_REQUIREMENTS.md) | 产品目标、范围与完成标准 |
| [EXECUTION_PLAN](Docs/EXECUTION_PLAN.md) | S0–S4 连续执行计划 |
| [ARCHITECTURE](Docs/ARCHITECTURE.md) | 采集、配准、覆盖、恢复、资源 |
| [ACCEPTANCE](Docs/ACCEPTANCE.md) | 证据层级与验收矩阵 |
| [RESEARCH](Docs/RESEARCH.md) | 竞品、开源源码和来源 |
| [CHROME_V2_LESSONS](Docs/CHROME_V2_LESSONS.md) | 56053a0/490e0ce 经验及迁移边界 |
| [DECISIONS](Docs/DECISIONS.md) | 已确定取舍 |
| [STATUS](Docs/STATUS.md) | 唯一当前状态入口 |
| [DEVELOPMENT_LOG](Docs/DEVELOPMENT_LOG.md) | 阶段记录 |
| [CODEX_START](Docs/CODEX_START.md) | 可直接转发的启动 prompt |

## 技术方向
Swift 6、SwiftUI + AppKit、ScreenCaptureKit；Vision 平移仅作为候选，必须独立验证。Apple Silicon 优先；macOS 15 为初始最低目标，S0 核对实际 SDK。默认离线处理，不依赖 Apple Intelligence 或云端模型。

## Chrome 固定参考
- [56053a021409a4771aa057d456f8138164f2d926](https://github.com/yoCruzer/chrome_extensions_dev/commit/56053a021409a4771aa057d456f8138164f2d926)：用户确认的人工成功基线。
- [490e0cec85211b2783b15e97e870721701833152](https://github.com/yoCruzer/chrome_extensions_dev/commit/490e0cec85211b2783b15e97e870721701833152)：完整 CI 候选，仍待人工验收。

仓库公开不等于已选定项目许可证。引入第三方实现前记录来源、固定版本和许可证。真实屏幕帧、私聊、窗口标题、个人路径和私有诊断不得进入公开 Git/CI。