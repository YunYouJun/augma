<script setup lang="ts">
import { AgmHudStatus } from 'augma'
</script>

<template>
  <div class="example-row">
    <AgmHudStatus>已连接</AgmHudStatus>
    <AgmHudStatus tone="warning">等待连接</AgmHudStatus>
    <AgmHudStatus tone="danger">连接中断</AgmHudStatus>
    <AgmHudStatus tone="neutral">未连接</AgmHudStatus>
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
