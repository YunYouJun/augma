# Augma

AR UI Framework

Docs: <https://docs.augma.elpsy.cn>

## Usage

```bash
pnpm add augma
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
