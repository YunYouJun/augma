<script lang="ts" setup>
import { computed } from 'vue'
import './index.scss'
import type { AgmColorType } from '@augma/utils'

const props = withDefaults(defineProps<{
  color?: string
  icon?: boolean
  type?: AgmColorType
  plain?: boolean
  onClick?: () => void
}>(), {
  color: '',
  icon: false,
  plain: false,
})

const emit = defineEmits(['click'])

function handleClick(evt: MouseEvent) {
  emit('click', evt)
}

const classes = computed(() => {
  const btnClasses = [
    props.icon && 'agm-button--icon',
    props.type && `agm-button--${props.type}`,
  ]
  const colorClasses = []
  if (props.color) {
    if (props.plain) {
      colorClasses.push('bg-white')
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

<template>
  <button
    class="agm-button agm-shadow"
    :class="classes"
    @click="handleClick"
  >
    <slot />
  </button>
</template>
