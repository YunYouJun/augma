import { onUnmounted, shallowRef } from 'vue'

export function useXr() {
  const supported = shallowRef(false)
  const ready = shallowRef(false)
  const active = shallowRef(false)
  const busy = shallowRef(false)
  const error = shallowRef('')
  let generation = 0
  let engine: import('@babylonjs/core').Engine | undefined
  let scene: import('@babylonjs/core').Scene | undefined
  let experience: import('@babylonjs/core').WebXRDefaultExperience | undefined
  async function detect() {
    try {
      supported.value = !!(await navigator.xr?.isSessionSupported('immersive-ar'))
    }
    catch {
      supported.value = false
    }
  }
  async function prepare(canvas: HTMLCanvasElement) {
    if (busy.value || ready.value)
      return
    const request = ++generation
    busy.value = true
    error.value = ''
    let pendingRuntime: ReturnType<typeof import('./xrRuntime').createXrScene> | undefined
    let pendingExperience: typeof experience
    try {
      const { createXrScene, createExperience } = await import('./xrRuntime')
      if (request !== generation)
        return
      pendingRuntime = createXrScene(canvas)
      pendingExperience = await createExperience(pendingRuntime.scene)
      if (request !== generation)
        return
      engine = pendingRuntime.engine
      scene = pendingRuntime.scene
      experience = pendingExperience
      pendingRuntime = undefined
      pendingExperience = undefined
      experience.baseExperience.onStateChangedObservable.add((state) => {
        if (request === generation)
          active.value = state === 2
      })
      engine.runRenderLoop(() => scene?.render())
      window.addEventListener('resize', resize)
      ready.value = true
    }
    catch {
      if (request === generation) {
        error.value = '空间 AR 初始化失败，可以继续使用摄像头演示。'
        cleanup()
      }
    }
    finally {
      pendingExperience?.dispose()
      pendingRuntime?.scene.dispose()
      pendingRuntime?.engine.dispose()
      if (request === generation)
        busy.value = false
    }
  }
  async function enter() {
    if (!experience || active.value || busy.value)
      return
    const current = experience
    const request = generation
    busy.value = true
    error.value = ''
    try {
      await current.baseExperience.enterXRAsync('immersive-ar', 'local-floor')
      if (request !== generation) {
        if (current.baseExperience.sessionManager.inXRSession)
          await current.baseExperience.exitXRAsync().catch(() => {})
        return
      }
      active.value = true
    }
    catch {
      if (request === generation)
        error.value = '未能进入空间 AR，请确认设备支持并允许会话。'
    }
    finally {
      if (request === generation)
        busy.value = false
    }
  }
  function resize() {
    engine?.resize()
  }
  function cleanup() {
    generation++
    window.removeEventListener('resize', resize)
    if (experience?.baseExperience.sessionManager.inXRSession)
      void experience.baseExperience.exitXRAsync().catch(() => {})
    experience?.dispose()
    scene?.dispose()
    engine?.dispose()
    experience = undefined
    scene = undefined
    engine = undefined
    ready.value = false
    active.value = false
    busy.value = false
  }
  onUnmounted(cleanup)
  return { supported, ready, active, busy, error, detect, prepare, enter, stop: cleanup }
}
