<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    label: string
    value?: number
    max?: number
    variant?: 'bar' | 'ring'
  }>(),
  { max: 100, variant: 'bar' },
)
const upper = computed(() =>
  Number.isFinite(props.max) && props.max > 0 ? props.max : 100,
)
const current = computed(() =>
  props.value === undefined || !Number.isFinite(props.value)
    ? undefined
    : Math.min(upper.value, Math.max(0, props.value)),
)
const percent = computed(() =>
  current.value === undefined
    ? undefined
    : Math.round((current.value / upper.value) * 100),
)
</script>

<template>
  <div
    class="agm-progress"
    :class="{ 'agm-progress--ring': variant === 'ring' }"
    :data-indeterminate="current === undefined"
    role="progressbar"
    :aria-label="label"
    :aria-valuemin="0"
    :aria-valuemax="upper"
    :aria-valuenow="current"
  >
    <template v-if="variant === 'ring'">
      <svg class="agm-progress-ring" viewBox="0 0 100 100" aria-hidden="true">
        <circle class="track" cx="50" cy="50" r="46" />
        <circle
          class="value"
          cx="50"
          cy="50"
          r="46"
          :stroke-dashoffset="289.03 * (1 - (percent ?? 25) / 100)"
        />
      </svg>
      <span class="agm-progress-ring-text">
        <strong>{{ percent === undefined ? '…' : `${percent}%` }}</strong>
        <small>{{ label }}</small>
      </span>
    </template>
    <template v-else>
      <div class="agm-progress-label">
        <span>{{ label }}</span>
        <span>{{ percent === undefined ? '进行中' : `${percent}%` }}</span>
      </div>
      <div class="agm-progress-track">
        <span
          class="agm-progress-fill"
          :style="current !== undefined ? { width: `${percent}%` } : undefined"
        />
      </div>
    </template>
  </div>
</template>
