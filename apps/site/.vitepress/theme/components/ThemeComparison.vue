<script setup lang="ts">
import ThemeSample from './ThemeSample.vue'
</script>

<template>
  <div class="theme-comparison">
    <ThemeSample theme="light" label="浅色" />
    <ThemeSample theme="dark" label="深色" />
  </div>
</template>

<style scoped>
.theme-comparison { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin: 28px 0; }
@media (max-width: 640px) { .theme-comparison { grid-template-columns: 1fr; } }
</style>
