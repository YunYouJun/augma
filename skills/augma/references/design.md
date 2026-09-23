# Design reference

Use white/ice surfaces, graphite text and restrained orange actions. Default tokens include `--agm-bg`, `--agm-surface`, `--agm-panel`, `--agm-text`, `--agm-muted`, `--agm-accent`, `--agm-on-accent`, `--agm-cyan`, `--agm-success`, `--agm-danger`, and `--agm-border`.

Translucency should not compromise text contrast over live camera content. Keep reading surfaces opaque enough. Circular controls and HUD progress communicate action or state; avoid filling screens with decorative telemetry. Use text alongside status colors. When the host has its own typography, override `--agm-font` rather than adding another font requirement.

Build a control surface from Panel, labelled Input/Select/Switch/Slider, and Button. Use HudStatus for textual state and HudProgress for a measurable process. A value omitted from HudProgress means an indeterminate process, not zero. Respect reduced motion and keep visible focus outlines outside clipped button geometry.

Use a root `dark` class or `data-agm-theme="dark"` for the dark palette. A local-only theme boundary does not automatically cover Dialog, Tooltip, Select or Toast portals.
