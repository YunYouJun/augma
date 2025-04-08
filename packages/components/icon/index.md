---
title: 图标
category: misc
description: 图标使用及其解决方案
props:
  - name: icon
    type: string
    description: 图标名称（见 icones.js.org）
  - name: color
    type: string
    description: 图标颜色
    default: "black"
  - name: size
    type: string
    description: 图标大小
    default: "1.5rem"
---

你可以基于 [iconify](https://iconify.design/) 与 [unplugin-icons](https://github.com/antfu/unplugin-icons) 来快速使用各类扩展图标

- [iconify](https://iconify.design/): Unified icons framework
- [unplugin-icons](https://github.com/antfu/unplugin-icons): 🤹 Access thousands of icons as components on-demand universally.
- [浏览图标 ｜ icones.js.org](https://icones.js.org/): 在这里快速查看各类图标名称

## 推荐方式

### 在 Vite 中使用

使用 unplugin-icons 将其渲染为 SVG，并按需加载图标。

[unplugin-icons](https://github.com/antfu/unplugin-icons): 🤹 Access thousands of icons as components on-demand universally.

- 使用方式：参考 README
  - [配置自动加载 | unplugin-icons](https://github.com/antfu/unplugin-icons#auto-importing)
- 使用示例: [@augma/client](https://github.com/YunYouJun/augma/blob/6884551c5f288d49eb3a37ec510903b02e27253b/packages/client/vite.config.ts#L89)

> By the way, I like [remixicon](https://remixicon.com/).

## 关于 Iconify

- [Simple icon bundle for SVG Framework](https://docs.iconify.design/icon-components/bundles/examples/svg-framework-simple.html)

### 导入图标集

安装依赖

```bash
pnpm add -D @iconify/iconify @iconify/json
```

#### 使用线上的图标 API

```ts
// import "https://code.iconify.design/2/2.0.0-rc.6/iconify.min.js";
import '@iconify/iconify'
```

#### Without API

本地绑定图标

##### 添加图标集

```ts
import Iconify from '@iconify/iconify/dist/iconify.without-api.min.js'
import mdiIcons from '@iconify/json/json/mdi.json'

// import carbonIcons from "@iconify/json/json/carbon.json";
Iconify.addCollection(mdiIcons)
// Iconify.addCollection(carbonIcons);
```

##### 自定义图标 Bundle

- [Simple icon bundle for SVG Framework](https://docs.iconify.design/sources/bundles/examples/svg-framework-simple.html)
