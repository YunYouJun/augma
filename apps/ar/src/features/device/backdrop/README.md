# Real-time scenery

This folder implements the browser scenery. The macOS Space tab uses independent RealityKit geometry; its floating garden is implemented in `apps/mac/Sources/AugmaDesktopDemo/Space/NativeFloatingGarden.swift` with the same low-poly art direction.

Both worlds use low-poly geometry, broad cel-like flat colors and atmospheric perspective. `SceneBackdrop.vue` selects the world, while the scene components mount their canvas. CSS gradients provide a lightweight background during loading or when WebGL is unavailable, without image assets.

`useSceneRenderer.ts` owns lazy loading, motion preferences and Vue/browser cleanup; `sceneRenderer.ts` owns the shared Babylon engine lifecycle, resize, render loop and WebGL context recovery. Each mounted world samples its own motion budget after its GPU resources are ready.

Rendering is capped at 30 fps, 1.5× pixel density and 1.6 million pixels. Web panels, hidden tabs, reduced motion and the low-frame-rate budget pause rendering. Pointer camera parallax follows the existing depth-motion setting. Switching worlds releases the previous engine, geometry and materials. Native side controls leave ambient movement running.

## Garden

`garden/gardenWorld.ts` builds the garden as real 3D geometry: an ivory terrace and grass in the foreground, small floating islands and clouds in the middle distance, and a broad tiered floating fortress with a hanging rock base and slender towers. A limited stone/green/sky-blue palette, faceted shapes and distant haze provide the visual style without texture maps, bloom or post-processing. Clouds drift and small islands gently bob; the camera adds subtle perspective changes when depth motion is enabled.

## City

`city/cityWorld.ts` builds the canal promenade, faceted buildings, trees, elevated railway and three-car train using Babylon.js. Geometry uses a small flat-color palette and distance fog; there are no image planes, bloom or post-processing effects. The train moves along the same rail coordinates as the viaduct, and a few windows slowly vary in brightness.

`CityScene.vue` uses the shared lifecycle through its small `cityRenderer.ts` adapter; the city model and behavior are unchanged when switching between the two real-time worlds.
