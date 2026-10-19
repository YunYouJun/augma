<script setup lang="ts">
import { AgmButton, AgmDialog, AgmInput, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const open = shallowRef(false)
const name = shallowRef('Augma')
const mode = shallowRef('focus')
</script>

<template>
  <AgmDialog
    v-model:open="open"
    title="Device settings"
    description="Rename the device, then close the dialog to keep browsing."
  >
    <template #trigger>
      <AgmButton variant="outline">Open settings</AgmButton>
    </template>
    <div class="example-stack">
      <AgmInput v-model="name" label="Device name" />
      <AgmSelect v-model="mode" label="Display mode" :options="[{ label: 'Focus', value: 'focus' }, { label: 'Explore', value: 'explore' }]" />
    </div>
    <template #footer>
      <AgmButton @click="open = false">Done</AgmButton>
    </template>
  </AgmDialog>
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
