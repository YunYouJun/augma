<script setup lang="ts">
import { AgmHudProgress, AgmSlider } from 'augma'
import { shallowRef } from 'vue'

const value = shallowRef(72)
</script>

<template>
  <div class="example-stack">
    <div class="example-row">
      <AgmHudProgress label="Synced" :value="value" variant="ring" />
      <AgmHudProgress label="Scanning" variant="ring" />
    </div>
    <AgmHudProgress label="Data sync" :value="value" />
    <AgmSlider v-model="value" label="Adjust sample progress" />
    <AgmHudProgress label="Connecting" indeterminate-text="In progress" />
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
