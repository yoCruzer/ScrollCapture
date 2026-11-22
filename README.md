# ScrollCapture

原生 macOS 截图与垂直滚动截图工具，Swift 6 + SwiftUI/AppKit + ScreenCaptureKit，macOS 15+，本地处理。

测试前审查修复版 `b916dcd` 已提供 Apple Silicon 和 Intel 两个 macOS 15+ 测试包。新版真实多视口采集与缺口恢复逐像素通过，当前等待 Owner 真机测试，F06 自动仍处于实验阶段。包路径、证据及限制见 [STATUS](Docs/STATUS.md)，人工操作见 [测试 SOP](Docs/OWNER_TEST_SOP.md)。

```sh
bash Scripts/build-app.sh
open build/ScrollCapture.app
```

选窗口、框选正文、普通截图或手动滚动；非激活HUD、暂停/回滚恢复、预览/100%、上下裁剪、PNG/整图复制、长图有序分片。当前窗口先手动验证3个接缝后可尝试有界自动：单步输入、真实覆盖确认、停止/超时/回手动。失败不整帧硬拼、不推进可信前缀。

[构建、权限及集中验收](Docs/BUILD_AND_VALIDATE.md) 包含准确支持边界。稳定 Bundle ID `com.yocruzer.ScrollCapture`；默认本机 ad-hoc 签名，重建可能需重新授权。无开发证书、未公证，不是正式分发版本。

## 文档

- [产品要求](Docs/PRODUCT_REQUIREMENTS.md)、[执行计划](Docs/EXECUTION_PLAN.md)、[唯一状态入口](Docs/STATUS.md)
- [架构](Docs/ARCHITECTURE.md)、[验收](Docs/ACCEPTANCE.md)、[决策](Docs/DECISIONS.md)、[开发记录](Docs/DEVELOPMENT_LOG.md)
- [研究](Docs/RESEARCH.md)、[Chrome V2经验](Docs/CHROME_V2_LESSONS.md)

Chrome `56053a0` 是人工成功基线，`490e0ce` 是完整CI候选，均不是本App验收证据。真实屏幕与私聊不进入公开仓库。未引入第三方实现；仓库公开不等于已选定项目许可证。
