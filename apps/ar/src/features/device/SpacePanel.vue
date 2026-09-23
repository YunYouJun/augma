<script setup lang="ts">
import type { Landmark, SceneId } from './types'
import { AgmButton, AgmHudProgress, AgmHudStatus } from 'augma'
import DeviceIcon from './DeviceIcon.vue'
import { scenes } from './types'

defineProps<{ scene: SceneId, selected: Landmark, scanning: boolean, progress: number, pinned: boolean, online: boolean }>()
const emit = defineEmits<{ scan: [], cancel: [], pin: [], navigate: [], scene: [id: SceneId] }>()
</script>

<template>
  <div class="feature-body">
    <div class="segmented-control" aria-label="模拟场景">
      <button v-for="item in scenes" :key="item.id" type="button" :aria-pressed="scene === item.id" :disabled="!online" @click="emit('scene', item.id)">{{ item.name }}</button>
    </div>
    <div class="space-calibration">
      <div class="calibration-orbit" aria-hidden="true" />
      <AgmHudProgress label="空间扫描" :value="progress" variant="ring" />
    </div>
    <div class="feature-status" aria-live="polite">
      <AgmHudStatus :tone="progress === 100 ? 'success' : 'neutral'">
        {{ scanning ? '正在识别模拟空间' : progress === 100 ? '已识别 3 个空间锚点' : '空间感知，等待开启' }}
      </AgmHudStatus>
    </div>
    <p class="feature-description">扫描当前场景，将地点化为视界中的锚点。</p>
    <AgmButton v-if="scanning" variant="outline" class="full-button" @click="emit('cancel')">取消扫描</AgmButton>
    <AgmButton v-else class="full-button" :disabled="!online" @click="emit('scan')"><DeviceIcon name="space" />{{ progress === 100 ? '重新扫描空间' : '扫描空间' }}</AgmButton>
    <button class="pin-control" type="button" :disabled="!online || progress !== 100" :aria-pressed="pinned" @click="emit('pin')"><DeviceIcon name="pin" />{{ pinned ? '释放空间锚点' : '固定空间锚点' }}</button>
    <div class="selected-place">
      <span class="muted-label">当前锚点</span>
      <h3>{{ selected.name }} <small>{{ selected.distance }} m</small></h3>
      <p>{{ selected.description }}</p>
      <AgmButton variant="outline" class="full-button" :disabled="!online" @click="emit('navigate')">导航到这里<DeviceIcon name="arrow" /></AgmButton>
    </div>
  </div>
</template>

<style scoped>
.space-calibration { position: relative; display: grid; place-items: center; padding: 24px 0 20px; }
.calibration-orbit { position: absolute; width: 158px; height: 158px; border: 1px dashed var(--agm-border); border-radius: 50%; }
.feature-status { text-align: center; font-size: 12px; }
.pin-control { display: flex; align-items: center; justify-content: center; gap: 8px; width: 100%; min-height: 44px; margin-top: 8px; border: 0; background: transparent; color: var(--agm-muted); font: inherit; font-size: 12px; cursor: pointer; }
.pin-control svg { width: 16px; height: 16px; }
.pin-control[aria-pressed='true'] { color: var(--agm-accent); }
.pin-control:disabled { opacity: .5; cursor: not-allowed; }
.selected-place { margin-top: 14px; padding-top: 18px; border-top: 1px solid var(--agm-border); }
.selected-place h3 { font-size: 18px; font-weight: 500; margin: 8px 0; display: flex; align-items: center; justify-content: space-between; }
.selected-place small { color: var(--agm-muted); font-size: 12px; font-weight: 400; }
.selected-place p { margin: 0 0 18px; font-size: 12px; line-height: 1.8; color: var(--agm-muted); }
</style>
