# @augma/core

> Interfaces that surface in reality.

Framework-free design tokens, CSS and effects for [Augma](https://augma.yyj.moe/en/), light AR-style interfaces inspired by the Augma device in *Sword Art Online: Ordinal Scale*. An original UI experiment, not affiliated with the rights holders.

Using Vue? Install [`augma`](https://www.npmjs.com/package/augma) instead: it ships the components and depends on this package.

[Website](https://augma.yyj.moe/en/) · [Design system](https://augma.yyj.moe/en/design/) · [Components](https://augma.yyj.moe/en/components/) · [中文](https://augma.yyj.moe/design/) · [日本語](https://augma.yyj.moe/ja/design/)

## Install

```sh
pnpm add @augma/core
```

It has no runtime dependencies and no global element reset.

## Use

Import either the variables only or the complete component styles:

```css
@import '@augma/core/tokens.css'; /* --agm-* variables */
@import '@augma/core/style.css'; /* tokens plus every .agm-* component class */
```

The classes work on plain HTML:

```html
<section class="agm-panel agm-materialize">
  <span class="agm-status" data-tone="success">
    <span class="agm-status-dot"></span>
    Linked
  </span>
  <button class="agm-button agm-button--primary" type="button">Link Start</button>
</section>
```

Interactive components such as Dialog, Select, Switch and Slider need behavior from your framework or a headless library. The Vue package shows the expected markup and attributes for each one.

## Link Start

`@augma/core/link-start` is a dependency-free ES module with a light-tunnel transition: it covers the screen, runs your navigation, then fades out over the page it arrives on. It skips straight to the navigation under `prefers-reduced-motion`.

```ts
import { linkStart } from '@augma/core/link-start'

link.addEventListener('click', (event) => {
  event.preventDefault()
  linkStart(() => router.push('/guide/'))
})
```

See [Link Start](https://augma.yyj.moe/en/components/link-start) for the options.

## Theming

- Dark mode: add the `dark` class or `data-agm-theme="dark"` to the document root. `data-agm-theme="light"` restores light inside a dark page.
- Colors, light and motion are namespaced variables such as `--agm-accent`, `--agm-panel`, `--agm-glow` and `--agm-ease`. Override them on the root to theme everything.
- `.agm-materialize` plays the window entrance (a lit line that unfolds); `--agm-delay` staggers it.
- All animations stop under `prefers-reduced-motion`.

See the [design system](https://augma.yyj.moe/en/design/) for the full token table and motion language.

## License

MIT © [YunYouJun](https://github.com/YunYouJun)
