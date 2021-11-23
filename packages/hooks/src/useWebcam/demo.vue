<template>
  <video id="webcam" ref="videoRef" autoplay />
</template>

<script lang="ts" setup>
import { onMounted, ref } from 'vue'
import { useWebcam } from './index'

const videoRef = ref(null)
const { changeWebcamStream, settings } = useWebcam(videoRef)

onMounted(async() => {
  await changeWebcamStream()
  // eslint-disable-next-line no-console
  console.log(settings.value)
})
</script>

<style scoped>
#webcam {
  width: 100%;
}
</style>
