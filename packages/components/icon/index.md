---
title: 图标
category: misc
---

## 图标

你可以使用各类扩展图标

[iconify](https://iconify.design/): Unified icons framework

- [浏览图标](https://icones.js.org/)

### 导入图标集

安装依赖

```bash
yarn add -D @iconify/iconify @iconify/json
```

#### 使用线上的图标 API

```ts
// import "https://code.iconify.design/2/2.0.0-rc.6/iconify.min.js";
import "@iconify/iconify";
```

#### Without API

本地绑定图标

##### 添加图标集

```ts
import Iconify from "@iconify/iconify/dist/iconify.without-api.min.js";
import mdiIcons from "@iconify/json/json/mdi.json";
// import carbonIcons from "@iconify/json/json/carbon.json";
Iconify.addCollection(mdiIcons);
// Iconify.addCollection(carbonIcons);
```

##### 自定义图标 Bundle

> [Simple icon bundle for SVG Framework](https://docs.iconify.design/sources/bundles/examples/svg-framework-simple.html)

### 使用

```vue
<template>
  <agm-icon icon="carbon:logo-github"></agm-icon>
</template>
```

| 参数  | 说明                                             | 类型   | 可选值 | 默认值 |
| ----- | ------------------------------------------------ | ------ | ------ | ------ |
| icon  | 图标名称（见 [icones](https://icones.js.org/) ） | string | -      | -      |
| color | 图标颜色                                         | string | -      | black  |
| size  | 图标大小                                         | string | -      | 1.5rem |

## 其它方式

其他一些使用图标的方式。

### 在 Vite 中使用

将其渲染为 SVG，并按需加载。

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
