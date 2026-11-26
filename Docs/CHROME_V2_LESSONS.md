# Chrome V2：有效经验与原生迁移边界

固定版本身份：
- [56053a021409a4771aa057d456f8138164f2d926](https://github.com/yoCruzer/chrome_extensions_dev/commit/56053a021409a4771aa057d456f8138164f2d926)：用户确认的最近人工成功基线。
- [490e0cec85211b2783b15e97e870721701833152](https://github.com/yoCruzer/chrome_extensions_dev/commit/490e0cec85211b2783b15e97e870721701833152)：完整 CI 候选，仍待下一轮人工验收。
- [两版本比较](https://github.com/yoCruzer/chrome_extensions_dev/compare/56053a021409a4771aa057d456f8138164f2d926...490e0cec85211b2783b15e97e870721701833152)；[CI run](https://github.com/yoCruzer/chrome_extensions_dev/actions/runs/35700711610)：132 Node、15 Chrome 分组、总 gate 全部成功。Ubuntu/Chromium CI 不是 Mac App 证据。

## 基线经验
1. Full Page 与 Region 坐标契约不同；Region 冻结用户四边，viewport 横向坐标与内部 cropLeft 分离。原生需区分桌面点、窗口/显示器、bitmap 像素、累计输出坐标。
2. 页面准备有界预热后回到起点建立正式基线；pending 帧变化可局部重采，已提交区域变化进入复核。只有 offscreen 接受并绘制后才 FULL_COMMIT。原生继承“采样→检查→配准→绘制→提交”，不继承 DOM 真值。
3. 视觉分块评估纹理、最佳/次佳候选和多块共识；Robust/Strict 有不同策略；subject-core 可匹配但边缘仍可能变化，不等于全宽一致。
4. 56053a0 的 1 CSS px 容差只限 terminal authorization；仍要求短尾上限、多次稳定、图片 ready、fresh capture 和前后核对。不能把几帧静止等于到底。
5. 输出保持固定比例，绝对边界先取整；分片和异常清理有界。一个 canvas 不等于任务内存恒定。

## 490e0ce 的生产修复
- 相邻行同分时不能按排序选择 524 代替预期 525，否则连续接缝可系统性少一行。只有质量证据或最佳/次佳有明确差距才允许视觉纠偏；否则保留有依据的预期并标记 probable。测试保留真实 ±1px 位移正例。
- Region resize 重试刷新失效的目标视口测量，但保留原窗口/tab/zoom 环境和用户四边；第二次 resize 仍 fail-closed。
- 编码异常通过 finally 释放资源。

## 测试经验
独立 Region oracle 用真实 bitmap、独立视口与冻结范围逐行比对，不复用生产 FRAME 当答案；动态故障在第一张正式 bitmap 后触发，避免 warmup 提前消耗；区分生产 bug、旧测试契约和自动化驱动错误。完整 CI 必须检查实际 jobs。

## 原生迁移限制
浏览器有 DOM、scrollTop、内容高度、可修改页面样式；任意 macOS App 通常没有。可迁移的是证据分级、唯一性、覆盖账本、有界恢复、独立 oracle 和资源所有权；不能把滚轮量当 expectedOffset，也不能直接搬 CSS 阈值/坐标。