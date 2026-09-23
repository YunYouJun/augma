<script setup lang="ts">
import { SliderRange, SliderRoot, SliderThumb, SliderTrack } from 'reka-ui'
import { computed, useId } from 'vue'

withDefaults(
  defineProps<{
    label: string
    min?: number
    max?: number
    step?: number
    disabled?: boolean
    name?: string
  }>(),
  { min: 0, max: 100, step: 1 },
)
const model = defineModel<number>({ default: 0 })
const values = computed({
  get: () => [model.value],
  set: (v: number[]) => {
    if (v[0] !== undefined)
      model.value = v[0]
  },
})
const id = useId()
</script>

<template>
  <div class="agm-field">
    <div class="agm-slider-label">
      <span :id="id">{{ label }}</span>
      <output>{{ model }}</output>
    </div>
    <SliderRoot
      v-model="values"
      class="agm-slider"
      :min="min"
      :max="max"
      :step="step"
      :disabled="disabled"
      :name="name"
    >
      <SliderTrack class="agm-slider-track">
        <SliderRange class="agm-slider-range" />
      </SliderTrack>
      <SliderThumb class="agm-slider-thumb" :aria-labelledby="id" />
    </SliderRoot>
  </div>
</template>
