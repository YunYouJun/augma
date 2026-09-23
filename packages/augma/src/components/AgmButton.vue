<script setup lang="ts">
withDefaults(
  defineProps<{
    variant?: 'primary' | 'outline' | 'ghost'
    disabled?: boolean
    loading?: boolean
    type?: 'button' | 'submit' | 'reset'
  }>(),
  { variant: 'primary', type: 'button' },
)
</script>

<template>
  <button
    :type="type"
    class="agm-button"
    :class="`agm-button--${variant}`"
    :disabled="disabled || loading"
    :aria-busy="loading || undefined"
  >
    <span v-if="loading" class="agm-spinner" aria-hidden="true" />
    <slot />
  </button>
</template>
