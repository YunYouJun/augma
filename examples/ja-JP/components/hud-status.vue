<script setup lang="ts">
import { AgmHudStatus } from 'augma'
</script>

<template>
  <div class="example-row">
    <AgmHudStatus>接続済み</AgmHudStatus>
    <AgmHudStatus tone="warning">接続待ち</AgmHudStatus>
    <AgmHudStatus tone="danger">接続が切れました</AgmHudStatus>
    <AgmHudStatus tone="neutral">未接続</AgmHudStatus>
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
