<script setup lang="ts">
import { computed, useId } from 'vue'

defineOptions({ inheritAttrs: false })
const props = withDefaults(
  defineProps<{
    id?: string
    label: string
    error?: string
    disabled?: boolean
    type?: string
  }>(),
  { type: 'text' },
)
const model = defineModel<string>({ default: '' })
const fallbackId = useId()
const resolvedId = computed(() => props.id ?? fallbackId)
</script>

<template>
  <div class="agm-field">
    <label :for="resolvedId" class="agm-field-label">{{ label }}</label>
    <input
      :id="resolvedId"
      v-model="model"
      v-bind="$attrs"
      class="agm-input"
      :type="type"
      :disabled="disabled"
      :aria-invalid="!!error"
      :aria-describedby="[$attrs['aria-describedby'], error ? `${resolvedId}-error` : undefined].filter(Boolean).join(' ') || undefined"
    />
    <span v-if="error" :id="`${resolvedId}-error`" class="agm-field-error">
      {{ error }}
    </span>
  </div>
</template>
