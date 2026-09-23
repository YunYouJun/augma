<script setup lang="ts">
import { SwitchRoot, SwitchThumb } from 'reka-ui'
import { useId } from 'vue'

defineProps<{ label: string, disabled?: boolean, name?: string }>()
const model = defineModel<boolean>({ default: false })
const id = useId()
</script>

<template>
  <div class="agm-switch-field">
    <label :for="id">{{ label }}</label>
    <SwitchRoot
      :id="id"
      v-model="model"
      class="agm-switch"
      :disabled="disabled"
      :name="name"
    >
      <SwitchThumb class="agm-switch-thumb" />
    </SwitchRoot>
  </div>
</template>
