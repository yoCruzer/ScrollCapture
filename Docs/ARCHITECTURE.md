# 架构与快速实验

状态：设计基线，尚未实现/构建/真实 Mac 验证。

## 技术方向
Swift 6；SwiftUI + AppKit；ScreenCaptureKit 单帧与 SCStream 连续采集；Vision Translational Registration 只作为位移候选；自有像素重叠验证决定是否接受；CGEvent 仅用于可选有界自动滚动；Accessibility 仅辅助，不是统一真值。首轮不依赖 OpenCV、云服务、Apple Intelligence 或 OCR。

## 逻辑模块
CaptureCoordinator（会话/状态）；SelectionOverlay（选区/HUD）；PermissionController；ScreenFrameSource；FrameNormalizer；MotionEstimator；OverlapValidator；CoverageLedger；StripStore；ScrollDriver；ResultExporter；ReplayHarness。初始可放在少量文件中，不要求过早拆 Package。异步任务携带 sessionID、generation、frameID，旧回调不能提交到新会话。

## 状态与正确性
会话状态 idle/selecting/preparing/capturingManual/capturingAuto/paused/finishing/resultReady/exporting/cancelled。结果另记 captureIntegrity、endReason、documentExtent、unresolvedRegions。用户结束但区间连续可以完成，不代表文档到底；内部缺口不能伪装完整。

## 坐标
分别表示桌面全局坐标、显示器本地点坐标、捕获 bitmap 像素坐标、重建内容相对坐标。不得假设 Retina 恒为 2 或屏幕点与像素一一对应；用真实 CGImage/CVPixelBuffer 和 ScreenCaptureKit 元数据核验。选区吸附后的边界在确认前展示。候选和累计位置可浮点，按绝对累计边界取整，避免逐帧误差。

## 采集与配准
SCStream 帧到达不代表目标内容加载完成。队列有界、有背压；丢帧后必须重新证明重叠。Vision 产生多个候选，独立检查有效重叠、纹理、分散区域共识、最佳/次佳差距、颜色残差、尺寸/scale 一致性。confidence 不是概率。无唯一解时暂停；匹配失败不得 overlap=0 后整帧追加。

固定栏分别建 registrationMask 与 validContentRegion。排除固定像素参与匹配，不证明其遮挡正文已经被捕获。逆滚只更新当前位置，不减少已确认最远范围；恢复失败保留可信前缀。

## 自动控制
同一拼接引擎；每步发送、观察、验证、提交后再发送。默认不移动光标；用户接管/失焦/目标变化/几何变化/取消后立即停止。多帧不动不等于到底。手动模式不依赖自动控制权限。

## 资源与导出
有界候选帧、临时磁盘、像素、长度、时长、恢复次数。条带/分块存储，避免每帧重绘全图。基础多 PNG 分片属于首轮；通用流式编码器可后置。保存先写临时目标、验证后完成；失败/取消不破坏原文件，用户确认后才替换。剪贴板与文件保存分别报告。

## 实验
E0 真实 App 单张采集与坐标/权限；E1 已知真值离线帧、重复/低纹理/微位移；E2 受控原生窗口与真实手动闭环；E3 同一核心上有界自动控制。E 是实验索引，按 S0–S4 风险使用，不是额外阶段。真实 GUI/TCC 缺失不得用回放冒充。