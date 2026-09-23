# AI 接入

让编程助手使用真实组件、明确的 API 和一致的设计规范。首版面向开发时的集成与界面构建。

## 安装 Skill

```sh
npx skills add YunYouJun/augma --skill augma
```

仓库中的 Skill 适用于支持 Agent Skills 的编程助手，例如 Codex 和 Claude。以下提示可以直接使用：

```text
使用 $augma 为当前 Vue 项目创建一个设备控制面板。
使用公开组件和语义 tokens，保留现有品牌与可访问行为。
先查阅组件 API，再实现状态切换和交互示例。
```

新版本的 Skill 和 Registry 需要随本仓库发布后才能通过公开 URL 获取；本地开发可直接加载 `skills/augma/SKILL.md`，并使用本地预览的资源地址。

## 机器可读入口

- [llms.txt](/llms.txt)：精简文档索引。
- [llms-full.txt](/llms-full.txt)：完整 Markdown 文档集合。
- [components.json](/components.json)：包含版本、导入、API、示例与 Registry 地址的组件契约。
- <a href="/markdown/guide/index.md" download>纯文本指南</a>：方便编程助手直接读取。

所有入口由同一套源码、示例与元数据生成。`components.json` 使用 `schemaVersion: 1`，消费者应检查版本。

## 组件 Registry

在已初始化 shadcn-vue 的 Vue 项目中执行：

```sh
pnpm dlx shadcn-vue@2.8.2 add https://augma.yunyoujun.cn/r/button.json
pnpm dlx shadcn-vue@2.8.2 add https://augma.yunyoujun.cn/r/dialog.json
```

首批支持 Button、Input、Panel、Dialog、HudStatus、HudProgress。Registry 复制与 npm 组件相同的源文件，同时声明样式与行为依赖。

在应用入口导入：

```ts
import '@augma/core/style.css'
```

复制后的 Vue 文件可以自由修改。Registry 自身不要求 Tailwind 来渲染 Augma 样式；CLI 对宿主项目的初始化要求遵循 shadcn-vue。

## 验收一个 AI 生成的界面

检查实际导入和 Props 是否存在，执行类型检查和构建，使用键盘走完主流程，并检查窄屏与减少动画设置。可用以下任务检查编程助手：

1. 创建带有 Select、Switch、Slider 的控制面板。
2. 创建同时展示正常、等待、错误状态的 HUD。
3. 通过 tokens 更改强调色，保留焦点和文字对比。

[展示页](/showcase/) 提供这三类任务的可运行参考，每个示例都可展开和复制源码。纯文本源文件：

- <a href="/markdown/compositions/control-panel.vue" download>控制面板</a>
- <a href="/markdown/compositions/hud.vue" download>HUD 状态</a>
- <a href="/markdown/compositions/theme.vue" download>主题定制</a>

Skill 提供设计与集成知识。站内聊天和实时生成 UI 属于后续独立功能。
