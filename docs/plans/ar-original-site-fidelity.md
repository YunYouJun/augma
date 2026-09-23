# AR demo: restore the original Augma visual language

User correction: follow https://augma.elpsy.cn/ rather than the new dashboard layout. This reference supersedes the AR simulator styling described in design-direction.md.

Reference inspected in the in-app browser on 2026-09-22 at 724 × 656: default view, weather widget, system menu and map toggle. Original implementations were read from HEAD under packages/client and packages/components.

## Visual contract

- Default viewport is an unobstructed gray view (#666 plus 10% white = #757575), or a camera feed explicitly enabled by the user. No illustration, radial gradient or synthetic architecture.
- Top controls: 32px outer offsets; white circular microphone and more-menu controls; centered white Courier clock at 20.8px; a 2px white horizontal rule below the clock. The menu expands vertically.
- Bottom: a full-width white rule with centered downward triangle, and nine separate white circles with colored filled Material Design Icons. No pill container, persistent text labels or orange selection treatment. Labels appear on hover / focus and remain accessible to screen readers.
- Icon colors retain the original mint #8dd3d6, amber #ed933d, blue #4dade0, navy #004d86 and teal #00959c. Microphone green #98d447. Compact original weather widget uses #d1ac6a.
- Default visible copy is the local clock only. No brand header, sidebar, status card, explanatory footer or initial module window.
- Applications open / close as floating overlays. Generic controls use small white / translucent surfaces, 3px corners and quiet shadows; no orange cut-corner buttons in the AR surface.
- Weather matches the original 400px transparent widget with a white weather glyph and an amber city / temperature strip. Its data is explicitly labelled as an example once opened.
- Navigation opens the map as an actual spatial overlay; the route list is a separate translucent layer. Maps are demo data. Mobile preserves the viewport shell and scrolls inside app windows, never turns the AR view into a long webpage.

## Component boundaries

DeviceSimulator wires browser capabilities and application state. SystemBar owns the clock and top-menu presentation (typed props and action events). DeviceDock owns the original nine-button application rail. DeviceWindow provides a labelled closable floating surface with constrained scrolling. Feature panels keep the already-implemented scan, route, playback, notifications, settings and camera behavior. useSimulator owns active application state and permits null for an empty view.

## Intentional functional updates

The original face-detection button was not functional; the same navy slot opens sound playback. GitHub and documentation buttons are real links. Notifications and device lifecycle actions are in the system menu. The microphone opens explicitly simulated voice commands, without requesting microphone permission. Camera is opt-in. Keyboard labels, visible focus and scrollable mobile windows are retained.

## Verification ledger

Compare original and implementation at 724 × 656, plus desktop and 390px mobile: background color, clock position/type, top rule, circle sizes and spacing, filled icon style/colors, empty default view, weather composition, and lack of page scrolling. Functional regression checks cover open/close, scan, navigation, settings, playback, camera denial and standby cleanup. Exact capture paths and outcomes are recorded after verification.

Verified on 2026-09-22:

- Compared original and local screenshots at 724 × 656: gray background, centered Courier clock, top rule, 39px bottom circles at 55px intervals, filled icon palette, and empty default view. The small navy slot intentionally uses a music icon for the working audio app.
- Compared weather widgets directly: 400px width, top position at 100px, white 48px weather glyph, amber strip, outlined city selector and 40px temperature. The implementation adds a close control and an explicit example-data note.
- Inspected 1280px desktop and 390 × 844 mobile layouts. App windows scroll internally, the dock stays available, and mobile anchors sit above the active spatial tool.
- ESLint, Vue type checking, the production build and 16 unit tests passed. All 42 Playwright checks passed in Chromium, Firefox and WebKit. Browser coverage includes empty view, weather selection/toggle, Escape and focus restoration, scan/pin, route completion, notices, settings persistence/reset, audio, standby cleanup, mobile anchors/HUD and denied camera permission.
- Screenshot evidence is saved under `/Users/yunyou/.codex/visualizations/2026/09/22/01a0c7e3-d97f-75a2-8c67-05df5b83c4d0/`: `augma-original-reference.png`, `augma-restored-default.png`, `augma-restored-weather.png`, `augma-mobile-navigation.png`.
- Physical camera and immersive XR still require device testing; the browser tests exercise permission rejection and resource cleanup with mocks.
