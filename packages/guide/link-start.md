# Link Start

## 在 Vue 中引入

```js
import { createApp } from "vue";
import App from "./App.vue";

import augma from "augma";

const app = createApp(App);

app.use(augma);
app.mount("#app");
```

## 使用未发布的开发版本

```bash
git clone https://github.com/YunYouJun/augma
cd augma
yarn
cd packages/augma
yarn link
```

前往你的项目，输入 `yarn link augma`。
