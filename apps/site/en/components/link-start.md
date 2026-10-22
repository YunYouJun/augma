# Link Start

A light-tunnel transition that covers the screen before a navigation and fades out over the page it arrives on.

About 240 streaks of light rush out from the centre while LINK START surfaces in the middle. After one second a flash covers the screen and settles on the destination page's background; once the page has changed, the overlay fades away. It is a framework-free function rather than a component: the overlay sits on `document.body`, so it is not unmounted by the route change.

## Basic usage

<DemoPreview name="link-start" />

## With a router

Put the navigation in the callback. `linkStart` runs it once the screen is covered and fades out when the new page is in place. With `waitFor`, it waits until nothing on the old page matches that selector before fading, so the old page never shows through.

```ts
import { linkStart } from 'augma'
import { useRouter } from 'vue-router'

const router = useRouter()

function enter() {
  return linkStart(() => router.push('/guide/'), { waitFor: '.home' })
}
```

To control the timing yourself, call it in steps: `playLinkStart` resolves when the screen is covered and returns the fade-out function.

```ts
import { playLinkStart } from 'augma'

const finish = await playLinkStart({ text: 'SYSTEM CALL' })
await router.push('/guide/')
await finish()
```

## API

### `linkStart(navigate, options?)`

Plays the tunnel, runs `navigate` once the screen is covered, then fades out over the new page. The returned promise resolves once the overlay is removed. If `navigate` throws, the overlay is still removed and the error is passed on. Calling it again while a transition is running returns the same promise, so the navigation does not run twice.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `text` | string | 'LINK START' | Text at the centre; an empty string shows none |
| `duration` | number | 1000 | Time until the screen is covered, in milliseconds |
| `colors` | string[] | The dark theme's `--agm-cyan`, `--agm-accent`, `--agm-highlight` and `--agm-text` | Streak colours, in any CSS colour format |
| `arrival` | string | The page's `--agm-bg` | Colour held before the fade; match the destination's background |
| `zIndex` | number | 1000 | Stacking order of the overlay |
| `waitFor` | string | undefined | Fade only once nothing matches this selector |
| `timeout` | number | 2000 | Longest wait for `waitFor`, in milliseconds |

### `playLinkStart(options?)`

Takes the options above except `waitFor` and `timeout`. Resolves when the screen is covered with `finish(): Promise<void>`, which fades the overlay out and removes it.

### `waitUntilGone(selector, timeout?)`

Resolves once nothing matches `selector`, or after `timeout` (2000 ms by default).

## Accessibility and usage notes

- With reduced motion turned on, the tunnel does not play and `navigate` runs at once; `playLinkStart` resolves straight away with a no-op.
- The canvas has `aria-hidden="true"`, ignores pointer events and never moves focus; the destination page handles focus and its title as usual.
- The overlay is removed after the fade. It is also removed at once if drawing fails or the browser has no Canvas 2D, so the navigation is never blocked. When a background tab pauses animation frames, it waits at most `duration` plus 500 ms.
- Colours come from the dark theme's tokens and the type from `--agm-font`, whether the page is light or dark. Override those variables on `[data-agm-theme='dark']`, or pass `colors`.
- Without `@augma/core/tokens.css` it falls back to the dark theme's defaults.
- Keep it for the few moments that enter a product, such as a "Link Start" call to action; do not add it to every link.

## Installation

```ts
import { linkStart, playLinkStart, waitUntilGone } from 'augma'
```

Without Vue, import it from `@augma/core`, which has no dependencies:

```ts
import { linkStart } from '@augma/core/link-start'
```
