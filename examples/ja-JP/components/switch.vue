<script setup lang="ts">
import { AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

const enabled = shallowRef(true)
</script>

<template>
  <div class="example-stack">
    <AgmSwitch v-model="enabled" label="HUD を表示" />
    <output>{{ enabled ? 'HUD オン' : 'HUD オフ' }}</output>
    <AgmSwitch label="使用できないスイッチ" disabled />
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
