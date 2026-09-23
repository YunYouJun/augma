# 包与站点组织建议

状态：建议，尚未迁移。根据 2026-09-22 对话补充；与设备模拟器的功能开发分开处理。

## 推荐边界

当前实际工作区为 `apps/site`、`apps/ar`、`packages/core` 与 `packages/augma`。旧的 components / hooks / utils 等包已经由上一轮重构移除。对于以 Vue 为主的当前产品，建议进一步收敛为一个公开的 `augma` 包。

```text
docs/                        # 首页、组件文档、设计规范、组合展示、AI 接入
  .vitepress/
  components/
  guide/
  showcase/
  public/                    # 生成的 Registry 和 llms 索引
packages/
  augma/
    src/
      components/            # AgmButton、AgmPanel 等公共组件
      composables/           # 仅有真实公共用途的 Vue 逻辑
      styles/                # tokens.css、基础与组件样式
      index.ts               # 明确的公开导出
apps/
  ar/                        # 可独立构建的设备模拟器，部署到 /ar/
examples/
  components/                # 预览、源码展示、测试共用的 SFC
  compositions/
scripts/                     # 生成、构建、包消费与 Registry 验证
tests/
skills/augma/
```

包内分目录即可，组件、hooks、types、utils、metadata 不需要各自成为 workspace。演示的场景数据、导航、合成音频、摄像头和 Babylon 保留在 AR 应用；验证出跨项目复用需求后再考虑公开组件或 composable。

`docs/` 是完整官网，并非第二个文档站；首页与展示用全宽布局，API 文档用阅读布局。当前 `docs/plans` 等维护资料迁到 `internal/`，避免混入公开导航与文档生成。

## 使用方式

- Vue 使用者：`import { AgmButton } from 'augma'`。
- 样式入口：`import 'augma/style.css'`。
- 设计 tokens：`import 'augma/tokens.css'`。
- 后续按需组件出口只有在产物分析显示实际收益时再增加。

合并后 CSS 文件本身依旧不依赖 JS 执行，但安装 `augma` 仍涉及 Vue / Reka 的依赖关系，不再保证独立 CSS 包的最小安装图。如果未来需要非 Vue 使用者零框架安装、多个框架适配或独立版本周期，再提取 `@augma/core`；仅为了文件分类无需现在拆包。

## 迁移应一次完成的事项

1. 将 core 样式移入 augma，直接构建 style.css 与 tokens.css，移除跨包 CSS import。
2. 同步 exports、types、workspace、依赖、锁文件和发布流程；删除 core 专属构建和发布步骤。
3. 将 apps/site 移到 docs，更新编辑链接、VitePress alias、CI、预览与静态产物拼装路径。
4. 同步 Registry 的样式依赖、安装文档、Skill、机器可读索引与包消费验证。
5. 重新通过类型检查、完整构建、SSR / CSS 消费、Registry 安装和三浏览器验证。

设备演示当前功能不依赖这个迁移；不应为目录调整改变其 /ar/ 公共路径。
