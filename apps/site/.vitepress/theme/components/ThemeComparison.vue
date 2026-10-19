<script setup lang="ts">
import { useI18n } from '../i18n'
import ThemeSample from './ThemeSample.vue'

const { t } = useI18n()
</script>

<template>
  <div class="theme-comparison">
    <ThemeSample theme="light" :label="t('theme.light')" />
    <ThemeSample theme="dark" :label="t('theme.dark')" />
  </div>
</template>

<style scoped>
.theme-comparison { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin: 28px 0; }
@media (max-width: 640px) { .theme-comparison { grid-template-columns: 1fr; } }
</style>
