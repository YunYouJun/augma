<script setup lang="ts">
import { AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="Mission status" class="hud-example">
    <div>
      <AgmHudStatus>Interface ready</AgmHudStatus>
      <AgmHudStatus tone="warning">Awaiting permission</AgmHudStatus>
      <AgmHudStatus tone="danger">Device offline</AgmHudStatus>
    </div>
    <AgmHudProgress label="Loading assets" :value="72" variant="ring" />
    <AgmHudProgress label="Waiting for a device" indeterminate-text="In progress" />
    <p>Sample states only. Nothing here accesses a device or asks for permission.</p>
  </AgmPanel>
</template>

<style scoped>
.hud-example {
  display: grid;
  justify-items: center;
  gap: 24px;
  width: 100%;
}
.hud-example > div:first-of-type {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
}
.hud-example > .agm-progress:not(.agm-progress--ring) {
  width: 100%;
}
p {
  color: var(--agm-muted);
  font-size: 13px;
}
</style>
