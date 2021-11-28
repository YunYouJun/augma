<template>
  <AgmButton icon title="Fullscreen" @click="toggle">
    <AgmIcon color="black">
      <i-mdi-fullscreen-exit v-if="isFullscreen" />
      <i-mdi-fullscreen v-else />
    </AgmIcon>
  </AgmButton>
</template>

<script lang="ts" setup>
import { useFullscreen } from '@vueuse/core'
const { isFullscreen, toggle } = useFullscreen()

const fullscreen = ref(document.fullscreenElement)

onMounted(() => {
  document.onfullscreenchange = () => {
    fullscreen.value = document.fullscreenElement
  }
})
</script>
