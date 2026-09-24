import type { Ref } from 'vue'
import { computed, nextTick, onMounted, onUnmounted, shallowRef, watch } from 'vue'

const storageKey = 'augma-window-placements-v1'
interface Position { x: number, y: number }

function readPositions(): Record<string, Position> {
  try {
    const value: unknown = JSON.parse(localStorage.getItem(storageKey) || '{}')
    return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Position> : {}
  }
  catch {
    return {}
  }
}

export function clearWindowPlacements() {
  try {
    localStorage.removeItem(storageKey)
  }
  catch { /* Layout remains usable without storage. */ }
}

export function useWindowPlacement(app: string, element: Readonly<Ref<HTMLElement | null>>, resetVersion: Readonly<Ref<number>>) {
  const position = shallowRef<Position | null>(null)
  const style = computed(() => position.value ? { left: `${position.value.x}px`, top: `${position.value.y}px`, right: 'auto' } : undefined)
  let pointerId: number | null = null
  let pointerOffset: Position = { x: 0, y: 0 }
  let resizeObserver: ResizeObserver | null = null

  function workspace() {
    return element.value?.parentElement
  }

  function clamp(x: number, y: number): Position | null {
    const panel = element.value
    const parent = workspace()
    if (!panel || !parent)
      return null
    return {
      x: Math.max(8, Math.min(x, parent.clientWidth - panel.offsetWidth - 8)),
      y: Math.max(8, Math.min(y, parent.clientHeight - panel.offsetHeight - 8)),
    }
  }

  function moveTo(x: number, y: number) {
    const next = clamp(x, y)
    if (next)
      position.value = next
  }

  function currentPosition(): Position | null {
    const panel = element.value
    const parent = workspace()
    if (!panel || !parent)
      return null
    const bounds = panel.getBoundingClientRect()
    const parentBounds = parent.getBoundingClientRect()
    return { x: bounds.left - parentBounds.left, y: bounds.top - parentBounds.top }
  }

  function persist() {
    if (!position.value)
      return
    try {
      localStorage.setItem(storageKey, JSON.stringify({ ...readPositions(), [app]: position.value }))
    }
    catch { /* Dragging still works when storage is unavailable. */ }
  }

  function reset() {
    position.value = null
    try {
      const positions = readPositions()
      delete positions[app]
      localStorage.setItem(storageKey, JSON.stringify(positions))
    }
    catch { /* Layout remains usable without storage. */ }
  }

  function pointerDown(event: PointerEvent) {
    if (event.button !== 0 || (event.target as HTMLElement).closest('button'))
      return
    const panel = element.value
    const parent = workspace()
    const start = currentPosition()
    if (!panel || !parent || !start)
      return
    const bounds = panel.getBoundingClientRect()
    pointerId = event.pointerId
    pointerOffset = { x: event.clientX - bounds.left, y: event.clientY - bounds.top }
    moveTo(start.x, start.y)
    ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
    event.preventDefault()
  }

  function pointerMove(event: PointerEvent) {
    if (pointerId !== event.pointerId)
      return
    const parent = workspace()
    if (!parent)
      return
    const bounds = parent.getBoundingClientRect()
    moveTo(event.clientX - bounds.left - pointerOffset.x, event.clientY - bounds.top - pointerOffset.y)
  }

  function pointerUp(event: PointerEvent) {
    if (pointerId !== event.pointerId)
      return
    pointerId = null
    persist()
  }

  function keyDown(event: KeyboardEvent) {
    const directions: Record<string, Position> = {
      ArrowLeft: { x: -1, y: 0 },
      ArrowRight: { x: 1, y: 0 },
      ArrowUp: { x: 0, y: -1 },
      ArrowDown: { x: 0, y: 1 },
    }
    const direction = directions[event.key]
    if (!direction || event.target !== event.currentTarget)
      return
    const current = position.value || currentPosition()
    if (!current)
      return
    const step = event.shiftKey ? 32 : 8
    moveTo(current.x + direction.x * step, current.y + direction.y * step)
    persist()
    event.preventDefault()
  }

  function fit() {
    if (position.value)
      moveTo(position.value.x, position.value.y)
  }

  onMounted(() => {
    const saved = readPositions()[app]
    if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y))
      moveTo(saved.x, saved.y)
    if (typeof ResizeObserver !== 'undefined' && element.value && workspace()) {
      resizeObserver = new ResizeObserver(fit)
      resizeObserver.observe(element.value)
      resizeObserver.observe(workspace()!)
    }
    window.addEventListener('resize', fit)
  })
  onUnmounted(() => {
    resizeObserver?.disconnect()
    window.removeEventListener('resize', fit)
  })
  watch(resetVersion, () => {
    void nextTick(reset)
  })

  return { position, style, reset, pointerDown, pointerMove, pointerUp, keyDown }
}
