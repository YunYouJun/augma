import type { Ref } from 'vue'
import { computed, onMounted, onUnmounted, shallowRef, watch } from 'vue'

/** Small optical-layer shifts without re-rendering application state on pointer movement. */
export function useDepthMotion(root: Readonly<Ref<HTMLElement | null>>, enabled: Readonly<Ref<boolean>>) {
  const reducedMotion = shallowRef(false)
  const visible = shallowRef(false)
  const active = computed(() => enabled.value && visible.value && !reducedMotion.value)
  let media: MediaQueryList | undefined
  const syncMotion = () => {
    reducedMotion.value = media?.matches ?? false
  }
  const syncVisibility = () => {
    visible.value = !document.hidden
  }

  onMounted(() => {
    media = window.matchMedia('(prefers-reduced-motion: reduce)')
    syncMotion()
    syncVisibility()
    media.addEventListener('change', syncMotion)
    document.addEventListener('visibilitychange', syncVisibility)
  })
  onUnmounted(() => {
    media?.removeEventListener('change', syncMotion)
    document.removeEventListener('visibilitychange', syncVisibility)
  })

  watch([active, root], ([running, element], _, onCleanup) => {
    if (!running || !element)
      return
    let frame: number | undefined
    let x = 0
    let y = 0
    function apply() {
      element!.style.setProperty('--depth-x', x.toFixed(4))
      element!.style.setProperty('--depth-y', y.toFixed(4))
      frame = undefined
    }
    function reset() {
      if (frame !== undefined)
        cancelAnimationFrame(frame)
      frame = undefined
      x = 0
      y = 0
      element!.style.removeProperty('--depth-x')
      element!.style.removeProperty('--depth-y')
    }
    function move(event: PointerEvent) {
      if (event.pointerType !== 'mouse' || event.buttons)
        return
      // Keep controls still while aiming at a button or manipulating a field.
      if (event.target instanceof Element && event.target.closest('button, a, input, select, [role="slider"], [role="switch"]'))
        return
      x = Math.max(-1, Math.min(1, event.clientX / window.innerWidth * 2 - 1))
      y = Math.max(-1, Math.min(1, event.clientY / window.innerHeight * 2 - 1))
      if (frame === undefined)
        frame = requestAnimationFrame(apply)
    }
    element.addEventListener('pointermove', move, { passive: true })
    element.addEventListener('pointerleave', reset)
    window.addEventListener('blur', reset)
    onCleanup(() => {
      reset()
      element.removeEventListener('pointermove', move)
      element.removeEventListener('pointerleave', reset)
      window.removeEventListener('blur', reset)
    })
  }, { flush: 'post' })

  return { active, reducedMotion }
}
