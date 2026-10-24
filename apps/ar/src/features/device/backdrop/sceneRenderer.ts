import { Engine } from '@babylonjs/core/Engines/engine'
import { Scene } from '@babylonjs/core/scene'

export type SceneRendererState = 'loading' | 'webgl' | 'fallback'

export interface SceneryWorld {
  update: (elapsedSeconds: number, depthX: number, depthY: number) => void
}

export type SceneryWorldFactory = (scene: Scene) => SceneryWorld

/** One GPU owner per mounted scene. Models have no timers or browser event handlers. */
export function createSceneRenderer(canvas: HTMLCanvasElement, onState: (state: SceneRendererState) => void, createWorld: SceneryWorldFactory) {
  const contextOptions = {
    alpha: false,
    stencil: false,
    depth: true,
    antialias: true,
    premultipliedAlpha: true,
    preserveDrawingBuffer: false,
    powerPreference: 'low-power' as const,
  }
  // Babylon registers the engine before requesting its context. Probe first so unsupported GPUs
  // never leave a half-constructed engine and detached canvas in its global instance registry.
  const context = canvas.getContext('webgl2', contextOptions) ?? canvas.getContext('webgl', contextOptions)
  if (!context)
    throw new Error('WebGL is unavailable')
  const engine = new Engine(canvas, true, contextOptions)
  engine.maxFPS = 30
  const scene = new Scene(engine)
  let world: SceneryWorld
  try {
    world = createWorld(scene)
  }
  catch (error) {
    scene.dispose()
    engine.dispose()
    throw error
  }

  let disposed = false
  let ready = false
  let contextLost = false
  let paused = true
  let elapsed = 0
  let lastTime = 0
  let targetX = 0
  let targetY = 0
  let depthX = 0
  let depthY = 0

  function draw() {
    world.update(elapsed, depthX, depthY)
    scene.render()
  }

  function frame() {
    if (disposed || contextLost || paused)
      return
    const now = performance.now()
    const delta = lastTime ? Math.min((now - lastTime) / 1000, 0.1) : 0
    lastTime = now
    elapsed += delta
    const easing = 1 - Math.exp(-delta * 4)
    depthX += (targetX - depthX) * easing
    depthY += (targetY - depthY) * easing
    draw()
  }

  function sync() {
    engine.stopRenderLoop(frame)
    lastTime = 0
    if (ready && !paused && !disposed && !contextLost)
      engine.runRenderLoop(frame)
  }

  function resize() {
    if (disposed || contextLost)
      return
    // Cap both Retina scaling and total pixels: this is ambient scenery behind application controls.
    const pixels = Math.max(1, canvas.clientWidth * canvas.clientHeight)
    const ratio = Math.min(window.devicePixelRatio || 1, 1.5, Math.sqrt(1_600_000 / pixels))
    engine.setHardwareScalingLevel(1 / ratio)
    engine.resize()
    if (ready)
      draw()
  }

  function prepare() {
    scene.executeWhenReady(() => {
      if (disposed || contextLost)
        return
      ready = true
      resize()
      onState('webgl')
      sync()
    })
  }

  engine.onContextLostObservable.add(() => {
    contextLost = true
    ready = false
    sync()
    onState('fallback')
  })
  engine.onContextRestoredObservable.add(() => {
    contextLost = false
    prepare()
  })
  resize()
  prepare()

  return {
    resize,
    setPaused(value: boolean) {
      paused = value
      sync()
    },
    setDepth(x: number, y: number) {
      targetX = x
      targetY = y
    },
    dispose() {
      disposed = true
      engine.stopRenderLoop(frame)
      scene.dispose()
      engine.dispose()
    },
  }
}

export type SceneRenderer = ReturnType<typeof createSceneRenderer>

export type SceneRendererFactory = (canvas: HTMLCanvasElement, onState: (state: SceneRendererState) => void) => SceneRenderer
