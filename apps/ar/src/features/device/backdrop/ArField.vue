<script setup lang="ts">
import { hexagon, hexCentres, sequence } from './scenery'

/** The AR battlefield floor: a hexagon grid laid on the ground, cells lighting up and rings spreading out. */
const size = 34
const centres = hexCentres(1600, 640, size)
const grid = centres.map(([x, y]) => hexagon(x, y, size)).join('')
const cells = ['', '', '']
const random = sequence(29)
for (const [x, y] of centres) {
  if (y > 90 && random() < 0.09)
    cells[Math.floor(random() * 3)] += hexagon(x, y, size * 0.82)
}
</script>

<template>
  <div class="ar-field">
    <div class="ar-plane">
      <svg class="ar-grid" viewBox="0 0 1600 640" preserveAspectRatio="xMidYMin slice"><path :d="grid" /></svg>
      <svg v-for="(path, index) in cells" :key="index" class="ar-cells" :class="`is-${index + 1}`" viewBox="0 0 1600 640" preserveAspectRatio="xMidYMin slice"><path class="ar-glow" :d="path" /><path :d="path" /></svg>
      <i class="ar-ring" />
      <i class="ar-ring is-late" />
    </div>
  </div>
</template>

<style scoped>
.ar-field { position: absolute; left: 0; right: 0; top: var(--ar-horizon, 76%); bottom: 0; overflow: hidden; perspective: 460px; perspective-origin: 50% 0; }
.ar-plane { position: absolute; left: -50%; right: -50%; top: 0; height: 460px; transform-origin: 50% 0; transform: rotateX(74deg); mask-image: radial-gradient(ellipse 46% 120% at 50% 0, black 30%, transparent 78%); }
.ar-grid, .ar-cells { position: absolute; inset: 0; width: 100%; height: 100%; fill: none; }
.ar-grid path { stroke: rgb(var(--ar) / var(--ar-grid, 26%)); stroke-width: 1.6; }
.ar-cells { opacity: .5; animation: ar-cell 7s ease-in-out infinite; will-change: opacity; }
.ar-cells path { fill: rgb(var(--ar) / 22%); stroke: rgb(var(--ar) / 80%); stroke-width: 2; }
/* A soft wide stroke rather than a filter: a blur over the whole tilted plane needs buffers of hundreds of megabytes. */
.ar-cells .ar-glow { fill: none; stroke: rgb(var(--ar) / 26%); stroke-width: 10; stroke-linejoin: round; }
.ar-cells.is-2 { animation-duration: 9s; animation-delay: -3s; }
.ar-cells.is-3 { animation-duration: 11s; animation-delay: -7s; }
.ar-ring { position: absolute; left: 50%; top: 30%; width: 1400px; aspect-ratio: 1; translate: -50% -50%; border-radius: 50%; opacity: 0; background: radial-gradient(circle closest-side, transparent 84%, rgb(var(--ar) / 35%) 93%, rgb(var(--ar) / 95%) 97%, transparent 100%); animation: ar-ring 8s cubic-bezier(.2, .6, .3, 1) infinite; will-change: transform, opacity; }
.ar-ring.is-late { animation-delay: -4s; }
@keyframes ar-cell { 0%, 100% { opacity: 0; } 35%, 55% { opacity: 1; } }
@keyframes ar-ring { 0% { opacity: 0; transform: scale(.04); } 8% { opacity: 1; } 70% { opacity: .55; } 100% { opacity: 0; transform: scale(1); } }
</style>
