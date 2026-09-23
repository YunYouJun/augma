<script setup lang="ts">
import { AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="设备概览" style="width: 100%; max-width: 360px">
    <template #actions>
      <AgmHudStatus>就绪</AgmHudStatus>
    </template>
    <p>将重要信息轻轻放在视野之中。</p>
    <AgmHudProgress label="示例进度" :value="72" />
  </AgmPanel>
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
