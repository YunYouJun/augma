// Link Start: a short light tunnel that covers the screen before a navigation and fades away over
// the page it leads to. The canvas lives on document.body rather than in a component, so it survives
// a client-side route change. Colours come from the dark Augma tokens: the tunnel is always a dive
// into the dark, whatever theme the page is in.

export interface LinkStartOptions {
  /** Text drawn at the centre of the tunnel. An empty string draws none. @default 'LINK START' */
  text?: string
  /** Time until the screen is covered, in milliseconds. @default 1000 */
  duration?: number
  /** Streak colours. @default the dark theme's --agm-cyan, --agm-accent and --agm-highlight, plus white light */
  colors?: string[]
  /** Colour the tunnel settles on before fading out. @default the page's --agm-bg */
  arrival?: string
  /** Stacking order of the overlay. @default 1000 */
  zIndex?: number
}

export interface LinkStartNavigateOptions extends LinkStartOptions {
  /** Wait until nothing matches this selector (the old page has left) before fading out. */
  waitFor?: string
  /** Longest wait for `waitFor`, in milliseconds. @default 2000 */
  timeout?: number
}

/** Fades the overlay out; resolves once it has been removed. */
export type LinkStartFinish = () => Promise<void>

const STREAKS = 240
const FADE = 450
// Fallbacks for pages that load the script without @augma/core/tokens.css: the dark theme's values.
const FALLBACK = {
  '--agm-bg': '#131e29',
  '--agm-text': '#edf4fa',
  '--agm-cyan': '#67c8da',
  '--agm-accent': '#f1a74c',
  '--agm-highlight': '#f28c12',
  '--agm-font': '\'Exo 2\', \'Avenir Next\', system-ui, sans-serif',
  '--agm-ease': 'cubic-bezier(0.16, 1, 0.3, 1)',
} as const

type Token = keyof typeof FALLBACK

interface Streak {
  angle: number
  z: number
  speed: number
  width: number
  color: string
}

function token(style: CSSStyleDeclaration, name: Token) {
  return style.getPropertyValue(name).trim() || FALLBACK[name]
}

/** Whether the user asked the system to minimise non-essential motion. */
export function prefersReducedMotion(): boolean {
  return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches
}

const noop: LinkStartFinish = () => Promise.resolve()

/**
 * Plays the tunnel and resolves once the screen is covered. Navigate, then call the returned
 * function to fade the overlay away over the new page.
 *
 * Under `prefers-reduced-motion`, or where a canvas cannot be drawn, it resolves at once with a
 * no-op, so callers can navigate straight away without a special case.
 *
 * @example
 * ```ts
 * const finish = await playLinkStart()
 * await router.push('/guide/')
 * await finish()
 * ```
 */
