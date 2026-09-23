<script setup lang="ts">
withDefaults(
  defineProps<{ tone?: 'success' | 'warning' | 'danger' | 'neutral' }>(),
  { tone: 'success' },
)
</script>

<template>
  <span class="agm-status" :data-tone="tone" role="status">
    <span class="agm-status-dot" aria-hidden="true" />
    <slot />
  </span>
</template>
