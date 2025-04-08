# Augma

[![GitHub Pages](https://github.com/YunYouJun/augma/workflows/client/badge.svg)](https://augma.elpsy.cn/)
[![docs](https://github.com/YunYouJun/augma/workflows/docs/badge.svg)](https://docs.augma.elpsy.cn)

🎨 AR UI Framework (Work In Progress)

> Because many new features are used, you'd better use the latest version of Chrome Browser.

- Docs: <https://docs.augma.elpsy.cn>
- Client: <https://augma.elpsy.cn/>

## What is Augma?

Augma 是 [刀剑神域：序列之争](https://zh.wikipedia.org/zh-sg/%E5%88%80%E5%8A%8D%E7%A5%9E%E5%9F%9F%E5%8A%87%E5%A0%B4%E7%89%88%EF%BC%9A%E5%BA%8F%E5%88%97%E7%88%AD%E6%88%B0) 中虚构的 AR（增强现实）型情报终端。

> 「但凡人能想象到的事物，必定有人能将它实现。」——儒勒·凡尔纳

我们希望参考此构建一套专门针对 AR 场景的 UI 组件。

我想，实现它将会是一件非常有趣的事情。

除了对于动漫的热情，我也希望它在作为各类新技术的试验地同时也可以是一个真正可用的产物。

譬如：

- 针对 AR 场景 UI 风格组件
  - 但这并非意味着造轮子，部分通用的组件完全可以复用 [element-plus](https://github.com/element-plus/element-plus) 或 Vue 生态等现有的组件（如 popper/dialog/notification/select），而只自定义 UI。既避免了细节的重复处理，也能有着良好的体验。
  - 同时这也意味着 element-plus 等组件库完全可以在此之上对子组件进一步抽象，做到样式与逻辑完全分离。
- AR 场景下的 Composition API
  - [VueUse](https://github.com/vueuse/vueuse) 是使用 Vue3 Compositon API 构建的很方便的工具库，而 AR 场景下也有很多可以抽象的地方。譬如，全屏（适配桌面、移动端）的 Web Camera、[mediapipe](https://github.com/google/mediapipe) 的一些封装……
- Augma Client
  - 使用上述组件库与 Compositon API 构建的 AR 操作终端，可以做各种看起来很酷的事情！

那就开始吧？Link Start.

## Usage

```bash
# Please wait for it to be available
pnpm add augma
```

```ts
import augma from 'augma'
import { createApp } from 'vue'
import App from './App.vue'

import 'augma/style'

const app = createApp(App)

app.use(augma)
app.mount('#app')
```

## Dev

You need [Node.js](https://nodejs.org/en/).

```bash
# install dependencies
pnpm i
```

```bash
# client
pnpm dev
# docs
pnpm docs:dev
```

### WebXR

- [https://github.com/meta-quest/immersive-web-emulator/](https://github.com/meta-quest/immersive-web-emulator/)

More Info see [WebXR | Babylon.js](https://doc.babylonjs.com/features/featuresDeepDive/webXR/introToWebXR).

## Monorepo

- augma
  - [@augma/components](https://github.com/YunYouJun/augma/tree/main/packages/client): Augma UI Components
  - [@augma/hooks]: Augma Composition API
- [@augma/client](https://github.com/YunYouJun/augma/tree/main/packages/client): Use augma ui to build a AR client like Augma

## Todo

- [ ] button to hide ui

## Thanks

- [element-plus](https://github.com/element-plus/element-plus)
- [icones](https://icones.js.org/)
- [unocss](https://github.com/antfu/unocss)
- [vite](https://github.com/vitejs/vite)
- [vitepress](https://github.com/vuejs/vitepress)
- [vueuse](https://github.com/vueuse/vueuse)
