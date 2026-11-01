# 本机构建与集中验收

最低 macOS 15，Swift 6；首轮 Apple Silicon。本机不依赖第三方包。当前真实证据/阻塞状态只看 [STATUS](STATUS.md)。

## 构建和启动

```sh
bash Scripts/build-app.sh
open build/ScrollCapture.app
swift test --disable-sandbox
```

脚本比较构建前后源码清单及 HEAD；App 内 `Contents/Resources/source-sha.txt` 和 `source-files.sha256` 记录准确来源。`working_tree_dirty=yes` 不能当成该 SHA 的干净产品验收。源码有变化须重建；仅证据文档变更可复用源码清单一致的产品证据。

稳定 Bundle ID：`com.yocruzer.ScrollCapture`。默认 ad-hoc 签名仅供本机，未公证、未商店发行。可在具有合法签名身份的本机设置 `SCROLLCAPTURE_SIGN_IDENTITY`；不会自动选择账号或修改证书信任。ad-hoc 重建后系统可能要求重新授权，旧二进制的 TCC 不是新二进制验收。

## 一次集中权限操作

在系统设置 → 隐私与安全性中，为本次 `build/ScrollCapture.app` 开启“屏幕与系统音频录制”，退出再打开。仅自动模式需要“辅助功能”/事件发送权限，点击 HUD“有界自动”时按需请求；手动不依赖它。若条目失效，使用系统设置删除旧 ScrollCapture 条目后重新添加同一路径的本次 App。不要授权测试命令行宿主来替代 App。

## 非敏感验收顺序

1. 点击“受控原生验收”：生产 SCStream 采集原生 NSScrollView 的 5 次120点变化，对照独立完整 NSView 渲染和宿主实际坐标；预期5接缝、首尾尺寸与每通道误差≤2。PNG/报告仅写 gitignored `artifacts/native-*`。这是 L2/L3 受控程序驱动，不能冒充 Owner 手动验收。
2. 点“合成测试窗口”，刷新后选择该窗口→获取画面→拖选正文（排除标题栏/滚动条）→开始手动。用鼠标缓慢滚动至少3次；HUD不能抢焦点或进入图像。暂停后滚回再继续；过快丢重叠必须暂停。完成后检查首尾、合法重复行、100%预览、裁剪、PNG、复制、Finder。
3. Safari 打开 `Fixtures/browser.html`（本地合成页面），先保存独立 canvas 真值 PNG；同样框选正文，做至少3接缝手动采集并保存。用独立 `Scripts/compare-images.swift` 按已知 canvas 起点/范围逐像素核对。禁止用生产位移或生产 crop 生成 expected。
4. 对原生合成窗口、Safari 分别重新开始手动采集，验证3个接缝后点击“有界自动”；3秒内把鼠标放到正文，保持目标前台。确认至少3个额外接缝；点击/按键/滚轮接管、切换窗口、移出鼠标、关闭目标、resize 应立即停回手动。无进展提示“未确认尾部”，不能报成功到底。B01+B03都通过才标F06完成。
5. 保存长图：8MP以内单PNG/整图复制，超过8MP保存新目录中的有序PNG+manifest；复制超预算明确拒绝。错误路径/取消导出后结果可重试，不覆盖未知文件。对照独立真值核对分片接边。
6. 最后 Owner 用非敏感 Chrome/Safari/飞书/微信内容实测；未安装不更改账号环境，标 NOT_TESTED。

独立像素比较：

```sh
swift Scripts/compare-images.swift actual.png oracle.png x y width height
```

## 明确边界

- 初版只验证垂直整数像素平移。候选仅基于图像，滚轮请求不参与位置估计；全可见重叠查歧义，每行/每像素验证，再写条带/提交覆盖。
- 完全重复整屏、跨无重叠跳跃、超过可见视口的周期、分数像素重采样无法可靠判别；不宣称全局唯一。可见歧义、动态内容、固定栏干扰会暂停，需回滚或保存标明局部的可信前缀。
- 不修复任意横向移动/缩放/布局变化；重新框选开始新会话。动态长图不是同一瞬间快照。用户结束不等于文档到底。
- 8MP单帧、128MP会话、4096条带、10分钟、32次恢复；自动80步/120秒/3秒无进展。未验证Retina/多显示器/Intel时不得宣传已支持其验收。
- 本地原始帧、私聊、窗口标题、账号、个人路径不得提交公开仓库或CI。公开夹具只有合成代码；临时条带权限0700，正常取消/对象释放清理；进程崩溃后的遗留目录需单独人工检查，不扫描删除未知目录。
