<script setup lang="ts">
import { AgmButton, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const destination = shallowRef<string>()
const submitted = shallowRef(false)
const options = [
  { label: 'Focus mode', value: 'focus' },
  { label: 'Explore mode', value: 'explore' },
  { label: 'Unavailable mode', value: 'locked', disabled: true },
]
</script>

<template>
  <div class="example-stack">
    <AgmSelect v-model="mode" label="Display mode" hint="Choose how much information the current scene shows." :options="options" />
    <output>Selected: {{ mode }}</output>
    <AgmSelect
      v-model="destination"
      label="Launch mode"
      hint="Choose an available mode before launching."
      placeholder="Select a mode"
      :error="submitted && !destination ? 'Choose a launch mode' : undefined"
      :options="options"
      required
    />
    <AgmButton variant="outline" @click="submitted = true">Confirm launch mode</AgmButton>
    <output v-if="submitted && destination" role="status">Launch mode confirmed.</output>
    <AgmSelect label="Unavailable select" placeholder="Select a mode" :options="options" disabled />
  </div>
</template>

<style scoped>
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
