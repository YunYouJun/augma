<script setup lang="ts">
import { computed } from 'vue'
import { round, sequence } from './scenery'

const props = defineProps<{ seed: number, count: number, top: number, bottom: number }>()

/** Polygon fragments of the AR layer, rising and turning like data breaking loose. */
const shards = computed(() => {
  const random = sequence(props.seed)
  const point = (left: number, top: number, span: number) => `${round(left + random() * span)}% ${round(top + random() * span)}%`
  return Array.from({ length: props.count }, () => ({
    'left': `${round(random() * 100)}%`,
    'top': `${round(props.top + random() * (props.bottom - props.top))}%`,
    'width': `${Math.round(7 + random() ** 2 * 18)}px`,
    'clipPath': `polygon(${point(0, 0, 40)}, ${point(60, 10, 40)}, ${point(20, 60, 40)})`,
    'animationDuration': `${Math.round(9 + random() * 10)}s`,
    'animationDelay': `${-Math.round(random() * 19)}s`,
    '--dx': `${Math.round((random() - 0.5) * 120)}px`,
    '--dy': `${-Math.round(90 + random() * 160)}px`,
    '--spin': `${Math.round(240 + random() * 480)}deg`,
  }))
})
</script>

<template>
  <div class="data-shards">
    <i v-for="(style, index) in shards" :key="index" class="shard" :style="style" />
  </div>
</template>

<style scoped>
.data-shards { position: absolute; inset: 0; }
.shard { position: absolute; aspect-ratio: 1; opacity: .6; background: linear-gradient(135deg, rgb(255 255 255 / 95%), rgb(var(--ar) / 80%) 55%, rgb(var(--ar) / 25%)); animation: shard ease-in-out infinite; will-change: transform, opacity; }
@keyframes shard {
  0% { opacity: 0; transform: translate3d(0, 0, 0) rotate3d(1, .6, .2, 0deg); }
  15% { opacity: 1; }
  80% { opacity: .8; }
  100% { opacity: 0; transform: translate3d(var(--dx), var(--dy), 0) rotate3d(1, .6, .2, var(--spin)); }
}
</style>