export function playLinkStart(options: LinkStartOptions = {}): Promise<LinkStartFinish> {
  if (typeof document === 'undefined' || prefersReducedMotion())
    return Promise.resolve(noop)
  const { text = 'LINK START', duration = 1000, zIndex = 1000 } = options

  const canvas = document.createElement('canvas')
  canvas.setAttribute('aria-hidden', 'true')
  // The canvas reads the dark tokens itself, the same way a dark island sits inside a light page.
  canvas.dataset.agmTheme = 'dark'
  Object.assign(canvas.style, {
    position: 'fixed',
    inset: '0',
    width: '100vw',
    height: '100vh',
    zIndex: String(zIndex),
    pointerEvents: 'none',
    opacity: '0',
  })
  document.body.append(canvas)
  const ctx = canvas.getContext('2d')
  if (!ctx) {
    canvas.remove()
    return Promise.resolve(noop)
  }

  const dark = getComputedStyle(canvas)
  const ease = token(dark, '--agm-ease')
  const colors = options.colors?.length
    ? options.colors
    : [token(dark, '--agm-cyan'), token(dark, '--agm-cyan'), token(dark, '--agm-accent'), token(dark, '--agm-highlight'), token(dark, '--agm-text')]
  const night = token(dark, '--agm-bg')
  const light = token(dark, '--agm-text')
  const cyan = token(dark, '--agm-cyan')
  const font = token(dark, '--agm-font')
  // Arrive on the colour of the page we are travelling to.
  const arrival = options.arrival ?? token(getComputedStyle(document.documentElement), '--agm-bg')

  const dpr = Math.min(window.devicePixelRatio || 1, 2)
  const width = window.innerWidth
  const height = window.innerHeight
  canvas.width = Math.round(width * dpr)
  canvas.height = Math.round(height * dpr)
  ctx.scale(dpr, dpr)
  const cx = width / 2
  const cy = height / 2
  const reach = Math.hypot(width, height) / 2

  const spawn = (z = Math.random()): Streak => ({
    angle: Math.random() * Math.PI * 2,
    z,
    speed: 0.5 + Math.random() * 0.9,
    width: 0.6 + Math.random() * 2,
    color: colors[Math.floor(Math.random() * colors.length)]!,
  })
  const streaks = Array.from({ length: STREAKS }, () => spawn())

  let removed = false
  const remove = () => {
    removed = true
    canvas.remove()
  }
  const finish: LinkStartFinish = () => new Promise((resolve) => {
    if (removed)
      return resolve()
    canvas.style.transition = `opacity ${FADE}ms ${ease}`
    canvas.style.opacity = '0'
    setTimeout(() => {
      remove()
      resolve()
    }, FADE + 50)
  })

  const draw = (t: number, dt: number) => {
    const accel = t * t
    ctx.globalCompositeOperation = 'source-over'
    ctx.globalAlpha = 1
    ctx.fillStyle = night
    ctx.fillRect(0, 0, width, height)

    // Streaks rush outward; perspective makes them slow near the centre.
    ctx.globalCompositeOperation = 'lighter'
    ctx.lineCap = 'round'
    for (const s of streaks) {
      s.z += dt * s.speed * (0.25 + accel * 2.6)
      if (s.z > 1)
        Object.assign(s, spawn(0))
      const near = s.z ** 2.4
      const r1 = reach * near
      const r2 = r1 + reach * (0.015 + near * (0.12 + accel * 0.5))
      const cos = Math.cos(s.angle)
      const sin = Math.sin(s.angle)
      ctx.globalAlpha = Math.min(1, s.z * 4) * (0.35 + accel * 0.65)
      ctx.strokeStyle = s.color
      ctx.lineWidth = s.width * (0.6 + near * 2)
      ctx.beginPath()
      ctx.moveTo(cx + cos * r1, cy + sin * r1)
      ctx.lineTo(cx + cos * r2, cy + sin * r2)
      ctx.stroke()
    }

    // Core glow: light at the centre fading into cyan. globalAlpha carries the intensity, so token
    // colours in any CSS format work without being parsed.
    const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, reach * (0.12 + accel * 0.5))
    glow.addColorStop(0, light)
    glow.addColorStop(0.35, cyan)
    glow.addColorStop(1, 'transparent')
    ctx.globalAlpha = 0.3 + accel * 0.6
    ctx.fillStyle = glow
    ctx.fillRect(0, 0, width, height)

    // Title card
    ctx.globalCompositeOperation = 'source-over'
    const textIn = Math.min(1, Math.max(0, (t - 0.08) / 0.2))
    const textOut = Math.min(1, Math.max(0, (t - 0.6) / 0.15))
    const textAlpha = textIn * (1 - textOut)
    if (text && textAlpha > 0) {
      ctx.globalAlpha = textAlpha
      ctx.fillStyle = light
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.font = `700 ${Math.round(Math.min(width / 14, 34))}px ${font}`
      if ('letterSpacing' in ctx)
        ctx.letterSpacing = `${(0.3 + t * 0.4).toFixed(2)}em`
      ctx.shadowColor = cyan
      ctx.shadowBlur = 24
      ctx.fillText(text, cx, cy)
      ctx.shadowBlur = 0
    }

    // Flash, then settle on the destination colour.
    if (t > 0.7) {
      const k = (t - 0.7) / 0.3
      ctx.globalAlpha = Math.min(1, k * 1.6)
      ctx.fillStyle = light
      ctx.fillRect(0, 0, width, height)
      ctx.globalAlpha = Math.max(0, k * 1.4 - 0.4)
      ctx.fillStyle = arrival
      ctx.fillRect(0, 0, width, height)
    }
    ctx.globalAlpha = 1
  }

  return new Promise((resolve) => {
    let start = 0
    let last = 0
    let settled = false
    // A background tab pauses animation frames; never hold up the navigation behind them.
    // Jump to the covered frame so the fade still starts from the arrival colour.
    const guard = setTimeout(() => {
      try {
        draw(1, 0)
        canvas.style.opacity = '1'
        settle(finish)
      }
      catch {
        remove()
        settle(noop)
      }
    }, duration + 500)
    function settle(value: LinkStartFinish) {
      if (settled)
        return
      settled = true
      clearTimeout(guard)
      resolve(value)
    }

    function frame(now: number) {
      if (settled)
        return
      try {
        start ||= now
        const dt = last ? Math.min(now - last, 48) / 1000 : 0
        last = now
        const t = Math.min((now - start) / duration, 1)
        draw(t, dt)
        if (t < 1)
          requestAnimationFrame(frame)
        else
          settle(finish)
      }
      catch {
        // A drawing failure must not strand the overlay or the navigation.
        remove()
        settle(noop)
      }
    }

    requestAnimationFrame((now) => {
      canvas.style.transition = `opacity 200ms ${ease}`
      canvas.style.opacity = '1'
      frame(now)
    })
  })
}

/**
 * Resolves once nothing matches `selector` (the old page has been replaced), or after `timeout`.
 */
export function waitUntilGone(selector: string, timeout = 2000): Promise<void> {
  const end = performance.now() + timeout
  return new Promise((resolve) => {
    const check = () => {
      if (!document.querySelector(selector) || performance.now() > end)
        requestAnimationFrame(() => resolve())
      else
        requestAnimationFrame(check)
    }
    check()
  })
}

let active: Promise<void> | undefined

/**
 * Plays the tunnel, runs `navigate` once the screen is covered, then fades out over the new page.
 * Under `prefers-reduced-motion` it navigates straight away. The overlay is removed even when
 * `navigate` throws, and the error is passed on. Calls made while a run is in flight return that run.
 *
 * @param navigate - Changes the page, for example `() => router.go('/guide/')`
 *
 * @example
 * ```ts
 * import { linkStart } from '@augma/core/link-start'
 *
 * button.addEventListener('click', () => linkStart(() => router.push('/guide/'), { waitFor: '.home' }))
 * ```
 */
export function linkStart(navigate: () => unknown, options: LinkStartNavigateOptions = {}): Promise<void> {
  active ??= (async () => {
    const finish = await playLinkStart(options)
    try {
      await navigate()
      if (options.waitFor)
        await waitUntilGone(options.waitFor, options.timeout)
    }
    finally {
      await finish()
    }
  })().finally(() => {
    active = undefined
  })
  return active
}
