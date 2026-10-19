<script setup lang="ts">
import { AgmButton, AgmTooltip } from 'augma'
</script>

<template>
  <AgmTooltip text="Restore the default display settings">
    <AgmButton variant="outline">Restore defaults</AgmButton>
  </AgmTooltip>
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
