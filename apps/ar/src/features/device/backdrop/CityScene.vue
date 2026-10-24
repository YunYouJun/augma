<script setup lang="ts">
import { useTemplateRef } from 'vue'
import { useSceneRenderer } from './useSceneRenderer'

const props = defineProps<{
  paused?: boolean
  depthEnabled?: boolean
}>()
const canvas = useTemplateRef<HTMLCanvasElement>('canvas')
const { state, still } = useSceneRenderer(canvas, props, async () => (await import('./city/cityRenderer')).createCityRenderer)
</script>

<template>
  <div class="backdrop-scene is-city" :class="{ 'is-ready': state === 'webgl', 'is-still': still }" :data-renderer="state">
    <canvas ref="canvas" class="art art-mid city-landscape" />
    <div class="city-atmosphere" />
  </div>
</template>

<style scoped>
.is-city { background: linear-gradient(175deg, #b5cfdd 0%, #e4ded6 57%, #a3b5c4 58%, #718f9e 80%, #d5d6cc 81%, #bfc5bc 100%); }
/* Keep a real layout size during lazy loading; display:none would initialize the GPU at 0 × 0. */
.city-landscape { opacity: 0; }
.is-ready .city-landscape { opacity: 1; }
.city-atmosphere { position: absolute; inset: 0; background: linear-gradient(rgb(17 30 55 / 3%), transparent 40%, rgb(18 35 50 / 5%)); }
.is-dark .city-atmosphere { background: linear-gradient(rgb(12 22 43 / 30%), rgb(18 32 49 / 12%) 48%, rgb(10 22 37 / 30%)); }
</style>
