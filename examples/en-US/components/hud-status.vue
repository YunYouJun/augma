<script setup lang="ts">
import { AgmHudStatus } from 'augma'
</script>

<template>
  <div class="example-row">
    <AgmHudStatus>Connected</AgmHudStatus>
    <AgmHudStatus tone="warning">Waiting to connect</AgmHudStatus>
    <AgmHudStatus tone="danger">Connection lost</AgmHudStatus>
    <AgmHudStatus tone="neutral">Not connected</AgmHudStatus>
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
