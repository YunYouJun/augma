<script setup lang="ts">
import { computed } from 'vue'
import { round, sequence } from './scenery'

/** Light catching the lens: sun rays, a horizontal streak and hexagonal ghosts across the view. */
const props = defineProps<{ x: number, y: number }>()

const ghosts = computed(() => ([[0.45, 26, 'a'], [0.8, 72, 'b'], [1.25, 40, 'c'], [1.6, 128, 'a'], [1.9, 54, 'b']] as const).map(([k, size, tone]) => ({
  'left': `${round(props.x + (50 - props.x) * k)}%`,
  'top': `${round(props.y + (50 - props.y) * k)}%`,
  'width': `${size}px`,
  '--tone': `var(--ghost-${tone})`,
})))

const random = sequence(53)
const stops: string[] = []
for (let angle = 0; angle < 360;) {
  const width = 2 + random() * 5
  stops.push(`transparent ${round(angle)}deg`, `rgb(var(--ray) / ${Math.round(10 + random() * 26)}%) ${round(angle + width / 2)}deg`, `transparent ${round(angle + width)}deg`)
  angle += width + 6 + random() * 18
}
const rays = `conic-gradient(${stops.join(', ')})`
</script>

<template>
  <div class="lens-flare" :style="{ '--sun-x': `${x}%`, '--sun-y': `${y}%` }">
    <i class="flare-rays" :style="{ backgroundImage: rays }" />
    <i class="flare-streak" />
    <i v-for="(style, index) in ghosts" :key="index" class="flare-ghost" :style="style" />
  </div>
</template>

<style scoped>
.lens-flare { position: absolute; inset: 0; overflow: hidden; }
/* Still rays paint once with the flare; a turning masked layer this size held hundreds of megabytes. */
.flare-rays { position: absolute; left: var(--sun-x); top: var(--sun-y); width: 140vmax; aspect-ratio: 1; translate: -50% -50%; opacity: var(--rays, .5); mask-image: radial-gradient(circle closest-side, black, rgb(0 0 0 / 45%) 43%, transparent); }
.flare-streak { position: absolute; left: var(--sun-x); top: var(--sun-y); width: 80vw; height: 40px; translate: -50% -50%; opacity: var(--streak, .9); background: radial-gradient(ellipse closest-side, rgb(var(--flare) / 40%), transparent); animation: flare-shimmer 5s ease-in-out infinite alternate; }
.flare-streak::before { content: ''; position: absolute; left: 0; right: 0; top: 50%; height: 2px; translate: 0 -50%; background: linear-gradient(90deg, transparent, rgb(var(--flare) / 85%) 50%, transparent); }
.flare-ghost { position: absolute; aspect-ratio: 1; translate: -50% -50%; opacity: var(--ghosts, .9); clip-path: polygon(25% 6%, 75% 6%, 100% 50%, 75% 94%, 25% 94%, 0 50%); background: radial-gradient(circle closest-side, rgb(var(--tone) / 8%), rgb(var(--tone) / 18%) 70%, rgb(var(--tone) / 40%) 94%, transparent); }
@keyframes flare-shimmer { from { opacity: calc(var(--streak, .9) * .7); } to { opacity: var(--streak, .9); } }
</style>
