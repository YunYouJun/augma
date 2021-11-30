<template>
  <button aria-label="Toggle Theme" class="icon-button" @click="()=>{toggleDark()}">
    <i-ri-moon-line v-show="isDark" />
    <i-ri-sun-line v-show="!isDark" />
  </button>
</template>

<script setup lang='ts'>
import { isDark, toggleDark } from '../composables/dark'
</script>
