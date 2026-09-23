<script setup lang="ts">
import { AgmButton, AgmPanel, AgmSelect, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const enabled = shallowRef(true)
const opacity = shallowRef(80)
const options = [
  { label: '专注', value: 'focus' },
  { label: '探索', value: 'explore' },
]
function reset() {
  mode.value = 'focus'
  enabled.value = true
  opacity.value = 80
}
</script>

<template>
  <AgmPanel title="控制面板" class="control-example">
    <AgmSelect v-model="mode" label="场景模式" :options="options" />
    <AgmSwitch v-model="enabled" label="显示导航" />
    <AgmSlider v-model="opacity" label="导航不透明度" :min="30" />
    <output>
      当前：{{ mode === 'focus' ? '专注' : '探索' }} · 导航{{
        enabled ? '开启' : '关闭'
      }}
      · {{ opacity }}%
    </output>
    <AgmButton variant="outline" @click="reset">恢复默认设置</AgmButton>
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
