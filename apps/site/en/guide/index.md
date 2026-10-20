# Quick start

Augma turns the lightness of the AR interfaces in *Sword Art Online the Movie: Ordinal Scale* into reusable web components. Use the standalone design foundation, or start building Vue interfaces right away.

## Vue components

Requires Vue 3.5 or later.

```sh
pnpm add augma
```

::: tip pnpm 11 or later
pnpm fails the install on install scripts nobody approved. From 0.2.2, augma no longer depends on `vue-demi`, so there is nothing to approve. 0.2.1 and earlier pull in `vue-demi`, which has an install script, through Reka UI and Floating UI; for those, run `pnpm approve-builds` to allow it, or add this to `pnpm-workspace.yaml`:

```yaml
allowBuilds:
  vue-demi: true
```

pnpm also skips versions published less than a day ago, so on release day you get the previous version. 0.1.x is an incompatible legacy API; make sure you have 0.2 or later.
:::

Import the styles in your app entry:

```ts
import 'augma/style.css'
```

Use named imports in your components:

```vue
<script setup lang="ts">
import { AgmButton, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="Connect device">
    <AgmButton>Connect</AgmButton>
  </AgmPanel>
</template>
```

No global registration, and no UnoCSS or Tailwind setup. The package ships TypeScript declarations. Vue components handle behavior, and Reka UI brings keyboard and focus support to complex interactions.

## Styles only

```sh
pnpm add @augma/core
```

```ts
// Semantic variables only; global element styles stay untouched.
import '@augma/core/tokens.css'
// Or the full entry, including component styles.
import '@augma/core/style.css'
```

```html
<button class="agm-button agm-button--primary" type="button">Connect device</button>
```

The CSS package has no Vue runtime dependency. Interaction, semantics, keyboard and focus management for complex components need native elements or matching behavior components.

## Editable source

Vue projects set up with shadcn-vue can copy the core components from the [Registry](/en/ai/#component-registry). The copied code is maintained by your project, and its styles keep using `@augma/core/style.css`.

## Themes

The light theme is the default. Add `class="dark"` or `data-agm-theme="dark"` to the root element for the dark theme. Overlays mount on body, so set the theme on `html` or `body`, not only on a local container.

## Migrating from 0.1

0.2 reworks the public API: use named imports such as `AgmButton`, and import styles from `augma/style.css`. The old `app.use(augma)`, internal workspace imports and the UnoCSS preset are no longer public interfaces.

Layouts that relied on the old Card can use Panel; Clock and the app menu are now composition examples. The camera and WebXR stay in the `/ar/` demo app, so installing the components never loads those dependencies.
