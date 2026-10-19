# 更新记录

## 0.2.0（待发布）

0.2 是不兼容重构。升级前请阅读 [0.1 → 0.2 迁移指南](apps/site/guide/migration.md)。

### 组件与设计

- 提供 13 个 Vue 3.5+ 组件：Button、IconButton、Input、Select、Switch、Slider、Dialog、Tooltip、Toast、Panel、HudStatus、HudProgress、HudGauge。
- 使用具名 `Agm*` 导出与 `augma/style.css`；独立 `@augma/core` 提供无框架依赖的 CSS 与语义 tokens。
- 提供浅色、深色及局部浅色主题；保留透明面板、细线边框、切角按钮与环形状态的 Augma 视觉语言。
- Input / Select 支持辅助说明与错误关联；Select 提供必选校验；Panel 提供说明与底部操作插槽；Toast 提供四种语义状态。
- 完善键盘与焦点管理、禁用和加载状态、触控命中区域，以及减少动态效果偏好。
- 新增 HudGauge 分段计量条：按剩余比例切换青 / 橙 / 红，数值下降时留下短暂余影。
- 统一 Augma 动效语言：Dialog 与 `.agm-materialize` 先现亮线再展开，按钮光扫，IconButton 环绕弧线与选中填充，HudStatus 声呐，Toast 倒计时线；新增动效与光线 tokens，全部遵循减少动态效果偏好。

### 文档与接入

- 统一中文文档站、组合展示、带外观预览的可筛选组件目录和可交互明暗主题样例。
- 可运行示例、源码复制、重置、API 文档、机器可读索引与 6 个 Registry 条目共用正式源码。
- 提供可安装的 Augma Agent Skill，以及 npm 包、SSR、独立 CSS 和 Registry 消费验证。
- 文档站新增 English（`/en/`）与日本語（`/ja/`）：主页、指南、展示、设计、AI 接入与组件 API 均有译文，切换语言时停留在对应页面；从文档进入 AR 演示时沿用当前语言。组件交互示例与可复制的源码同样提供译文。
- 站内 AR 入口改为整页跳转，不再经客户端路由打开 404。

### 演示与工具

- AR 模拟器独立部署到 `/ar/`，摄像头与 WebXR 按需启用，不进入组件库依赖。
- 提供 macOS 桌面与语音控制实验演示；实机摄像头 / immersive-ar 支持范围仍需单独验收。
- AR 模拟器与 macOS 客户端支持简体中文、English、日本語：按浏览器 / 系统语言自动选择，可在设置中切换并记住；语音指令可识别三种语言的说法，执行结果可用当前语言朗读（Web Speech API，可在设置中关闭）。
- macOS 客户端可从 GitHub Release 下载：通用（Apple 芯片 / Intel）安装包随 `v*` 标签发布，站点新增下载与首次打开说明。
- 主页加入 HUD 轨道环、雷达扫描、六边形场域扫描与滚动浮现；macOS 演示的 HUD、沉浸控制条与侧栏采用同一视觉语言，进入沉浸模式时播放一次性开场。
- CI 覆盖 `main` 的推送与所有 PR。`pnpm release`（bumpp）更新版本并推送 `v*` 标签，标签触发 npm Trusted Publishing（OIDC）发布；发布前校验标签、提交与 tarball 摘要，并跳过 registry 上已存在且一致的版本。手动运行工作流默认只准备产物。

### 不兼容变更

- 移除 `app.use(augma)`、旧 SCSS / UnoCSS preset 及内部 workspace 导入方式。
- Card 改用 Panel；Clock / Menu / BottomMenu 作为应用组合处理。
- 旧组件 Props 不保证兼容；移除未稳定的 TensorFlow / 目标检测实验。
