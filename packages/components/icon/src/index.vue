<script setup lang="ts">
import { computed } from 'vue'
import './index.scss'
import { getAgmColorByType } from '@augma/utils'

const props = withDefaults(defineProps<{
  /**
   * 图标 Class 名称，通过 unocss 实现
   */
  name?: string
  icon?: string
  color?: string
  size?: string
  svg?: string
}>(), {
  icon: '',
  color: '',
  size: '',
})

const styles = computed(() => {
  return {
    color: getAgmColorByType(props.color) || 'inherit',
    fontSize: props.size,
  }
})
</script>

<template>
  <div class="agm-icon" :class="name" :style="styles">
    <span v-if="svg" v-html="svg" />
    <component :is="icon" v-if="icon" />
    <slot />
  </div>
</template>
