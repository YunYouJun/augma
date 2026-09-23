<script setup lang="ts">
import { mdiIcons } from './mdi-icons'

defineProps<{ name: string }>()
</script>

<template>
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path :d="mdiIcons[name] || mdiIcons.space" />
  </svg>
</template>
