<script setup lang="ts">
import { AgmButton, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const destination = shallowRef<string>()
const submitted = shallowRef(false)
const options = [
  { label: '集中モード', value: 'focus' },
  { label: '探索モード', value: 'explore' },
  { label: '使用できないモード', value: 'locked', disabled: true },
]
</script>

<template>
  <div class="example-stack">
    <AgmSelect v-model="mode" label="表示モード" hint="今のシーンに合った情報量を選びます。" :options="options" />
    <output>選択中：{{ mode }}</output>
    <AgmSelect
      v-model="destination"
      label="起動モード"
      hint="起動する前に、利用できるモードを選んでください。"
      placeholder="モードを選択"
      :error="submitted && !destination ? '起動モードを選んでください' : undefined"
      :options="options"
      required
    />
    <AgmButton variant="outline" @click="submitted = true">起動モードを確定</AgmButton>
    <output v-if="submitted && destination" role="status">起動モードを確定しました。</output>
    <AgmSelect label="使用できないセレクト" placeholder="モードを選択" :options="options" disabled />
  </div>
</template>

<style scoped>
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
