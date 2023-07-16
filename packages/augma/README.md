# Augma

![npm bundle size](https://img.shields.io/bundlephobia/minzip/augma)

AR UI Framework

Docs: <https://docs.augma.elpsy.cn>

## Usage

```bash
pnpm add augma
```

```ts
import { createApp } from 'vue'
import augma from 'augma'
import App from './App.vue'

import 'augma/style'

const app = createApp(App)

app.use(augma)
app.mount('#app')
```
