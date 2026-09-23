<script setup lang="ts">
import { AgmButton, AgmTooltip } from 'augma'
</script>

<template>
  <AgmTooltip text="恢复默认的显示参数">
    <AgmButton variant="outline">恢复默认</AgmButton>
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
