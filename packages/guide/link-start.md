# Link Start

Augma 是使用 Vite 开发并基于 Vue3 实现的实验性 AR UI 框架

- 尽可能地使用浏览器的新特性

> 仍在努力开发中...

[Client Demo](https://augma.elpsy.cn): 使用 Augma 实现的客户端示例

## 安装

[![npm](https://img.shields.io/npm/v/augma)](https://www.npmjs.com/package/augma)

```bash
pnpm add augma
```

## 在 Vue3 中引入

```js
import { createApp } from "vue";
import App from "./App.vue";

// 引入 Augma 组件
import augma from "augma";
// 引入 Augma 样式
import "augma/style";

const app = createApp(App);

app.use(augma);
app.mount("#app");
```

## 使用未发布的开发版本

```bash
git clone https://github.com/YunYouJun/augma
# install dependencies
cd augma
yarn
# link augma
cd packages/augma
yarn link
# link to your project
cd your-project # 进入你的项目
yarn link augma
```
