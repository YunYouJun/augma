# 从 0.1 迁移

0.2 是一次允许不兼容调整的重构。升级前先检查项目对旧组件、内部路径和样式 preset 的依赖。

| 旧用法 / 功能 | 0.2 用法 |
| --- | --- |
| `app.use(augma)` | `import { AgmButton } from 'augma'` 等具名导入 |
| 旧 SCSS / UnoCSS preset | `import 'augma/style.css'` |
| workspace 内部组件路径 | `augma` 的公开出口，或 Registry 复制到自己的项目 |
| Card | AgmPanel，按内容组合插槽 |
| Clock / Menu / BottomMenu | 由基础组件组合；[查看展示](/showcase/) |
| Button / Input / Select 等旧 Props | 查阅新的组件 API，不能直接保证兼容 |
| 摄像头与 Babylon 混入组件包 | 独立的 [AR 演示](/guide/ar) |
| TensorFlow / 目标检测实验 | 首版移除，没有作为稳定能力发布 |

框架无关样式使用 `@augma/core`。Vue 包需要 Vue 3.5+，复杂行为由 Reka UI 提供。首版没有提供全局组件注册插件或 React 包。

文档和展示统一于 `augma.yunyoujun.cn`，并在 `augma.yyj.moe` 的 Cloudflare Pages 部署提供相同内容。旧域名的迁移状态取决于实际托管切换，不能通过升级 npm 包自动完成。
