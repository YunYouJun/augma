<template>
  <button
    class="agm-button"
    :class="classes"
    @click="handleClick"
  >
    <slot />
  </button>
</template>

<script lang="ts" setup>
import { computed } from 'vue'
import './index.scss'
import type { AgmColorType } from '@augma/shared'

const props = withDefaults(defineProps<{
  color?: string
  icon?: boolean
  type?: AgmColorType
  plain?: boolean
  outline?: boolean
  onClick?: () => void
}>(), {
  color: '',
  icon: false,
  plain: false,
  outline: false,
})

const emit = defineEmits(['click'])

const handleClick = (evt: MouseEvent) => {
  emit('click', evt)
}

const classes = computed(() => {
  const btnClasses = [
    props.icon && 'agm-button--icon',
    props.type && `agm-button--${props.type}`,
    props.outline && 'is-outline',
  ]
  const colorClasses = []
  if (props.color) {
    colorClasses.push(`shadow-${props.color}-500`)
    if (props.plain) {
      colorClasses.push('bg-white')
      colorClasses.push('shadow-md')
      colorClasses.push(`text-${props.color}-500`)
    }
    else {
      colorClasses.push(`bg-${props.color}-500`)
      colorClasses.push(`text-${props.color}-100`)
    }
  }
  return btnClasses.concat(colorClasses)
})
</script>
