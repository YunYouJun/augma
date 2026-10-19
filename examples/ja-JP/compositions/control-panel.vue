<script setup lang="ts">
import { AgmButton, AgmPanel, AgmSelect, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const enabled = shallowRef(true)
const opacity = shallowRef(80)
const options = [
  { label: '集中', value: 'focus' },
  { label: '探索', value: 'explore' },
]
function reset() {
  mode.value = 'focus'
  enabled.value = true
  opacity.value = 80
}
</script>

<template>
  <AgmPanel title="コントロールパネル" class="control-example">
    <AgmSelect v-model="mode" label="シーンモード" :options="options" />
    <AgmSwitch v-model="enabled" label="ナビゲーションを表示" />
    <AgmSlider v-model="opacity" label="ナビゲーションの不透明度" :min="30" />
    <output>
      現在：{{ mode === 'focus' ? '集中' : '探索' }} · ナビゲーション{{
        enabled ? 'オン' : 'オフ'
      }}
      · {{ opacity }}%
    </output>
    <AgmButton variant="outline" @click="reset">初期設定に戻す</AgmButton>
  </AgmPanel>
</template>

<style scoped>
.control-example {
  display: grid;
  gap: 20px;
  width: 100%;
  max-width: 420px;
}
output {
  color: var(--agm-muted);
  font-size: 13px;
}
</style>
