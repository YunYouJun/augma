<script setup lang="ts">
import { AgmIconButton } from 'augma'
import { shallowRef } from 'vue'

const active = shallowRef(false)
</script>

<template>
  <div class="example-row">
    <AgmIconButton
      label="マーカーを切り替え"
      :pressed="active"
      @click="active = !active"
    />
    <span>{{ active ? 'マーク済み' : '未マーク' }}</span>
    <AgmIconButton label="使用できない操作" disabled />
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
