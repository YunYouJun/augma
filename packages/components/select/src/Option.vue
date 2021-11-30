<template>
  <li class="agm-select-dropdown__item" @click.stop="selectOptionClick">
    <slot>
      <span>{{ label }}</span>
    </slot>
  </li>
</template>

<script lang="ts" setup>
import { useOption } from './useOption'

const props = withDefaults(defineProps<{
  disable?: boolean
  label: string
  value: string
}>(), {
  disable: false,
  label: '',
  value: '',
})

const { select } = useOption()

function selectOptionClick() {
  if (props.disable) return

  select.handleOptionSelect({
    label: props.label,
    value: props.value,
  })
}
</script>

<style lang="scss">
.agm-select-dropdown__item {
  display: block;
  padding: 0.5rem 0.8rem;
  &:hover {
    background: #f6f6f6;
  }
}
</style>
