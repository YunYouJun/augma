# 更新记录

## 0.2.0（待发布）

0.2 是不兼容重构。升级前请阅读 [0.1 → 0.2 迁移指南](apps/site/guide/migration.md)。

### 组件与设计

- 提供 12 个 Vue 3.5+ 组件：Button、IconButton、Input、Select、Switch、Slider、Dialog、Tooltip、Toast、Panel、HudStatus、HudProgress。
- 使用具名 `Agm*` 导出与 `augma/style.css`；独立 `@augma/core` 提供无框架依赖的 CSS 与语义 tokens。
- 提供浅色、深色及局部浅色主题；保留透明面板、细线边框、切角按钮与环形状态的 Augma 视觉语言。
- Input / Select 支持辅助说明与错误关联；Select 提供必选校验；Panel 提供说明与底部操作插槽；Toast 提供四种语义状态。
- 完善键盘与焦点管理、禁用和加载状态、触控命中区域，以及减少动态效果偏好。

### 文档与接入

- 统一中文文档站、组合展示、带外观预览的可筛选组件目录和可交互明暗主题样例。
- 可运行示例、源码复制、重置、API 文档、机器可读索引与 6 个 Registry 条目共用正式源码。
- 提供可安装的 Augma Agent Skill，以及 npm 包、SSR、独立 CSS 和 Registry 消费验证。

### 演示与工具

- AR 模拟器独立部署到 `/ar/`，摄像头与 WebXR 按需启用，不进入组件库依赖。
- 提供 macOS 桌面与语音控制实验演示；实机摄像头 / immersive-ar 支持范围仍需单独验收。
- CI 同时覆盖 `dev` 和 `main`。发布流程默认只准备产物，正式发布校验版本标签、提交与 tarball 摘要。

### 不兼容变更

- 移除 `app.use(augma)`、旧 SCSS / UnoCSS preset 及内部 workspace 导入方式。
- Card 改用 Panel；Clock / Menu / BottomMenu 作为应用组合处理。
- 旧组件 Props 不保证兼容；移除未稳定的 TensorFlow / 目标检测实验。
