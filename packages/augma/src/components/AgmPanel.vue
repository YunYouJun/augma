<script setup lang="ts">
defineProps<{ title?: string }>()
</script>

<template>
  <section class="agm-panel">
    <header v-if="title || $slots.header" class="agm-panel-heading">
      <slot name="header">
        <h2 class="agm-panel-title">{{ title }}</h2>
      </slot>
      <slot name="actions" />
    </header>
    <slot />
  </section>
</template>
