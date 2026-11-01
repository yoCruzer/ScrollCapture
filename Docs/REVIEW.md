# 独立只读审查记录

审查在 Codex 独立 reviewer 中完成，未由实现者自评替代；reviewer不修改仓库、不发布GitHub评论。以下 SHA 均为源码快照，真实证据另见 STATUS。

| 固定版本 | 发现 | 修复/复核 |
|---|---|---|
| c3be097 | P1 await旧结果覆盖新目标；P1未跟踪源码遗漏dirty | 方法互斥、generation/目标校验；未跟踪检查、完整源码清单、构建前后比对 |
| 94ddadd | P1 150px周期/160px视口/实际跳170被认dy20；P1 contentRect字典直接cast可能丢全部帧 | 全可见重叠搜索+成对反例；字典解码/contentScale/超时；暂停CommitPermit与attempt |
| c658504 | P1自动把旧帧提交时间当发送后进展；P1忽略浮动遮挡；P1 NativeGate跨会话污染证据；阻断P2退出未等待原始条带清理 | 帧采集host clock；全部非透明层；gateID独占/跨await/绑定engine；terminateLater等待cleanup/export |
| 303c331 | 增量复核以上修复 | reviewer结论：代码层面关闭此前阻断项，未发现新阻断；不等于真实GUI/F06通过 |

另外 reviewer 的独立稀疏标志 probe 指出采样runner与全残差可接受集合不同；最终不只验证最佳候选，所有竞争位移都用同一全像素/逐行验证，任一替代位移可接受即暂停。新增针对反例的定向测试通过。

reviewer 运行独立周期别名/CGRect字典/稀疏标志 probe，未重复全量测试。真实ScreenCaptureKit多视口、自动B01/B03、退出清理、浮层与gate并发实测在review时均NOT_RUN；由主实现者继续集中实测，不把静态结论冒充设备证据。

初版构建曾误把文档SHA标为clean，已保留失败记录。S0旧截图仅是提交前工作树观察；最终产品要单独以准确SHA与二进制hash绑定。

## 交付证据独立复核

2026-11-02，reviewer再次核对保存证据和产品身份（未独立重演GUI）：

- 以独立Python标准库PNG解码器对实际723×868、732×1241、732×1211与不可变oracle重新比较，RGBA逐字节零差异；不是仅复用实现者比较器的结果。
- 产品Sources/Resources/Package相对303c331无变化；App内源码标记、二进制/zip hash与STATUS一致。
- 原始条带清理1目录/2510256 bytes→0；本机20/20；连接器确认CI 41326467704所有测试/构建/签名步骤成功。
- 复核结论：未发现必须阻塞手动交付的新问题，可以标READY_FOR_OWNER_DEVICE_GATE手动候选，必须保留F06未通过、非完整V1、非OWNER_VERIFIED。内置字体oracle失败没有被冒充通过。
