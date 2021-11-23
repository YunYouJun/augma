<template>
  <div :class="classes">
    <div class="agm-card--header">
      <slot name="header"></slot>
    </div>
    <div class="agm-card--body">
      <slot></slot>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import './index.scss'

export default defineComponent({
  name: 'AgmCard',
  props: {
    dark: {
      type: Boolean,
      default: false,
    },
    type: {
      type: String,
      default: '',
    },
  },
  computed: {
    classes(): string[] {
      return [
        'agm-card',
        this.type ? `agm-card--${this.type}` : '',
        this.dark ? 'is-dark' : '',
      ]
    },
  },
})
</script>
