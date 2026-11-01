# 滚动截图竞品与开源研究

本文件为公开资料/固定源码审阅，不是跨产品实测报告；不以未经验证的下载量或成功率排名。

## 竞品
- 飞书：官方桌面文档支持区域框选、自动/手动滚动；提醒避开滚动条、动画、视频和过快滚动。未公开当前算法，不能断言其使用特定特征匹配。
- 微信 Mac：Mac App Store 版本历史明确列出滚动截图能力；内部算法、逆滚语义、所有窗口兼容性未证实，需实机记录渠道和版本。
- Shottr：官方说明 macOS 滚动 API + 计算机视觉匹配重叠；自动/手动/向上捕获；动画、固定元素和部分 Terminal/VS Code 自动模式有限。
- CleanShot X：Auto-Scroll、横向滚动和 URL Scheme，可用于可重复区域实验；内部匹配算法未公开。
- Xnip：手动滚动、实时预览；文档列出滚快、动画、横移、悬浮区等失败因素。
- PixPin：可见匹配位置、末尾补采和裁剪交互值得研究；重复内容/纯色可能导致匹配困难。
- Snagit：自动/手动多路径，自动失败可退回手动；视差页面仍是边界。
- Picsew：iOS/iPadOS 录屏帧序列转长图参考，不是 macOS 原生跨应用工具。

闭源厂商资料只能证明公开能力/限制，不能反推算法。专利也不能证明当前产品采用了专利方案。

## 开源
- ScrollSnap 3.2.0，固定 commit 09982391fc9b7e96e02dd366d590471e4bf95476，MIT：ScreenCaptureKit、Vision 平移候选、像素重叠复核、多区域确认、逆滚保留范围；仍有累计图像重绘成本。
- Lenscap 固定 commit b4782cdb849b5f6af076521a896da4786321319a，MIT：CGEvent 滚动、64 列灰度重叠；无匹配时零重叠追加是危险捷径，不继承。
- ShareX 固定 commit 5668552d390bcb62e7ae02851453ae0e8622a7f6，GPL-3.0：逐行比较、部分成功状态、静态/动画/hover 限制可学；不直接复制 GPL 源码。

## 快速实验
先做唯一行号、重复行/气泡、纯色、周期表格、固定栏/遮挡、动态加载、快滚丢重叠、逆滚恢复、resize、末尾低信息。用同一帧序列对比 Vision 与简单多条带/相关算法，真值不能泄漏给算法。记录漏行/重行、唯一性、暂停原因、耗时、峰值内存、导出完整性。手动和自动分别测试；手动成功自动失败先查驱动，二者离线帧都失败再查匹配。

## 一手来源
- 飞书：https://www.feishu.cn/hc/zh-CN/articles/145659580677-%E5%BD%95%E5%B1%8F%E5%92%8C%E6%BB%9A%E5%8A%A8%E6%88%AA%E5%9B%BE
- 微信 Mac：https://apps.apple.com/cn/app/%E5%BE%AE%E4%BF%A1/id836500024?mt=12
- Shottr：https://shottr.cc/kb/scrollingcapture/
- CleanShot：https://cleanshot.com/changelog ; https://cleanshot.com/docs-api
- Xnip：https://xnipapp.com/scrolling-capture/
- PixPin：https://pixpin.cn/docs/capture/long-capture
- Snagit：https://www.techsmith.com/snagit/features/screenshot-website/
- Picsew：https://docs.picsew.app/
- ScrollSnap：https://github.com/Brkgng/ScrollSnap/tree/09982391fc9b7e96e02dd366d590471e4bf95476
- Lenscap：https://github.com/rutmehta/Lenscap/tree/b4782cdb849b5f6af076521a896da4786321319a
- ShareX：https://github.com/ShareX/ShareX/tree/5668552d390bcb62e7ae02851453ae0e8622a7f6
- Apple ScreenCaptureKit：https://developer.apple.com/documentation/screencapturekit
- Apple Vision registration：https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest
- Apple CGEvent：https://developer.apple.com/documentation/coregraphics/cgevent
