import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { linkStart, playLinkStart } from '../../packages/core/src/link-start'

// happy-dom has no 2D canvas; a recording stand-in lets the tunnel run frame by frame.
function fakeContext(fail = false) {
  const calls: string[] = []
  const context = new Proxy({} as Record<string, unknown>, {
    get(target, key: string) {
      if (key in target)
        return target[key]
      return (...args: unknown[]) => {
        calls.push(key)
        if (fail && key === 'stroke')
          throw new Error('lost context')
        return key === 'createRadialGradient' ? { addColorStop: () => {} } : args[0]
      }
    },
    set(target, key: string, value) {
      target[key] = value
      return true
    },
  })
  vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(context as unknown as CanvasRenderingContext2D)
  return calls
}

function reduceMotion(reduce: boolean) {
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: reduce && query.includes('reduce') }))
}

const overlay = () => document.querySelector('canvas')

describe('link start', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout', 'requestAnimationFrame', 'cancelAnimationFrame', 'performance'] })
    reduceMotion(false)
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    document.body.innerHTML = ''
  })

  it('covers the screen, navigates, then fades out and removes the overlay', async () => {
    const calls = fakeContext()
    const navigate = vi.fn()
    const done = linkStart(navigate)
    const canvas = overlay()!
    expect(canvas.getAttribute('aria-hidden')).toBe('true')
    expect(canvas.dataset.agmTheme).toBe('dark')
    expect(canvas.style.pointerEvents).toBe('none')
    await vi.advanceTimersByTimeAsync(500)
    expect(navigate).not.toHaveBeenCalled()
    expect(calls).toContain('fillText')
    await vi.advanceTimersByTimeAsync(600)
    expect(navigate).toHaveBeenCalledOnce()
    expect(overlay()).not.toBeNull()
    await vi.advanceTimersByTimeAsync(600)
    await done
    expect(overlay()).toBeNull()
  })

  it('navigates at once without a tunnel under reduced motion', async () => {
    reduceMotion(true)
    const navigate = vi.fn()
    const done = linkStart(navigate)
    expect(overlay()).toBeNull()
    await done
    expect(navigate).toHaveBeenCalledOnce()
  })

  it('navigates at once where no canvas can be drawn', async () => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(null)
    const navigate = vi.fn()
    await linkStart(navigate)
    expect(navigate).toHaveBeenCalledOnce()
    expect(overlay()).toBeNull()
  })

  it('removes the overlay and passes on a navigation error', async () => {
    fakeContext()
    const done = linkStart(() => {
      throw new Error('route missing')
    })
    const failed = expect(done).rejects.toThrow('route missing')
    await vi.advanceTimersByTimeAsync(2000)
    await failed
    expect(overlay()).toBeNull()
  })

  it('removes the overlay and still navigates when drawing fails', async () => {
    fakeContext(true)
    const navigate = vi.fn()
    const done = linkStart(navigate)
    await vi.advanceTimersByTimeAsync(100)
    expect(overlay()).toBeNull()
    await done
    expect(navigate).toHaveBeenCalledOnce()
  })

  it('joins a run in flight instead of navigating twice', async () => {
    fakeContext()
    const navigate = vi.fn()
    const first = linkStart(navigate)
    const second = linkStart(navigate)
    expect(second).toBe(first)
    expect(document.querySelectorAll('canvas')).toHaveLength(1)
    await vi.advanceTimersByTimeAsync(2000)
    await first
    expect(navigate).toHaveBeenCalledOnce()
  })

  it('reads the arrival colour from the page tokens unless given one', async () => {
    fakeContext()
    document.documentElement.style.setProperty('--agm-bg', 'rgb(1, 2, 3)')
    const fills: unknown[] = []
    const finishing = playLinkStart()
    const context = overlay()!.getContext('2d') as unknown as Record<string, unknown>
    let fill: unknown
    Object.defineProperty(context, 'fillStyle', {
      get: () => fill,
      set: (value) => {
        fill = value
        fills.push(value)
      },
    })
    await vi.advanceTimersByTimeAsync(1100)
    const finish = await finishing
    expect(fills).toContain('rgb(1, 2, 3)')
    const removed = finish()
    await vi.advanceTimersByTimeAsync(600)
    await removed
    expect(overlay()).toBeNull()
    document.documentElement.style.removeProperty('--agm-bg')
  })
})
