<script setup lang="ts">
import { AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

const enabled = shallowRef(true)
</script>

<template>
  <div class="example-stack">
    <AgmSwitch v-model="enabled" label="显示 HUD" />
    <output>{{ enabled ? 'HUD 已开启' : 'HUD 已关闭' }}</output>
    <AgmSwitch label="不可用开关" disabled />
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
