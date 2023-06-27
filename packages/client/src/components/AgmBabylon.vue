<script lang="ts" setup>
import { createWebXR } from '@augma/babylon'

const babylonCanvas = ref<HTMLCanvasElement | null>(null)

onMounted(() => {
  if (!babylonCanvas.value)
    return

  const canvas = babylonCanvas.value
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight

  window.onresize = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }

  createWebXR(babylonCanvas.value)
})
</script>

<template>
  <canvas id="babylon-canvas" ref="babylonCanvas" />
</template>

<style scoped>
#babylon-canvas {
  width: 100%;
  height: 100%;
}
</style>
