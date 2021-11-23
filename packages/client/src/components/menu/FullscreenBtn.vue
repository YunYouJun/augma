<template>
  <agm-button icon title="Fullscreen" @click="toggle">
    <agm-icon :icon="icon" color="black" />
  </agm-button>
</template>

<script lang="ts">
import { useFullscreen } from '@vueuse/core'
import { computed } from 'vue'
export default {
  setup() {
    const { isFullscreen, toggle } = useFullscreen()

    const icon = computed(() => {
      return isFullscreen.value ? 'mdi:fullscreen-exit' : 'mdi:fullscreen'
    })

    return {
      icon,
      toggle,
    }
  },
  data() {
    return {
      fullscreen: document.fullscreenElement,
    }
  },
  mounted() {
    document.onfullscreenchange = () => {
      this.fullscreen = document.fullscreenElement
    }
  },
}
</script>
