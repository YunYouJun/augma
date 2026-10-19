<script setup lang="ts">
import { AgmInput } from 'augma'
import { shallowRef } from 'vue'

const name = shallowRef('Augma')
</script>

<template>
  <div class="example-stack">
    <AgmInput
      v-model="name"
      label="Device name"
      hint="Identifies this device in the device list."
      placeholder="Enter a device name"
      :error="name.trim() ? undefined : 'A device name is required'"
    />
    <AgmInput label="Device ID" model-value="AGM-001" disabled />
    <output>Current name: {{ name || 'Not set' }}</output>
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
