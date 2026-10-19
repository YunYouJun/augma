<script setup lang="ts">
import { AgmButton, AgmDialog, AgmInput, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const open = shallowRef(false)
const name = shallowRef('Augma')
const mode = shallowRef('focus')
</script>

<template>
  <AgmDialog
    v-model:open="open"
    title="デバイス設定"
    description="デバイス名を変更して、閉じたら閲覧を続けられます。"
  >
    <template #trigger>
      <AgmButton variant="outline">設定を開く</AgmButton>
    </template>
    <div class="example-stack">
      <AgmInput v-model="name" label="デバイス名" />
      <AgmSelect v-model="mode" label="表示モード" :options="[{ label: '集中', value: 'focus' }, { label: '探索', value: 'explore' }]" />
    </div>
    <template #footer>
      <AgmButton @click="open = false">完了</AgmButton>
    </template>
  </AgmDialog>
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
