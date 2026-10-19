<script setup lang="ts">
import { AgmInput } from 'augma'
import { shallowRef } from 'vue'

const name = shallowRef('Augma')
</script>

<template>
  <div class="example-stack">
    <AgmInput
      v-model="name"
      label="デバイス名"
      hint="デバイス一覧でこのデバイスを見分けるために使います。"
      placeholder="デバイス名を入力"
      :error="name.trim() ? undefined : 'デバイス名を入力してください'"
    />
    <AgmInput label="デバイス ID" model-value="AGM-001" disabled />
    <output>現在の名前：{{ name || '未入力' }}</output>
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
