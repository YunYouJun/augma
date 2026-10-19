<script setup lang="ts">
import { AgmButton } from 'augma'
import { shallowRef } from 'vue'

const count = shallowRef(0)
</script>

<template>
  <div class="example-row">
    <AgmButton @click="count++">デバイスを接続</AgmButton>
    <AgmButton variant="outline" @click="count++">サブアクション</AgmButton>
    <AgmButton variant="ghost" @click="count++">控えめなアクション</AgmButton>
    <AgmButton loading>読み込み中</AgmButton>
    <AgmButton disabled>使用不可</AgmButton>
    <output aria-live="polite">{{ count }} 回操作しました</output>
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
