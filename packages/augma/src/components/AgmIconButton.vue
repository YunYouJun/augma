<script setup lang="ts">
withDefaults(
  defineProps<{ label: string, disabled?: boolean, pressed?: boolean }>(),
  { pressed: undefined },
)
</script>

<template>
  <button
    type="button"
    class="agm-icon-button"
    :aria-label="label"
    :disabled="disabled"
    :aria-pressed="pressed"
  >
    <slot>
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        aria-hidden="true"
      >
        <path d="M12 4v16M4 12h16" />
      </svg>
    </slot>
  </button>
</template>
