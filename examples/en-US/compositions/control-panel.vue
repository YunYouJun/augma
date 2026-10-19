<script setup lang="ts">
import { AgmButton, AgmPanel, AgmSelect, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const enabled = shallowRef(true)
const opacity = shallowRef(80)
const options = [
  { label: 'Focus', value: 'focus' },
  { label: 'Explore', value: 'explore' },
]
function reset() {
  mode.value = 'focus'
  enabled.value = true
  opacity.value = 80
}
</script>

<template>
  <AgmPanel title="Control panel" class="control-example">
    <AgmSelect v-model="mode" label="Scene mode" :options="options" />
    <AgmSwitch v-model="enabled" label="Show navigation" />
    <AgmSlider v-model="opacity" label="Navigation opacity" :min="30" />
    <output>
      Current: {{ mode === 'focus' ? 'Focus' : 'Explore' }} · Navigation {{
        enabled ? 'on' : 'off'
      }}
      · {{ opacity }}%
    </output>
    <AgmButton variant="outline" @click="reset">Restore default settings</AgmButton>
  </AgmPanel>
</template>

<style scoped>
.control-example {
  display: grid;
  gap: 20px;
  width: 100%;
  max-width: 420px;
}
output {
  color: var(--agm-muted);
  font-size: 13px;
}
</style>
