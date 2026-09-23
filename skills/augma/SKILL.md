---
name: augma
description: Build, integrate, theme, or review Augma AR-inspired interfaces using its design tokens, Vue components, and source Registry. Use when a task explicitly adopts Augma or extends an existing Augma interface.
---

# Augma

Build light, legible interfaces inspired by the Augma device in Sword Art Online: Ordinal Scale. Start from the project's existing framework and interaction requirements.

## Choose the integration

- Vue 3.5+: install `augma`, import named `Agm*` components and `augma/style.css`.
- Custom or other-framework components: install `@augma/core` and use `tokens.css`; `style.css` adds the CSS primitives. Supply appropriate native/headless behavior separately.
- Editable Vue source: use the Registry entries listed in the component contract. Import `@augma/core/style.css` once and keep the declared behavior dependencies.

Read the relevant component API before writing code. Canonical documentation is https://augma.yunyoujun.cn/llms.txt; the versioned contract is https://augma.yunyoujun.cn/components.json. In this repository, use `scripts/catalog.mjs`, `examples/components/`, and `packages/augma/src/components/` as the source of truth. When working from a local preview, replace the public origin with the preview origin. Do not invent components or props when remote documentation is unavailable; use local sources or identify the missing contract.

## Design and implementation

Read [the design reference](references/design.md) when composing or restyling a screen. Keep the host product's brand and information hierarchy. Augma's defining choices are translucent surfaces, fine borders, restrained orange emphasis, circular state displays and deliberate whitespace. Use namespaced `--agm-*` variables for theming.

Keep behavior and presentation separate. Preserve accessible labels, native form semantics, focus restoration and controlled state. Use `v-model` for Input, Select, Switch and Slider; use `v-model:open` for Dialog and Toast. Dialog requires both title and description, and its trigger slot should contain one focusable element. Set dark mode on html/body so teleported content inherits it.

Copy working examples instead of approximating APIs. Component consumers should not require UnoCSS or Tailwind setup. Babylon and camera code belong to the optional AR app, not to general UI components.

## Verify

Build and typecheck the consumer project. Exercise its main keyboard and pointer flows, narrow-screen layout and reduced-motion state. When reviewing an Augma change, report concrete API, interaction or design inconsistencies relevant to the requested scope. Keep deployment and publication within the user's authorization.
