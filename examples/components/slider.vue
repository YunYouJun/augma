<script setup lang="ts">
import { AgmSlider } from 'augma'
import { shallowRef } from 'vue'

const opacity = shallowRef(72)
</script>

<template>
  <div class="example-stack">
    <AgmSlider v-model="opacity" label="界面不透明度" :min="20" :max="100" />
    <AgmSlider label="固定亮度" :model-value="50" disabled />
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
