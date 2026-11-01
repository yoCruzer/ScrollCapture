# 简短启动 prompt

直接将以下内容发给 Mac 上的 Codex：

```text
/goal
请在 https://github.com/yoCruzer/ScrollCapture 开始原生 macOS 截图与滚动截图工具的第一轮完整开发。当前完整启动文档位于 docs/initial-project-plan 分支和 Draft PR #1，main 尚未包含这些文件；先 fetch 并读取该分支的文档，再以其 HEAD 为基础创建 codex/scroll-capture-v1，避免从空 main 开始。保留 PR #1，不要覆盖或关闭。

先读 AGENTS.md、README.md、Docs/PRODUCT_REQUIREMENTS.md、Docs/EXECUTION_PLAN.md、Docs/STATUS.md；按需读架构、验收、研究与 Chrome V2 经验。核对远端、HEAD、工作区、Xcode/Swift/SDK；未知改动必须保留，必要时用独立 worktree。

在 codex/scroll-capture-v1 分支开发并创建一个指向 main 的 Draft PR；已有同目标进度则续接。按 S0–S4 连续推进到可运行 .app：真实采集、手动滚动端到端、接缝/覆盖恢复、长图分片导出、有界自动滚动、独立 review 与交付。不要停在计划、CLI、回放器或仅生成工程。默认中文。

每阶段提交并普通推送，正常阶段自动继续。实现、定向测试、独立审查和必要修复在 Codex 内闭环；复用准确版本且未受影响的证据，最终集中跑必要回归，不重复跑所有研究实验或每阶段全量测试。

严格遵守：滚轮量不是实际位移；高相似度不证明唯一位移；匹配失败不能整帧硬拼；合法重复内容必须保留；缺口暂停并可回滚补采或保存明确局部结果。Chrome 56053a0 是人工成功基线，490e0ce 是完整 CI 候选，均不是本原生 App 的验收证据。

权限/环境阻塞时列出最少用户操作并继续独立工作。核心真实采集、GUI 或受控多视口证据缺失时保持 BLOCKED/AWAITING_PERMISSION，不提前标 READY。F06 自动模式未完成须明示，不能称完整 V1。真实屏幕/私聊不得进入公开仓库。

持续更新 STATUS 和开发记录。最终交付 .app、构建/启动方式、精确源码 SHA、Draft PR、测试/review、限制和集中人工验收步骤。满足文档条件后停在 READY_FOR_OWNER_DEVICE_GATE。不要自动合并 main、强推或发布。
```
