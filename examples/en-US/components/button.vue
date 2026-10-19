<script setup lang="ts">
import { AgmButton } from 'augma'
import { shallowRef } from 'vue'

const count = shallowRef(0)
</script>

<template>
  <div class="example-row">
    <AgmButton @click="count++">Connect device</AgmButton>
    <AgmButton variant="outline" @click="count++">Secondary action</AgmButton>
    <AgmButton variant="ghost" @click="count++">Subtle action</AgmButton>
    <AgmButton loading>Loading</AgmButton>
    <AgmButton disabled>Unavailable</AgmButton>
    <output aria-live="polite">Clicks: {{ count }}</output>
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
