# Codex 工作约定

默认中文。产品范围以 Docs/PRODUCT_REQUIREMENTS.md 为准，执行顺序以 Docs/EXECUTION_PLAN.md 为准，当前状态以 Docs/STATUS.md 为准；研究材料不是额外门禁。

## 工作方式
- 一次 /goal 授权，按 S0–S4 连续推进；阶段完成即提交、普通推送、更新一个 Draft PR 并继续。
- 使用独立分支 codex/scroll-capture-v1；若已有同目标分支则续接。未知工作区改动必须保留，必要时使用 worktree；不得 stash/reset/clean 覆盖用户内容。
- 实现、定向测试、独立只读 review、必要修复在 Codex 内闭环。P0/P1 和阻断核心路径的 P2 修复，其余记录。
- 不自动合并 main、不强推、不删除未知分支、不打发布 tag、不发布商店。
- 首次权限、签名账户选择等外部步骤集中列出最少操作；不受阻工作继续推进。

## 正确性
- 滚轮请求量不等于真实位移；相似度高不等于位移唯一。
- 合法重复内容必须保留；无可靠匹配不得把整帧硬接到末尾。
- 失败帧不得推进已确认覆盖；缺口要暂停、回滚补采或明确形成局部结果。
- 固定栏的匹配 mask 不证明其遮挡正文已采集。
- 坐标、bitmap 尺寸、分数位移、绝对累计边界取整必须明确；防止逐帧误差累计。
- Vision confidence、单次最高分、连续静止帧不能单独证明正确或到底。
- Chrome 56053a0 是人工成功基线；490e0ce 是完整 CI 候选；都不是本 App 的验收证据。

## 验证与隐私
- 按 Docs/ACCEPTANCE.md 风险映射定向测试；只在共享核心变化或交付前风险明确时扩大回归。
- 记录精确 SHA、环境、命令、结果、限制；区分离线回放、受控窗口、真实 ScreenCaptureKit、真实应用人工验收。
- 不上传真实屏幕帧、私聊、窗口标题、账号、路径、签名证书或私有诊断到公开 Git/CI。
- 权限必须属于实际交付 App 的稳定 Bundle ID；测试宿主授权不能替代。
- 临时资源仅清理本 App 自有目录；异步任务绑定 session/attempt/geometry generation。

## 状态与交付
- STATUS.md 是唯一状态入口，DEVELOPMENT_LOG.md 追加阶段记录，DECISIONS.md 记录重大取舍。
- 核心真实采集/GUI/受控多视口证据缺失时保持 BLOCKED_ENVIRONMENT 或 AWAITING_PERMISSION；不能提前标 READY。
- 最终交付可运行 .app、构建方式、Draft PR、精确源码 SHA、测试/review、限制和集中人工验收步骤。