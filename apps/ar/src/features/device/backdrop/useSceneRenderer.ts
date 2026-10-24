import type { Ref } from 'vue'
import type { SceneRenderer, SceneRendererFactory, SceneRendererState } from './sceneRenderer'
import { computed, onMounted, onUnmounted, readonly, shallowRef, watch } from 'vue'
import { useMotionBudget } from './useMotionBudget'

interface SceneMotion {
  paused?: boolean
  depthEnabled?: boolean
}

/** Vue owns mounting and motion preferences; Babylon owns the scene and its render loop. */
export function useSceneRenderer(canvas: Readonly<Ref<HTMLCanvasElement | null>>, motion: SceneMotion, loadRenderer: () => Promise<SceneRendererFactory>) {
  const state = shallowRef<SceneRendererState>('loading')
  const reducedMotion = shallowRef(false)
  // Each scene gets its own motion budget, sampled only once its GPU resources are ready.
  const still = useMotionBudget(computed(() => Boolean(motion.paused || reducedMotion.value || state.value !== 'webgl')))
  let renderer: SceneRenderer | undefined
  let disposed = false
  let media: MediaQueryList | undefined
  let resizeObserver: ResizeObserver | undefined
  let root: Element | null = null

  function sync() {
    reducedMotion.value = media?.matches ?? false
    renderer?.setPaused(Boolean(motion.paused || still.value || reducedMotion.value || document.hidden))
    if (!motion.depthEnabled || reducedMotion.value)
      resetDepth()
  }

  function resetDepth() {
    renderer?.setDepth(0, 0)
  }

  function move(event: Event) {
    const pointer = event as PointerEvent
    if (!motion.depthEnabled || motion.paused || still.value || reducedMotion.value || pointer.pointerType !== 'mouse' || pointer.buttons)
      return
    if (pointer.target instanceof Element && pointer.target.closest('button, a, input, select, [role="slider"], [role="switch"]'))
      return
    const bounds = canvas.value?.getBoundingClientRect()
    if (!bounds?.width || !bounds.height)
      return
    renderer?.setDepth(
      Math.max(-1, Math.min(1, (pointer.clientX - bounds.left) / bounds.width * 2 - 1)),
      Math.max(-1, Math.min(1, (pointer.clientY - bounds.top) / bounds.height * 2 - 1)),
    )
  }

  watch(() => [motion.paused, motion.depthEnabled, still.value], sync)
  onMounted(async () => {
    media = window.matchMedia('(prefers-reduced-motion: reduce)')
    sync()
    media.addEventListener('change', sync)
    document.addEventListener('visibilitychange', sync)
    window.addEventListener('blur', resetDepth)
    root = canvas.value?.closest('.ar-app') ?? null
    root?.addEventListener('pointermove', move, { passive: true })
    root?.addEventListener('pointerleave', resetDepth)
    try {
      // Load only the selected world, and cancel setup if the user switches away during the import.
      const createRenderer = await loadRenderer()
      if (disposed || !canvas.value)
        return
      renderer = createRenderer(canvas.value, (value) => {
        if (!disposed)
          state.value = value
      })
      resizeObserver = new ResizeObserver(() => renderer?.resize())
      resizeObserver.observe(canvas.value)
      sync()
    }
    catch {
      renderer?.dispose()
      renderer = undefined
      if (!disposed)
        state.value = 'fallback'
    }
  })

  onUnmounted(() => {
    disposed = true
    resizeObserver?.disconnect()
    media?.removeEventListener('change', sync)
    document.removeEventListener('visibilitychange', sync)
    window.removeEventListener('blur', resetDepth)
    root?.removeEventListener('pointermove', move)
    root?.removeEventListener('pointerleave', resetDepth)
    renderer?.dispose()
  })

  return { state: readonly(state), still }
}
