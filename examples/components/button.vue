<script setup lang="ts">
import { AgmButton } from 'augma'
import { shallowRef } from 'vue'

const count = shallowRef(0)
</script>

<template>
  <div class="example-row">
    <AgmButton @click="count++">连接设备</AgmButton>
    <AgmButton variant="outline" @click="count++">次要操作</AgmButton>
    <AgmButton variant="ghost" @click="count++">轻量操作</AgmButton>
    <AgmButton loading>加载中</AgmButton>
    <AgmButton disabled>不可用</AgmButton>
    <output aria-live="polite">已操作 {{ count }} 次</output>
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
