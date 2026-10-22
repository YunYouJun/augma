<script setup lang="ts">
import { AgmButton, AgmHudStatus, linkStart } from 'augma'
import { shallowRef } from 'vue'

const links = shallowRef(0)

// linkStart covers the screen, runs the callback, then fades out. Pass your router's navigation here.
function start() {
  return linkStart(() => {
    links.value++
  })
}
</script>

<template>
  <div class="example-row">
    <AgmButton @click="start">Link Start</AgmButton>
    <AgmHudStatus :tone="links ? 'success' : 'neutral'">
      {{ links ? `Linked × ${links}` : 'Waiting to link' }}
    </AgmHudStatus>
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
</style>
