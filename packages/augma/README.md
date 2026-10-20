# augma

> Interfaces that surface in reality.

Light, AR-style Vue 3.5+ components inspired by the Augma device in *Sword Art Online: Ordinal Scale*: translucent panels, fine borders, ring gauges and a restrained orange accent. An original UI experiment, not affiliated with the rights holders.

[![Augma home page: a translucent device panel over HUD rings](https://augma.yyj.moe/og.jpg)](https://augma.yyj.moe)

[Website](https://augma.yyj.moe/en/) · [Components](https://augma.yyj.moe/en/components/) · [AR demo](https://augma.yyj.moe/ar/) · [macOS app](https://augma.yyj.moe/en/download) · [中文](https://augma.yyj.moe/) · [日本語](https://augma.yyj.moe/ja/)

## Install

```sh
pnpm add augma
```

Vue 3.5 or newer is a peer dependency. Styles come from [`@augma/core`](https://www.npmjs.com/package/@augma/core), installed with it.

From 0.2.2, augma no longer depends on `vue-demi`, so pnpm 11 or later installs it without approving any install script. 0.2.1 and earlier pull in `vue-demi` through Reka UI, and pnpm fails the install until its install script is allowed: run `pnpm approve-builds`, or set `allowBuilds: { vue-demi: true }` in `pnpm-workspace.yaml`.

## Use

Import the components you need and the stylesheet once. There is no plugin to register.

```vue
<script setup lang="ts">
import { AgmButton, AgmHudGauge, AgmPanel } from 'augma'
import { shallowRef } from 'vue'
import 'augma/style.css'

const battery = shallowRef(86)
</script>

<template>
  <AgmPanel title="Device" description="Linked and ready.">
    <AgmHudGauge label="Battery" :value="battery" />
    <template #footer>
      <AgmButton @click="battery = Math.max(0, battery - 18)">
        Drain
      </AgmButton>
    </template>
  </AgmPanel>
</template>
```

Add the `dark` class (or `data-agm-theme="dark"`) to the document root for the dark palette, and override `--agm-*` variables to theme it. Complex interactions are built on [Reka UI](https://reka-ui.com) with native semantics, keyboard support and visible focus; every animation respects `prefers-reduced-motion`.

## Components

| Group | Components |
| --- | --- |
| Basics | [Button](https://augma.yyj.moe/en/components/button), [IconButton](https://augma.yyj.moe/en/components/icon-button), [Input](https://augma.yyj.moe/en/components/input) |
| Controls | [Select](https://augma.yyj.moe/en/components/select), [Switch](https://augma.yyj.moe/en/components/switch), [Slider](https://augma.yyj.moe/en/components/slider) |
| Feedback | [Dialog](https://augma.yyj.moe/en/components/dialog), [Tooltip](https://augma.yyj.moe/en/components/tooltip), [Toast](https://augma.yyj.moe/en/components/toast) |
| HUD | [Panel](https://augma.yyj.moe/en/components/panel), [HudStatus](https://augma.yyj.moe/en/components/hud-status), [HudProgress](https://augma.yyj.moe/en/components/hud-progress), [HudGauge](https://augma.yyj.moe/en/components/hud-gauge) |

Every page has a live example, its Vue source and the full API.

## Copy the source instead

Every component is also available as editable source through a [shadcn-vue](https://www.shadcn-vue.com) Registry; each component page lists its command:

```sh
pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/button.json
```

## For AI coding tools

```sh
npx skills add YunYouJun/augma --skill augma
```

The site also serves [`llms.txt`](https://augma.yyj.moe/llms.txt) and a machine-readable [`components.json`](https://augma.yyj.moe/components.json).

## Upgrading from 0.1

0.2 is a rewrite and does not keep the 0.1 API. See the [migration guide](https://augma.yyj.moe/en/guide/migration) and the [changelog](https://github.com/YunYouJun/augma/blob/main/CHANGELOG.md).

## License

MIT © [YunYouJun](https://github.com/YunYouJun)
