<script setup lang="ts">
import { AgmHudProgress, AgmSlider } from 'augma'
import { shallowRef } from 'vue'

const value = shallowRef(72)
</script>

<template>
  <div class="example-stack">
    <AgmHudProgress label="同步完成" :value="value" variant="ring" />
    <AgmHudProgress label="数据同步" :value="value" />
    <AgmSlider v-model="value" label="调整示例进度" />
    <AgmHudProgress label="正在连接" />
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
