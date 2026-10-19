<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    label: string
    value: number
    max?: number
  }>(),
  { max: 100 },
)
const upper = computed(() =>
  Number.isFinite(props.max) && props.max > 0 ? props.max : 100,
)
const current = computed(() =>
  Number.isFinite(props.value)
    ? Math.min(upper.value, Math.max(0, props.value))
    : 0,
)
const ratio = computed(() => current.value / upper.value)
// Color follows the remaining share; the numeric readout always carries the value.
const tone = computed(() =>
  ratio.value <= 0.2 ? 'danger' : ratio.value <= 0.5 ? 'warning' : 'success',
)
const shown = computed(() => Math.round(current.value))
</script>

<template>
  <div
    class="agm-gauge"
    :data-tone="tone"
    role="meter"
    :aria-label="label"
    :aria-valuemin="0"
    :aria-valuemax="upper"
    :aria-valuenow="current"
    :aria-valuetext="`${shown} / ${upper}`"
    :style="{ '--agm-gauge-value': `${ratio * 100}%` }"
  >
    <div class="agm-gauge-header">
      <span class="agm-gauge-label">{{ label }}</span>
      <span class="agm-gauge-readout"><strong>{{ shown }}</strong> / {{ upper }}</span>
    </div>
    <div class="agm-gauge-bar" aria-hidden="true">
      <span class="agm-gauge-trail" />
      <span class="agm-gauge-fill" />
    </div>
  </div>
</template>
