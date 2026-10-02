<script setup lang="ts">
defineProps<{ title?: string, description?: string }>()
</script>

<template>
  <section class="agm-panel">
    <header v-if="title || description || $slots.header || $slots.actions" class="agm-panel-heading">
      <div v-if="title || description || $slots.header" class="agm-panel-heading-content">
        <slot name="header">
          <h2 v-if="title" class="agm-panel-title">{{ title }}</h2>
          <p v-if="description" class="agm-panel-description">{{ description }}</p>
        </slot>
      </div>
      <slot name="actions" />
    </header>
    <slot />
    <footer v-if="$slots.footer" class="agm-panel-footer">
      <slot name="footer" />
    </footer>
  </section>
</template>
