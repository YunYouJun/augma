# Optional depth and curved HUD

Keep the restored Augma default unchanged. Add two independently persisted, initially disabled settings: depthMotion and curvedHud. Old saved preferences omit these keys and retain the disabled defaults.

- SettingsPanel exposes typed defineModel switches and a reduced-motion status message.
- useDisplaySettings validates, saves and resets both preferences with the existing schema.
- useDepthMotion owns pointer sampling, one scheduled animation frame at a time, motion/media/visibility listeners and teardown. It writes normalized CSS variables to the AR root; Vue application state is not updated on every pointer move.
- DeviceSimulator connects settings and runtime availability. Motion is suspended when HUD is hidden, the device is offline, immersive XR is prepared, the page is hidden or the OS requests reduced motion.
- SystemBar and DeviceDock take a curved boolean prop, rendering decorative SVG curves and a shallow curved icon arrangement without changing the controls or their tab order.
- DeviceWindow retains positioning/scroll/focus behavior. AR-only CSS adds small perspective, an entrance transition and restrained background defocus. Touch scrolling does not trigger parallax.

Verification: default visual remains unchanged; switches act independently; saved values hydrate and reset; pointer motion changes layer transforms only when enabled; reduced-motion changes stop pending work and keep the curved layout static; mobile remains scrollable and controls remain reachable. Use browser tests for computed styles and pointer behavior, unit tests for stored settings validation.

Verified: ESLint, vue-tsc, production build, 16 unit tests and all 48 Playwright checks passed (Chromium, Firefox, WebKit). New browser checks cover all four toggle combinations, persisted reload, reset, real pointer CSS movement, live reduced-motion changes, stopping after HUD hides, curved mobile navigation and viewport bounds. Inspected the effects at 1280 × 720 and 390 × 844. Screenshots: `augma-depth-curves.png` and `augma-depth-curves-mobile.png` under the task's local visualization directory.
