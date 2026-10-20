/** Generators for the simulated scenery. Seeded, so every visit draws the same world. */

/** `[x, y, radius]` */
export type Circle = [number, number, number]

export interface Box { x: number, y: number, w: number, h: number }

/** A particle placed in percent of the view, drifting by `dx`/`dy` pixels over one cycle. */
export interface Drift {
  x: number
  y: number
  size: number
  duration: number
  delay: number
  dx: number
  dy: number
  alt: boolean
}

/** A repeatable pseudo-random sequence in `[0, 1)`. */
export function sequence(seed: number) {
  return () => {
    seed = seed * 16807 % 2147483647
    return (seed - 1) / 2147483646
  }
}

export const round = (value: number) => Math.round(value * 10) / 10

/** Union of circles as one path. */
export function circles(items: Circle[]) {
  return items.map(([x, y, r]) => `M${x - r} ${y}a${r} ${r} 0 1 0 ${r * 2} 0a${r} ${r} 0 1 0 ${-r * 2} 0`).join('')
}

/**
 * Cel shading for round shapes: each circle shrinks toward the light while staying inside the original,
 * so drawing the result over the base leaves a hard-edged shadow rim on the far side.
 *
 * @param items - The base circles
 * @param light - Direction toward the light, at most unit length
 * @param amount - How much of each radius becomes shadow
 */
export function lit(items: Circle[], light: [number, number], amount = 0.22): Circle[] {
  const [ux, uy] = light
  return items.map(([x, y, r]) => [round(x + ux * r * amount), round(y + uy * r * amount), round(r * (1 - amount))])
}

/** Pointed leaves as one path: `[x, y, angle in degrees, length, half width]`. */
export function leaves(items: number[][]) {
  return items.map(([x, y, angle, length, width]) => {
    const cos = Math.cos(angle * Math.PI / 180)
    const sin = Math.sin(angle * Math.PI / 180)
    const at = (u: number, v: number) => `${round(x + u * cos - v * sin)} ${round(y + u * sin + v * cos)}`
    return `M${x} ${y}Q${at(length * 0.45, -width)} ${at(length, 0)}Q${at(length * 0.45, width)} ${x} ${y}z`
  }).join('')
}

/** A tree crown of overlapping circles scattered inside an ellipse. */
export function crown(seed: number, cx: number, cy: number, rx: number, ry: number, count: number): Circle[] {
  const random = sequence(seed)
  const items: Circle[] = [[cx, cy, Math.round(Math.min(rx, ry) * 0.75)]]
  for (let i = 0; i < count; i++) {
    const angle = random() * Math.PI * 2
    const distance = Math.sqrt(random())
    items.push([round(cx + Math.cos(angle) * rx * distance), round(cy + Math.sin(angle) * ry * distance), Math.round(Math.min(rx, ry) * (0.22 + random() * 0.3))])
  }
  return items
}

/** A towering cumulus: rows of puffs that narrow toward the top. The bottom row hangs below `bottom`. */
export function cumulus(seed: number, x: number, bottom: number, width: number, rows: number): Circle[] {
  const random = sequence(seed)
  const step = width / 6
  const items: Circle[] = []
  for (let row = 0; row < rows; row++) {
    const span = width * (1 - row / rows) ** 0.9
    const left = x + (width - span) / 2 + (random() - 0.5) * step * 0.8
    const count = Math.max(1, Math.round(span / step))
    for (let i = 0; i < count; i++) {
      const r = step * (0.62 + random() * 0.4) * (1 - row / rows * 0.25)
      items.push([round(left + span * (i + 0.5) / count), round(bottom - row * step * 0.7 - r * 0.3), round(r)])
    }
  }
  return items
}

export function towers(seed: number, base: number, [minHeight, maxHeight]: number[], [minWidth, maxWidth]: number[]) {
  const random = sequence(seed)
  const list: Box[] = []
  for (let x = -20; x < 1620;) {
    const w = Math.round(minWidth + random() * (maxWidth - minWidth))
    const h = Math.round(minHeight + random() ** 1.3 * (maxHeight - minHeight))
    list.push({ x, y: base - h, w, h })
    x += w + Math.round(random() * 12)
  }
  return list
}

export const boxes = (list: Box[]) => list.map(({ x, y, w, h }) => `M${x} ${y}h${w}v${h}h${-w}z`).join('')

/** Pointy-top hexagon centred on `(x, y)`. */
export function hexagon(x: number, y: number, size: number) {
  return `${Array.from({ length: 6 }, (_, i) => {
    const angle = (60 * i - 90) * Math.PI / 180
    return `${i ? 'L' : 'M'}${round(x + size * Math.cos(angle))} ${round(y + size * Math.sin(angle))}`
  }).join('')}z`
}

/** Centres of a pointy-top hexagon grid covering `width` × `height`. */
export function hexCentres(width: number, height: number, size: number) {
  const w = Math.sqrt(3) * size
  const centres: [number, number][] = []
  for (let row = 0; row * size * 1.5 < height + size; row++) {
    for (let x = row % 2 ? w / 2 : 0; x < width + w; x += w)
      centres.push([round(x), round(row * size * 1.5)])
  }
  return centres
}

export function drifts(seed: number, count: number, [top, bottom]: number[], [minSize, maxSize]: number[], move: (random: () => number) => [number, number], alt = 0): Drift[] {
  const random = sequence(seed)
  return Array.from({ length: count }, () => {
    const [dx, dy] = move(random)
    return {
      x: round(random() * 100),
      y: round(top + random() * (bottom - top)),
      size: Math.round(minSize + random() ** 2 * (maxSize - minSize)),
      duration: Math.round(12 + random() * 14),
      delay: -Math.round(random() * 26),
      dx,
      dy,
      alt: random() < alt,
    }
  })
}

/** Inline style for a drifting particle. */
export function driftStyle(drift: Drift) {
  return {
    'left': `${drift.x}%`,
    'top': `${drift.y}%`,
    'width': `${drift.size}px`,
    'height': `${drift.size}px`,
    'animationDuration': `${drift.duration}s`,
    'animationDelay': `${drift.delay}s`,
    '--dx': `${drift.dx}px`,
    '--dy': `${drift.dy}px`,
  }
}
