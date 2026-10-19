# Design system

Inspired by Augma in *Sword Art Online the Movie: Ordinal Scale*: information shown clearly, lightly and with restraint, on top of the real world. This page distills that direction into an original interface language for the web.

## One interface, two kinds of light

Light suits bright surroundings; dark avoids large bright surfaces. Both sides use the same public components and semantic variables. Adjust the brightness or hide the HUD on either side independently, then restore the defaults.

<ThemeComparison />

Use `.dark` or `data-agm-theme="dark"` on the page root to turn on dark; a nested `data-agm-theme="light"` brings light back. Dialog, Select, Tooltip and Toast overlays mount on body, so set the app theme on html or body; the scoped theme samples contain only inline components.

## Surfaces and hierarchy

White and ice gray form the main surfaces. Transparency and hairline borders build depth, cut corners are reserved for actionable entry points, and rings are for status and progress. Reading areas stay quiet; panels on busy backgrounds need a solid enough background to keep text contrast.

## Color

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--agm-bg` | `#ffffff` | `#131e29` | Page background |
| `--agm-surface` | `#f3f6f8` | `#1b2936` | Secondary surface |
| `--agm-text` | `#263442` | `#edf4fa` | Primary text |
| `--agm-muted` | `#5c7187` | `#a0b6c9` | Supporting text |
| `--agm-accent` | `#b75e08` | `#f1a74c` | Primary actions and alerts |
| `--agm-highlight` | `#f28c12` | `#f28c12` | Decorative highlights, HUD graphics and gauge warnings |
| `--agm-cyan` | `#258ca4` | `#67c8da` | Continuous controls |
| `--agm-success` | `#287947` | `#7cdaa0` | Success |
| `--agm-danger` | `#bc394a` | `#ff95a4` | Errors |

Override the variables at your app root to customize the theme. When you change the accent color, check the text contrast of `--agm-on-accent` too. A status must always include text, never color alone.

## Type

The site uses the geometric letterforms of Exo 2, with Chinese and Japanese text falling back to the system sans-serif. Components take the host font through `--agm-font`; the CSS package requests no external fonts. Body text and controls keep readable sizes, and the numerals suit live status.

## States and feedback

| State | Expression | Guidance |
| --- | --- | --- |
| Default / focus | Hairline border / outer focus ring | Keyboard focus must never be clipped by cut corners or containers |
| Disabled | Lower contrast, no interaction | Explain why nearby; do not make a Tooltip the only explanation |
| Input error | Error border and specific error text | Use `error` to say how to fix it, and `hint` to keep the input requirements |
| Busy | Button `loading`, or indeterminate progress | Block repeat submissions; for unknown progress leave out `value` instead of passing a fake percentage |
| Action feedback | Toast `tone` with result text | success / warning / danger / neutral map to success, warning, failure and messages |
| Empty results | Say that nothing matches the current filters | Offer to clear the filters or a next step |

Error and helper text are linked to their fields through `aria-describedby`. Keep the user's input during validation and clear the error once it is fixed; a failed async submission must not be signaled by notification color alone.

## Interaction and motion

Buttons and overlay close controls provide a touch height of at least 44px; small switches and sliders keep their light look by extending the hit area. Leave room in layouts so neighboring hit areas don't overlap. Focus rings stay whole and are never clipped by cut corners. Motion explains state changes and respects `prefers-reduced-motion`.

Motion follows the way Augma interfaces "surface" over reality: appear quickly, settle softly, and leave faster.

| Motion | Used on | Expresses |
| --- | --- | --- |
| Materialize | Dialog; any element with `.agm-materialize` | A bright line appears first, then unfolds vertically; closing folds back the same way |
| Sheen | Button hover, Dialog opening | A sweep of light crosses the surface, only on enter |
| Orbit | IconButton hover and focus | Two arcs circle the target; when `pressed` it fills with the accent color, like a selected round menu button |
| Sonar | HudStatus | The status dot ripples outward; danger is more urgent, neutral stays still |
| Afterimage | HudGauge | When the value drops, a pale afterimage retracts a moment later, so the loss is easy to see |
| Countdown | Toast | A thin line at the bottom shows the time left, and pauses while the notification region is hovered or focused |

`--agm-duration` (160ms) is for color and presses, `--agm-duration-slow` (420ms) for unfolding and movement; `--agm-ease` handles entering, `--agm-ease-in` leaving, and `--agm-ease-spring` is only for physical springs such as the switch thumb. `--agm-light`, `--agm-sheen` and `--agm-glow` control the glass top edge, the sheen and the accent glow. `.agm-materialize` can be sequenced with `--agm-delay`; no clipping remains after the animation ends, so shadows and accent lines stay intact.

With reduced motion on, materialize, sheen, orbit, sonar and countdown all stop, and content appears in its final state; the afterimage follows the value immediately.

## Composition

Panel groups information with a title, description, content and footer; actions hold secondary header actions, and the footer carries the group's primary action. On narrow screens the action area wraps naturally. HudStatus describes the current state, HudProgress a process, and HudGauge remaining capacity such as battery or signal. Settle the information hierarchy first, then pick visual elements. Docs pages and working interfaces don't need to reuse the homepage's decorative orbits.

## Source

The design direction draws on the [official Augma device introduction](https://sao-movie.net/sp/story/augma.html). This is an independent interface experiment with no affiliation to the rights holders.
