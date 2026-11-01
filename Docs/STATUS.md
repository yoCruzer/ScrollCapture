# 当前状态

更新日期：2026-11-01（Asia/Shanghai）

**DOCUMENTATION_READY — 原生开发尚未开始。**

正式公开仓库：https://github.com/yoCruzer/ScrollCapture
默认分支：main。文档初始化分支：docs/initial-project-plan。后续产品开发分支：codex/scroll-capture-v1。

## 已完成
- 产品目标、范围、架构、竞品/开源研究、Chrome V2 经验、验收矩阵、S0–S4 计划。
- 两轮文档一致性 review；明确 READY 证据条件、App 权限身份、保存失败保护、研究实验不额外形成门禁。
- Chrome 参考身份：56053a021409a4771aa057d456f8138164f2d926 人工成功基线；490e0cec85211b2783b15e97e870721701833152 完整 CI 候选。

## 阶段
| 阶段 | 状态 | 原生证据 |
|---|---|---|
| S0 工程/真实采集 | NOT_STARTED | 无 |
| S1 手动端到端 | NOT_STARTED | 无 |
| S2 恢复/资源 | NOT_STARTED | 无 |
| S3 有界自动 | NOT_STARTED | 无 |
| S4 review/交付 | NOT_STARTED | 无 |

本仓库初始提交仅包含文档，不是产品源码或测试证据。

## 下一步
Codex 核对远端和工作区，创建 codex/scroll-capture-v1，启动 S0；确认真实 Xcode/Swift/SDK、稳定 Bundle ID，完成真实 App 截图与最小离线真值回放。缺少真实 GUI/TCC 条件时记录阻塞并继续不受影响工作。

无原生缺陷记录；原生实现尚未开始。