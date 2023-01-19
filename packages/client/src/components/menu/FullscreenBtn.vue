<script lang="ts" setup>
import { useFullscreen } from '@vueuse/core'
const { isFullscreen, toggle } = useFullscreen()
</script>

<template>
  <AgmButton icon title="Fullscreen" @click="toggle">
    <AgmIcon>
      <i-mdi-fullscreen-exit v-if="isFullscreen" />
      <i-mdi-fullscreen v-else />
    </AgmIcon>
  </AgmButton>
</template>
