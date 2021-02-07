---
title: 图标
category: misc
---

## 图标

你可以使用各类扩展图标

[iconify](https://iconify.design/): Unified icons framework

- [浏览图标](https://icones.js.org/)

## 在 Vite 中使用

[vite-plugin-icons](https://github.com/antfu/vite-plugin-icons): Access thousands of icons as Vue components in Vite

```bash
yarn add -D vite-plugin-icons @iconify/json
```

```ts
import Vue from "@vitejs/plugin-vue";
import VueIcons from "vite-plugin-icons";

export default {
  plugins: [Vue(), VueIcons()],
};
```

你还可以自动按需加载图标

```html
<template>
  <i-carbon-accessibility />
  <i-mdi-account-box style="font-size: 2em; color: red" />
</template>
```

> [配置自动加载](https://github.com/antfu/vite-plugin-icons#auto-importing)
