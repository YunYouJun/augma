# 更新记录

## 0.2.2（2026-10-21）

### 修复

- 升级 Reka UI 至 2.11.0。它使用的 Floating UI 2 不再依赖 `vue-demi`，pnpm 11 及以上安装 augma 时无需批准任何安装脚本；0.2.1 及更早版本仍需允许 `vue-demi` 的安装脚本。
- augma 对 Reka UI 的依赖改为 `^2.11.0`，便于与项目自身的 Reka UI 或 shadcn-vue 去重；Registry 条目声明同一范围，由 `pnpm generate` 从 augma 的 `package.json` 读取。

### 文档与接入

- 快速开始、npm README 与 Skill 更新 pnpm 安装说明：0.2.2 起不再需要批准 `vue-demi`，0.2.1 及更早版本仍需批准。
- Registry 覆盖全部 13 个组件：新增 IconButton、Select、Switch、Slider、Tooltip、Toast 的 `/r/*.json` 条目，各语言组件页与 Skill 速查附上复制源码命令，AI 接入页、快速开始、npm README 与 Skill 同步说明。
- Registry 校验为每个组件传入各自所需的 Props 与插槽，并在消费项目中检查 Select、Switch、Slider、Tooltip 与 Toast 的交互。

### 演示与工具

- 语音指令接入 DeepSeek 助手：本地规则无法识别的说法和问题，会连同最近四轮对话交给 DeepSeek（`deepseek-flash`）。助手用一两句话作答并以系统语音朗读，也可以从演示已有的 15 项操作中选择一项执行，结果由设备播报，不采信模型的说法。
- 网页 AR 演示可在「设置 → DeepSeek 助手」中填写自己的 API Key，密钥只保存在当前浏览器，请求从浏览器直接发往 DeepSeek；Chrome、Edge 与 Safari 可用浏览器语音识别录音，首次录音时才请求麦克风权限，其他浏览器可输入文字。
- 网页 AR 演示新增「场景背景」，默认开启：未开启摄像头时，以动画风格绘制空中庭院或城市漫游，并叠加 AR 图层，代替纯灰背景：晴空积云与浮空岛、黄昏楼群与铁塔，深色视界下为星空和霓虹夜景；地面铺开六边形 AR 网格并扩散光环，数据碎片升起，城市有扫描线掠过，阳光带镜头光晕。远景、中景、前景按景深虚化，随「空间」中的场景切换以 AR 闪光淡入。开启景深动画后，背景按远近分层视差，浮窗展开时对焦到 HUD。可在「设置 → 视界效果」中关闭，恢复原站的纯灰背景；摄像头、空间 AR 与 macOS 沉浸模式不显示场景背景。
- 场景背景在面板或对话框打开时暂停动画；浏览器渲染跟不上（约每秒 20 帧以下，例如没有 GPU 加速的 Safari / WebKit）时保持静止，对焦与切换场景即时完成，与减少动态效果时一致。
- macOS 客户端的「使用 DeepSeek 理解未匹配的指令」改为 DeepSeek 助手。提示词与回答格式改由网页统一维护，原生端只校验对话消息、固定模型与上限并附上钥匙串中的密钥，密钥仍不交给网页。
- AR 演示新增键盘快捷键：焦点不在输入框时，用单键打开各应用、切换 HUD / 深色视界 / 镜像 / 全屏、开始或结束语音指令，按 `?` 查看全部快捷键；Esc 在焦点离开面板后也能关闭当前面板。默认均为单键，不占用浏览器、系统和其他应用带 ⌘ / Ctrl / Alt 的组合键。按键可自定义并保存在当前浏览器：录入时拒绝浏览器、系统、输入法与页面操作占用的按键，提示与微信 / QQ 截图、Alfred / Raycast、VoiceOver 等常见全局快捷键的潜在冲突，按键被占用时再按一次即可改用。单键快捷键可在设置中整体关闭；应用图标的提示与 `aria-keyshortcuts` 显示当前按键。
- macOS 客户端「开始或结束语音指令」的菜单快捷键由 `⇧⌘V` 改为 `⌥⌘V`：`⇧⌘V` 是 Paste、Pastebot 等剪贴板工具的全局快捷键，按下后 Augma 收不到。可在「系统设置 → 键盘 → 键盘快捷键 → App 快捷键」中按菜单标题改成其他按键，内置网页的快捷键列表和指令面板显示菜单当前的按键。

## 0.2.1（2026-10-20）

### 修复

- HudProgress 环形进度的数值不再换行，修复 100% 时折成两行。

### 文档与接入

- Agent Skill 新增组件速查 `references/components.md` 与组合示例 `references/recipes.md`：由 `pnpm generate` 从组件源码与示例生成，覆盖全部组件的导入、Props、默认值、事件、插槽与完整示例，以及控制面板、HUD 状态和主题定制三个完整页面。速查随 Skill 安装，离线可用；CI 与发布流程检查它与源码一致。
- 在全新 Vite + Vue + TypeScript 项目中验证接入：速查里的 16 段示例均通过 `vue-tsc` 与 `vite build`。
- 快速开始、npm README 与 Skill 说明 pnpm 11 及以上需允许 `vue-demi` 的安装脚本，否则安装失败；移除过时的“0.2 发布准备中”提示。
- 重写 `augma` 与 `@augma/core` 的 npm README；AI 接入页更新为 7 个 Registry 条目（含 HudGauge）并说明 Skill 内容。

## 0.2.0（2026-10-20）

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
- 可运行示例、源码复制、重置、API 文档、机器可读索引与 7 个 Registry 条目共用正式源码。
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
