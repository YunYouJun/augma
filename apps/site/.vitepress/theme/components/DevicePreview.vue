<script setup lang="ts">
import {
  AgmButton,
  AgmDialog,
  AgmHudProgress,
  AgmHudStatus,
  AgmIconButton,
  AgmPanel,
  AgmSlider,
  AgmSwitch,
} from 'augma'
import { shallowRef } from 'vue'
import UiIcon from './UiIcon.vue'

const progress = shallowRef(72)
const bright = shallowRef(false)
const sound = shallowRef(true)
const spatial = shallowRef(false)
const open = shallowRef(false)
</script>

<template>
  <div class="device-stage" :class="{ 'is-spatial': spatial }">
    <div class="orbit orbit-one" aria-hidden="true" />
    <div class="orbit orbit-two" aria-hidden="true" />
    <AgmPanel
      class="device-panel"
      title="设备连接"
      :style="{ '--device-opacity': bright ? '1' : '.88' }"
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
      <AgmHudProgress label="数据同步演示" :value="progress" />
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
