# Migrating from 0.1

0.2 is a rewrite that allows breaking changes. Before upgrading, check how your project depends on old components, internal paths and the style preset.

| Old usage / feature | In 0.2 |
| --- | --- |
| `app.use(augma)` | Named imports such as `import { AgmButton } from 'augma'` |
| Old SCSS / UnoCSS preset | `import 'augma/style.css'` |
| Internal workspace component paths | The public `augma` exports, or copy into your project from the Registry |
| Card | AgmPanel, composing content through its slots |
| Clock / Menu / BottomMenu | Composed from the base components; [see the showcase](/en/showcase/) |
| Old props on Button / Input / Select and others | Check the new component APIs; compatibility is not guaranteed |
| Camera and Babylon mixed into the component package | The separate [AR demo](/en/guide/ar) |
| TensorFlow / object detection experiments | Removed in the first release; never shipped as a stable feature |

Framework-agnostic styles live in `@augma/core`. The Vue package needs Vue 3.5+, and Reka UI provides complex behavior. The first release has no global component registration plugin and no React package.

Docs and the showcase live at `augma.yunyoujun.cn`, and the Cloudflare Pages deployment at `augma.yyj.moe` serves the same content. Moving the old domain depends on the actual hosting switch; upgrading the npm package cannot do it for you.
