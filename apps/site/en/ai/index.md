# AI integration

Help coding assistants work with real components, explicit APIs and a consistent design system. The first release targets integration and interface building during development.

## Install the Skill

```sh
npx skills add YunYouJun/augma --skill augma
```

The Skill in this repository works with coding assistants that support Agent Skills, such as Codex and Claude. You can use these prompts as they are:

```text
Use $augma to build a device control panel for this Vue project.
Use the public components and semantic tokens, and keep the existing brand and accessible behavior.
Read the component API first, then implement state changes and an interactive example.
```

New versions of the Skill and the Registry are available from public URLs only after this repository is released; for local development, load `skills/augma/SKILL.md` directly and use the resource URLs from your local preview.

## Machine-readable entry points

- [llms.txt](/llms.txt): a compact documentation index.
- [llms-full.txt](/llms-full.txt): the complete Markdown documentation, in Simplified Chinese.
- [components.json](/components.json): the component contract with version, imports, API, examples and Registry URLs; descriptions are in Simplified Chinese.
- <a href="/markdown/en/guide/index.md" download>Plain-text guide</a>: easy for coding assistants to read directly.

All entry points are generated from the same source, examples and metadata. `components.json` uses `schemaVersion: 1`; consumers should check the version.

## Component Registry

In a Vue project set up with shadcn-vue, run:

```sh
pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/button.json
pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/dialog.json
```

The first batch covers Button, Input, Panel, Dialog, HudStatus and HudProgress. The Registry copies the same source files as the npm components and declares their style and behavior dependencies.

Import in your app entry:

```ts
import '@augma/core/style.css'
```

The copied Vue files are yours to change. The Registry itself does not need Tailwind to render Augma styles; the CLI's setup requirements for the host project follow shadcn-vue.

## Reviewing an AI-generated interface

Check that the imports and props actually exist, run type checking and the build, walk through the main flow with a keyboard, and check narrow screens and the reduced motion setting. These tasks put a coding assistant to the test:

1. Build a control panel with Select, Switch and Slider.
2. Build a HUD that shows normal, waiting and error states at once.
3. Change the accent color through tokens while keeping focus rings and text contrast.

The [showcase](/en/showcase/) has runnable references for all three tasks, and every example's source can be expanded and copied. Plain-text source files:

- <a href="/markdown/compositions/control-panel.vue" download>Control panel</a>
- <a href="/markdown/compositions/hud.vue" download>HUD status</a>
- <a href="/markdown/compositions/theme.vue" download>Theme customization</a>

The Skill provides design and integration knowledge. On-site chat and live UI generation are separate, later features.
