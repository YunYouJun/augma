<script setup lang="ts">
import type { StyleValue } from 'vue'
import {
  SelectContent,
  SelectItem,
  SelectItemIndicator,
  SelectItemText,
  SelectPortal,
  SelectRoot,
  SelectTrigger,
  SelectValue,
  SelectViewport,
} from 'reka-ui'
import { computed, useAttrs, useId } from 'vue'

defineOptions({ inheritAttrs: false })
const props = withDefaults(
  defineProps<{
    id?: string
    label: string
    hint?: string
    error?: string
    options: { label: string, value: string, disabled?: boolean }[]
    placeholder?: string
    disabled?: boolean
    name?: string
    required?: boolean
  }>(),
  { placeholder: '请选择' },
)
const model = defineModel<string>()
const fallbackId = useId()
const id = computed(() => props.id ?? fallbackId)
const attrs = useAttrs()
function triggerAttrs() {
  return Object.fromEntries(Object.entries(attrs).filter(([key]) => key !== 'class' && key !== 'style'))
}
</script>

<template>
  <div class="agm-field" :class="$attrs.class" :style="$attrs.style as StyleValue">
    <label :id="`${id}-label`" :for="id" class="agm-field-label">{{ label }}</label>
    <SelectRoot v-model="model" :disabled="disabled" :name="name" :required="required">
      <SelectTrigger
        v-bind="triggerAttrs()"
        :id="id"
        class="agm-select"
        :aria-labelledby="`${id}-label`"
        :aria-invalid="!!error"
        :aria-required="required || undefined"
        :aria-describedby="[$attrs['aria-describedby'], hint ? `${id}-hint` : undefined, error ? `${id}-error` : undefined].filter(Boolean).join(' ') || undefined"
      >
        <SelectValue :placeholder="placeholder" />
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path d="m6 9 6 6 6-6" />
        </svg>
      </SelectTrigger>
      <SelectPortal>
        <SelectContent
          class="agm-select-content"
          position="popper"
          :side-offset="6"
        >
          <SelectViewport>
            <SelectItem
              v-for="option in options"
              :key="option.value"
              :value="option.value"
              :disabled="option.disabled"
              class="agm-select-item"
            >
              <SelectItemText>{{ option.label }}</SelectItemText>
              <SelectItemIndicator aria-hidden="true">✓</SelectItemIndicator>
            </SelectItem>
          </SelectViewport>
        </SelectContent>
      </SelectPortal>
    </SelectRoot>
    <span v-if="hint" :id="`${id}-hint`" class="agm-field-hint">{{ hint }}</span>
    <span v-if="error" :id="`${id}-error`" class="agm-field-error">{{ error }}</span>
  </div>
</template>
