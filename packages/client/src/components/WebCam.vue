<script lang="ts" setup>
import { computed, onMounted, ref, watchEffect } from 'vue'
import { useWebcam } from '@augma/hooks'
import { useCameraStore } from '~/stores/camera'
const props = withDefaults(defineProps<{
  isFlip: boolean
  isFront: boolean
}>(), {
  isFlip: false,
  isFront: false,
})

const camera = useCameraStore()

const videoRef = ref(null)

const isFlip = ref(props.isFlip)

const classes = computed(() => {
  return {
    flip: isFlip,
  }
})

const { changeWebcamStream, settings } = useWebcam(videoRef, {
  isFront: props.isFront,
})

watchEffect(async () => {
  await changeWebcamStream(props.isFront)
})

onMounted(async () => {
  await changeWebcamStream(props.isFront)
  camera.videoEl = videoRef.value
  camera.settings = settings.value
  const ratio = document.body.clientWidth / settings.value.width
  camera.ratio = ratio
})
</script>

<template>
  <video id="webcam" ref="videoRef" :class="classes" autoplay />
</template>

<style lang="scss">
#webcam {
  width: 100vw;
  height: 100vh;
  object-fit: cover;
}

.flip {
  transform: rotateY(180deg);
}
</style>
