# 组件库设计完善记录

日期：2026-10-02。基于现有 12 个组件、Core 样式和 VitePress 主站，完成重构计划 P1–P3 中的状态展示与交互细节。本轮保留现有包结构、组件导出和 AR 独立入口。

## 已完成

- [x] 组件目录展示组件外观；名称、用途搜索与分类可叠加，展示结果数，并提供空结果恢复入口。预览不进入键盘焦点顺序，组件链接支持键盘访问。
- [x] 设计规范用同一组公共组件展示浅色、深色主题；示例状态独立，补充双主题颜色表、状态与反馈规范及浮层主题边界。
- [x] Core 支持显式的 `data-agm-theme="light"`，可在深色页面内恢复浅色内联组件。
- [x] Input 新增 `hint`；Select 新增 `id`、`hint`、`error`、`required`。字段保留辅助说明，错误自动关联到交互元素，外部描述 ID 可叠加。Select 的 class / style 仍作用于容器。
- [x] Panel 新增 `description` 和 `footer`，单独使用 actions 也能渲染标题栏；操作区支持换行。
- [x] Toast 新增 success / warning / danger / neutral 四种 tone，默认仍为 success；示例同时说明结果与下一步。
- [x] 开关、滑块扩展触控区域，浮层关闭按钮使用 44px 尺寸；不确定环形进度有旋转反馈并尊重减少动态效果偏好。
- [x] 示例支持重置；Input、Select、Panel、Toast、HudProgress 示例覆盖新增能力。API、Registry、机器可读文档继续由正式源码和 catalog 生成。

## 组件职责

- ComponentCatalog 管理搜索与分类，筛选结果通过 computed 派生；CatalogPreview 只根据 name 展示不可交互的外观缩略图。
- ThemeComparison 组合两个 ThemeSample；每个 ThemeSample 通过 theme / label 接收展示主题，独立管理亮度和显示状态。
- DemoPreview 管理示例加载、源码复制和重新挂载重置，不读取示例内部状态。
- 公共组件负责属性、插槽和语义，Core 负责视觉规则；新增属性均为可选。

## 验证

ESLint、vue-tsc、完整构建、38 项单元测试、Chromium / Firefox / WebKit 共 72 项浏览器测试通过。npm tarball 的 SSR / 类型 / 样式消费通过，6 个 Registry 条目通过实际 shadcn-vue CLI 安装、构建和渲染验证。人工检查桌面和 390px 窄屏布局。

覆盖了分类与搜索组合、无结果恢复、选择器键盘跳过禁用项与错误恢复、面板操作反馈、通知状态切换、示例重置、局部主题隔离及减少动画。原有 AR 和语音指令浏览器回归也通过。

## 后续独立事项

[包与站点组织建议](./package-organization.md) 仍为待评估的迁移方案；公网发布、域名和实机 AR 验收继续按 [发布说明](../release.md) 跟进。在线属性编辑器、更多 Registry 条目和框架适配仍属于后续候选范围。
