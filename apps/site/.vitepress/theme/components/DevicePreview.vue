<script setup lang="ts">
import {
  AgmButton,
  AgmDialog,
  AgmHudGauge,
  AgmHudProgress,
  AgmHudStatus,
  AgmIconButton,
  AgmPanel,
  AgmSlider,
  AgmSwitch,
} from 'augma'
import { onUnmounted, shallowRef, useTemplateRef } from 'vue'
import HudOrbit from './HudOrbit.vue'
import UiIcon from './UiIcon.vue'

const progress = shallowRef(72)
const energy = shallowRef(86)
const bright = shallowRef(false)
const sound = shallowRef(true)
const spatial = shallowRef(false)
const open = shallowRef(false)

// Pointer tilt writes CSS variables once per frame instead of updating Vue state.
const stage = useTemplateRef<HTMLElement>('stage')
let frame = 0
function tilt(event: PointerEvent) {
  if (event.pointerType !== 'mouse' || matchMedia('(prefers-reduced-motion: reduce)').matches)
    return
  const { clientX, clientY } = event
  cancelAnimationFrame(frame)
  frame = requestAnimationFrame(() => {
    const el = stage.value
    if (!el)
      return
    const rect = el.getBoundingClientRect()
    el.style.setProperty('--tilt-x', (((clientX - rect.left) / rect.width) * 2 - 1).toFixed(3))
    el.style.setProperty('--tilt-y', (((clientY - rect.top) / rect.height) * 2 - 1).toFixed(3))
  })
}
function settle() {
  cancelAnimationFrame(frame)
  stage.value?.style.removeProperty('--tilt-x')
  stage.value?.style.removeProperty('--tilt-y')
}
onUnmounted(() => cancelAnimationFrame(frame))
</script>

<template>
  <div
    ref="stage"
    class="device-stage"
    :class="{ 'is-spatial': spatial }"
    @pointermove="tilt"
    @pointerleave="settle"
  >
    <HudOrbit />
    <AgmPanel
      class="device-panel agm-materialize"
      title="设备连接"
      :style="{ '--device-opacity': bright ? '1' : '.88', '--agm-delay': '260ms' }"
    >
      <template #header>
        <div class="device-title">
          <UiIcon name="link" />
          <h2>设备连接</h2>
        </div>
      </template>
      <div class="device-overview">
        <div>
          <div class="device-preview-label">界面预览</div>
          <AgmHudStatus>交互已就绪</AgmHudStatus>
          <p>试着调整你的视界。</p>
        </div>
        <AgmHudProgress label="示例进度" :value="progress" variant="ring" />
      </div>
      <AgmHudGauge label="示例电量" :value="energy" />
      <div class="device-controls">
        <div>
          <AgmIconButton
            label="切换亮度"
            :pressed="bright"
            @click="bright = !bright"
          >
            <UiIcon name="sun" />
          </AgmIconButton>
          <span>亮度</span>
        </div>
        <div>
          <AgmIconButton
            label="切换声音状态"
            :pressed="sound"
            @click="sound = !sound"
          >
            <UiIcon name="volume" />
          </AgmIconButton>
          <span>{{ sound ? '声音开启' : '声音关闭' }}</span>
        </div>
        <div>
          <AgmIconButton
            label="切换空间模式"
            :pressed="spatial"
            @click="spatial = !spatial"
          >
            <UiIcon name="scan" />
          </AgmIconButton>
          <span>空间模式</span>
        </div>
      </div>
      <AgmDialog
        v-model:open="open"
        title="调整界面"
        description="即时预览组件状态，找到适合你的显示方式。"
      >
        <template #trigger>
          <AgmButton variant="outline" class="device-settings">
            <UiIcon name="settings" />
            调整界面
          </AgmButton>
        </template>
        <div class="settings-fields">
          <AgmSlider v-model="progress" label="示例进度" />
          <AgmSlider v-model="energy" label="示例电量" />
          <AgmSwitch v-model="bright" label="明亮面板" />
          <AgmSwitch v-model="spatial" label="空间模式" />
        </div>
        <template #footer>
          <AgmButton @click="open = false">完成</AgmButton>
        </template>
      </AgmDialog>
    </AgmPanel>
  </div>
</template>
