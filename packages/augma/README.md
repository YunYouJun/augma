# Augma

AR UI Framework

Docs: <https://docs.augma.elpsy.cn>

## Usage

```sh
yarn add augma
```

```ts
import { createApp } from "vue";
import App from "./App.vue";

import augma from "augma";
import "augma/dist/style.css";

const app = createApp(App);

app.use(augma);
app.mount("#app");
```
