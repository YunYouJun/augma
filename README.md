# Augma

[![GitHub Pages](https://github.com/YunYouJun/augma/workflows/client/badge.svg)](https://augma.elpsy.cn/)
[![docs](https://github.com/YunYouJun/augma/workflows/docs/badge.svg)](https://docs.augma.elpsy.cn)

<!-- [![GitHub Pages](https://github.com/SAO-UI/augma/workflows/docs/badge.svg)](https://sao-ui.github.io/augma/) -->

🎨 AR UI Framework

> Because many new features are used, you'd better use the latest version of Chrome Browser.

## Usage

```bash
yarn add augma
```

```ts
import { createApp } from "vue";
import App from "./App.vue";

import augma from "augma";
import "augma/style";

const app = createApp(App);

app.use(augma);
app.mount("#app");
```

## Dev

You need [Node.js](https://nodejs.org/en/).

```bash
# install dependencies
yarn
```

```bash
yarn dev
# localhost:3000
```

### Docs

```bash
yarn docs
```

## Todo

- [ ] button to hide ui

## Thanks

- [vite](https://github.com/vitejs/vite)
- [vitepress](https://github.com/vuejs/vitepress)
- [icones](https://icones.js.org/)
- [vueuse](https://github.com/vueuse/vueuse)

### UI Components

- [element-plus](https://github.com/element-plus/element-plus)

## Dependencies

Use `@tensorflow/tfjs@1` for `tfjs-yolo` & `face-api.js`.
