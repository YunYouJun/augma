<script setup lang="ts">
import { useTemplateRef, watch } from 'vue'

const props = defineProps<{ stream: MediaStream | null, mirror: boolean }>()
const video = useTemplateRef<HTMLVideoElement>('video')
watch(
  [() => props.stream, video],
  async ([stream, element]) => {
    if (element) {
      element.srcObject = stream
      if (stream) {
        try {
          await element.play()
        }
        catch {
          /* A native playback control remains available. */
        }
      }
    }
  },
  { immediate: true },
)
function capture() {
  const element = video.value
  if (!element?.videoWidth)
    return false
  const canvas = document.createElement('canvas')
  canvas.width = element.videoWidth
  canvas.height = element.videoHeight
  const ctx = canvas.getContext('2d')
  if (!ctx)
    return false
  if (props.mirror) {
    ctx.translate(canvas.width, 0)
    ctx.scale(-1, 1)
  }
  ctx.drawImage(element, 0, 0)
  const link = document.createElement('a')
  link.href = canvas.toDataURL('image/png')
  link.download = 'augma-camera.png'
  link.click()
  return true
}
defineExpose({ capture })
</script>

<template>
  <video
    v-show="!!stream"
    ref="video"
    class="camera-feed"
    :class="{ mirrored: mirror }"
    autoplay
    playsinline
    muted
    :controls="!!stream"
    aria-label="摄像头画面"
  />
</template>
