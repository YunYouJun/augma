# Augma visual direction

Confirmed reference: the Augma AR device UI in Sword Art Online: Ordinal Scale. Official context: https://sao-movie.net/sp/story/augma.html. We translate its translucent surfaces, lightweight information hierarchy, circular controls and orange emphasis into original web components.

The working concepts are generated previews, not shipped raster interfaces. Homepage concept: `exec-f56472fd-6e80-408c-a64b-780bb38dab9d.png`; documentation concept: `exec-ef75b1fc-cf1f-4ffb-bcf0-ce345878b722.png` in the task's generated-images directory.

Palette: white #ffffff, ice #f3f6f8, graphite #263442, slate #5c7187, orange #b75e08, cyan #258ca4. Exo 2 carries geometric Latin headings; system Chinese sans keeps reading legible. Dark mode uses navy surfaces and lighter semantic colors. Layout uses a 1248px aligned content width, a two-column hero, open three-column component examples, and a compact AI command band. Mobile stacks these in reading order. Controls use 44px touch targets, clipped button corners and fine borders. Motion responds to actions; reduced-motion overrides are built in.

Component ownership: HomePage composes DevicePreview, ComponentStrip and AiBand. DevicePreview owns local demo settings and dialog state, reusing the public Vue components. DemoPreview loads a named source example and displays its exact source. VitePress owns documentation navigation and search. AR App composes camera and XR features whose composables own resource lifetimes.

AR simulator correction (2026-09-22): the earlier dashboard layout was rejected. The user explicitly requested the original https://augma.elpsy.cn/ style. The AR surface now follows [the original-site fidelity contract](./ar-original-site-fidelity.md): gray empty viewport, white clock and rules, colored filled MDI circles, opt-in floating applications. AR-specific tokens override the documentation palette only in the AR build; the documentation layout remains independent.

DeviceSimulator composes the view and passes typed props/events to ArHud (session controls), WorldScene (selectable anchors and map), SpacePanel (scan and scene controls), NavigationPanel (destination and route steps), SoundPanel (playback), NotificationPanel (session notices), SettingsPanel (two-way display models) and CameraControls (browser capabilities). useSimulator owns the device state machine and timers; display, audio, camera and XR composables own persistence or browser resources. App.vue remains a composition entry.

Copy contract: Augma; 界面，浮现于现实。; 为 Web 构建轻盈的 AR 风格界面。; 浏览组件; 体验 AR; 从一个按钮，到一整个视界; 操作 / 控制 / 信息; AI 也能读懂的设计系统; AI 接入指南. Device controls: 设备连接 / 界面预览 / 已连接 / 调整界面. Documentation uses component names, actual API and real examples.

Intentional refinements to generated concepts: omit invented English decorative labels, illustrative hardware and fictitious location/weather. Label simulated device content as a preview; show real local state, not an implied live device connection. Documentation icons are code-native outline SVGs; the AR view uses the original filled Material Design Icons with their Apache-2.0 license. Ring progress is an accessible SVG data visualization. No movie imagery is required by the shipped interface.
