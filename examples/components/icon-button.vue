<script setup lang="ts">
import { AgmIconButton } from 'augma'
import { shallowRef } from 'vue'

const active = shallowRef(false)
</script>

<template>
  <div class="example-row">
    <AgmIconButton
      label="切换标记"
      :pressed="active"
      @click="active = !active"
    />
    <span>{{ active ? '已标记' : '未标记' }}</span>
    <AgmIconButton label="不可用操作" disabled />
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
