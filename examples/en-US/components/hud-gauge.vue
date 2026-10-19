<script setup lang="ts">
import { AgmButton, AgmHudGauge } from 'augma'
import { shallowRef } from 'vue'

const battery = shallowRef(86)
</script>

<template>
  <div class="example-stack">
    <AgmHudGauge label="Device battery" :value="battery" />
    <AgmHudGauge label="Free storage" :value="12" :max="64" />
    <div class="example-row">
      <AgmButton variant="outline" :disabled="battery === 0" @click="battery = Math.max(0, battery - 18)">
        Simulate drain
      </AgmButton>
      <AgmButton variant="ghost" :disabled="battery === 100" @click="battery = 100">
        Charge fully
      </AgmButton>
    </div>
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
