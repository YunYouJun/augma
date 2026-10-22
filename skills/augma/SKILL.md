---
name: augma
description: Build, integrate, theme, or review Augma AR-inspired interfaces using its design tokens, Vue components, and source Registry. Use when a task adopts Augma, mentions augma, @augma/core or Agm* components, or extends an existing Augma interface.
---

# Augma

Build light, legible interfaces inspired by the Augma device in Sword Art Online: Ordinal Scale. Start from the project's existing framework and interaction requirements.

## Choose the integration

- Vue 3.5+: `pnpm add augma`, import named `Agm*` components and `augma/style.css` once. `@augma/core` is installed with it.
- Check that `augma` resolved to 0.2 or later; 0.1.x is an incompatible legacy API, and pnpm skips versions published less than a day ago. From 0.2.2 there is no install script to approve. On pnpm 11+, 0.2.1 and earlier fail to install until the `vue-demi` install script (pulled in by Reka UI) is allowed: `pnpm approve-builds`, or `allowBuilds: { vue-demi: true }` in `pnpm-workspace.yaml`.
- Other frameworks or plain HTML: `pnpm add @augma/core` and import `tokens.css` (variables only) or `style.css` (every `.agm-*` class). Supply native or headless behavior separately.
- Editable Vue source: every component has a Registry entry, `pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/<slug>.json`; the component reference gives each command. Import `@augma/core/style.css` once and keep the declared behavior dependencies.

## Get the API right

Read [the component reference](references/components.md) before writing code. It is generated from the component source for each release and lists every import, prop, default, `v-model`, event and slot, with a working example per component. Start a screen from [the recipes](references/recipes.md) when one fits.

Online, the same contract is at https://augma.yyj.moe/llms.txt and the versioned https://augma.yyj.moe/components.json. In the Augma repository itself, `scripts/catalog.mjs`, `examples/` and `packages/augma/src/components/` are the source of truth. When working from a local preview, replace the public origin with the preview origin. Never invent components or props; if the contract lacks something, say so.

## Design and implementation

Read [the design reference](references/design.md) when composing or restyling a screen. Keep the host product's brand and information hierarchy. Augma's defining choices are translucent surfaces, fine borders, restrained orange emphasis, circular state displays and deliberate whitespace. Theme through namespaced `--agm-*` variables.

Keep behavior and presentation separate. Preserve accessible labels, native form semantics, focus restoration and controlled state. Use `v-model` for Input, Select, Switch and Slider; use `v-model:open` for Dialog and Toast. Dialog requires both title and description, and its trigger slot should contain one focusable element. Built-in copy defaults to Simplified Chinese; for other languages pass Select `placeholder`, Dialog and Toast `closeLabel`, Toast `regionLabel` and HudProgress `indeterminateText`. Set dark mode on html/body so teleported content inherits it.

Motion is part of the look: overlays materialize from a lit line, buttons sweep, icon buttons show orbit arcs, statuses ping and gauges leave a trail. Tune it with `--agm-duration`, `--agm-duration-slow`, `--agm-ease`, `--agm-ease-in` and `--agm-ease-spring`, and the light with `--agm-light`, `--agm-sheen` and `--agm-glow`. Add `.agm-materialize` to any element for the window entrance and stagger it with `--agm-delay`. For a "Link Start" entry moment, `linkStart(navigate, options)` (from `augma` or the framework-free `@augma/core/link-start`) plays a light tunnel, runs the navigation once the screen is covered and fades out over the new page; it is a function, not a component, and belongs on a few entry points only (https://augma.yyj.moe/en/components/link-start). Everything stops under `prefers-reduced-motion`; never add motion that ignores it.

Copy working examples instead of approximating APIs. Component consumers should not require UnoCSS or Tailwind setup. Babylon and camera code belong to the optional AR app, not to general UI components.

## Verify

Build and typecheck the consumer project. Exercise its main keyboard and pointer flows, narrow-screen layout and reduced-motion state. When reviewing an Augma change, report concrete API, interaction or design inconsistencies relevant to the requested scope. Keep deployment and publication within the user's authorization.
