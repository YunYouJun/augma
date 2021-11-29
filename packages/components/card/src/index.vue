<template>
  <div :class="classes">
    <div class="agm-card--header">
      <slot name="header" />
    </div>
    <div class="agm-card--body">
      <slot />
    </div>
  </div>
</template>

<script lang="ts" setup>
import './index.scss'

const props = withDefaults(defineProps<{
  dark?: boolean
  type?: string
}>(), {
  dark: false,
  type: '',
})

const classes = computed(() => {
  return [
    'agm-card',
    props.type ? `agm-card--${props.type}` : '',
    props.dark ? 'is-dark' : '',
  ]
})
</script>
