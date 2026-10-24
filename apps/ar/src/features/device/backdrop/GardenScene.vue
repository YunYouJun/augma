<script setup lang="ts">
import { useTemplateRef } from 'vue'
import { useSceneRenderer } from './useSceneRenderer'

const props = defineProps<{
  paused?: boolean
  depthEnabled?: boolean
}>()
const canvas = useTemplateRef<HTMLCanvasElement>('canvas')
const { state, still } = useSceneRenderer(canvas, props, async () => (await import('./garden/gardenRenderer')).createGardenRenderer)
</script>

<template>
  <div class="backdrop-scene is-garden" :class="{ 'is-ready': state === 'webgl', 'is-still': still }" :data-renderer="state">
    <canvas ref="canvas" class="art art-mid garden-landscape" />
    <div class="garden-atmosphere" />
  </div>
</template>

<style scoped>
.is-garden { background: linear-gradient(175deg, #93bedb 0%, #d9e9e9 58%, #9bbaaa 59%, #608b79 80%, #466c5d 100%); }
/* Preserve canvas layout while its WebGL resources load. */
.garden-landscape { opacity: 0; }
.is-ready .garden-landscape { opacity: 1; }
.garden-atmosphere { position: absolute; inset: 0; background: linear-gradient(rgb(8 30 50 / 2%), transparent 60%, rgb(13 42 49 / 4%)); }
.is-dark .garden-atmosphere { background: linear-gradient(rgb(12 28 49 / 22%), rgb(15 36 53 / 8%) 48%, rgb(10 32 43 / 24%)); }
</style>
