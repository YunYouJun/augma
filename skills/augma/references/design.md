# Design reference

Use white/ice surfaces, graphite text and restrained orange actions. Default tokens live in `packages/core/src/tokens.json` (synced to CSS and Swift) and include `--agm-bg`, `--agm-surface`, `--agm-panel`, `--agm-glass-bg`, `--agm-glass-strong`, `--agm-glass-border`, `--agm-glass-blur`, `--agm-text`, `--agm-muted`, `--agm-accent`, `--agm-on-accent`, `--agm-cyan`, `--agm-success`, `--agm-danger`, `--agm-on-danger`, and `--agm-border`.

Translucency should not compromise text contrast over live camera content. Keep reading surfaces opaque enough, and respect `prefers-reduced-transparency: reduce` and `forced-colors: active` fallbacks. Circular controls and HUD progress communicate action or state; avoid filling screens with decorative telemetry. Use text alongside status colors. When the host has its own typography, override `--agm-font` rather than adding another font requirement.

Build a control surface from Panel, labelled Input/Select/Switch/Slider, and Button (`variant`: `primary` | `outline` | `ghost` | `glass` | `danger`; `size`: `sm` | `md` | `lg`). Use `glass` for floating capsule actions over imagery or scenes and `danger` for destructive actions. Use HudStatus for textual state, HudProgress for a measurable process and HudGauge for a remaining quantity such as battery or signal. A value omitted from HudProgress means an indeterminate process, not zero. Respect reduced motion and keep visible focus outlines outside clipped button geometry.

On Apple platforms (`AugmaUI`, iOS 26 / macOS 26), separate content actions from floating Liquid Glass controls: use `.augmaButton(.floating)` / `.augmaButton(.floatingProminent)` (`.glass` / `.glassProminent`) inside `GlassEffectContainer` or `AugmaGlassActionBar` for floating overlays, `.augmaButton(.primary)` / `.augmaButton(.secondary)` (`.borderedProminent` / `.bordered`) inside scrolling cards and forms, and never nest Liquid Glass buttons inside another `.augmaGlass` surface.

Use a root `dark` class or `data-agm-theme="dark"` for the dark palette. A local-only theme boundary does not automatically cover Dialog, Select, Tooltip or Toast portals.
