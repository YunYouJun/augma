<script setup lang="ts">
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
import { useId } from 'vue'

withDefaults(
  defineProps<{
    label: string
    options: { label: string, value: string, disabled?: boolean }[]
    placeholder?: string
    disabled?: boolean
    name?: string
  }>(),
  { placeholder: '请选择' },
)
const model = defineModel<string>()
const id = useId()
</script>

<template>
  <div class="agm-field">
    <label :id="`${id}-label`" :for="id">{{ label }}</label>
    <SelectRoot v-model="model" :disabled="disabled" :name="name">
      <SelectTrigger
        :id="id"
        class="agm-select"
        :aria-labelledby="`${id}-label`"
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
  </div>
</template>
