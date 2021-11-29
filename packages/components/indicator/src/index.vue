<template>
  <div class="agm-indicator" :style="styles">
    <h2 class="agm-indicator__title">
      {{ title }}
    </h2>
    <div class="agm-indicator__info">
      {{ info }}
    </div>
    <div class="agm-indicator__cursor" />
  </div>
</template>

<script lang="ts" setup>
import { getAgmColorByType } from '@augma/shared'
import './index.scss'

const props = withDefaults(defineProps<{
  title?: string
  info?: string
  color?: string
}>(), {
  title: 'Asuna',
  info: '318',
  color: '',
})

const styles = computed(() => {
  return {
    color: getAgmColorByType(props.color),
  }
})
</script>
