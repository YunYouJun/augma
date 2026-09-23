# 快速开始

Augma 将《刀剑神域：序列之争》中 AR 界面的轻盈感转化为可复用的 Web 组件。使用独立的设计基础，或直接开始构建 Vue 界面。

## Vue 组件

需要 Vue 3.5 或更新版本。

```sh
pnpm add augma
```

在应用入口导入样式：

```ts
import 'augma/style.css'
```

在组件中具名导入：

```vue
<script setup lang="ts">
import { AgmButton, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="连接设备">
    <AgmButton>开始连接</AgmButton>
  </AgmPanel>
</template>
```

不需要全局注册，也不需要配置 UnoCSS 或 Tailwind。组件包包含 TypeScript 声明。Vue 组件负责行为，Reka UI 为复杂交互提供键盘和焦点支持。

## 只使用样式

```sh
pnpm add @augma/core
```

```ts
// 只引入语义变量，不改变全局元素样式。
import '@augma/core/tokens.css'
// 或者使用包含组件样式的完整入口。
import '@augma/core/style.css'
```

```html
<button class="agm-button agm-button--primary" type="button">连接设备</button>
```

CSS 包没有 Vue 运行时依赖。复杂组件的交互、语义、键盘和焦点管理需要原生元素或相应的行为组件。

## 可编辑源码

已初始化 shadcn-vue 的 Vue 项目可以从 [Registry](/ai/#组件-registry) 复制核心组件。复制后的代码由你的项目维护，样式继续引用 `@augma/core/style.css`。

## 主题

默认提供浅色主题。在根元素添加 `class="dark"` 或 `data-agm-theme="dark"` 可启用深色主题。弹层会挂载到 body，因此主题应设置在 `html` 或 `body`，不能只设置在局部容器上。

## 从 0.1 迁移

0.2 重构了公共 API：使用 `AgmButton` 等具名导入，样式入口为 `augma/style.css`。旧的 `app.use(augma)`、内部 workspace 导入和 UnoCSS preset 不再作为公开接口。

旧 Card 的布局需求可使用 Panel；Clock 和应用菜单属于组合示例。摄像头与 WebXR 留在 `/ar/` 演示应用中，组件安装不会加载这些依赖。
