<script setup lang="ts">
import type { DeviceModule } from './types'
import DeviceIcon from './DeviceIcon.vue'

defineProps<{ curved: boolean, active: DeviceModule | null, showHud: boolean, mirror: boolean }>()
const emit = defineEmits<{ select: [module: DeviceModule, trigger: HTMLElement], mirror: [], hud: [] }>()
const apps = [
  { id: 'weather', label: '天气', color: '#ed933d' },
  { id: 'audio', label: '声音', color: '#004d86' },
  { id: 'space', label: '空间', color: '#00959c' },
  { id: 'camera', label: '摄像头', color: '#4dade0' },
  { id: 'navigation', label: '导航', color: '#dd9d5e' },
] as const
</script>

<template>
  <nav class="device-dock" :class="{ 'is-curved': curved }" aria-label="设备应用">
    <svg v-if="curved" class="dock-arc" viewBox="0 0 1000 28" preserveAspectRatio="none" aria-hidden="true"><path d="M0 26 Q500 -22 1000 26" /></svg>
    <div class="dock-pointer" aria-hidden="true" />
    <div class="dock-scroll">
      <div class="dock-buttons">
        <button class="orb-button" type="button" aria-label="镜像画面" data-tooltip="镜像画面" :aria-pressed="mirror" style="--orb-color: #8dd3d6" @click="emit('mirror')"><DeviceIcon name="mirror" /></button>
        <template v-for="app in apps" :key="app.id">
          <button class="orb-button" type="button" :aria-label="app.label" :data-tooltip="app.label" :aria-pressed="active === app.id" :style="{ '--orb-color': app.color }" @click="emit('select', app.id, $event.currentTarget as HTMLElement)"><DeviceIcon :name="app.id" /></button>
          <button v-if="app.id === 'weather'" class="orb-button" type="button" role="switch" aria-label="显示 HUD" :data-tooltip="showHud ? '隐藏 HUD' : '恢复 HUD'" :aria-checked="showHud" style="--orb-color: #4dade0" @click="emit('hud')"><DeviceIcon :name="showHud ? 'eye' : 'eye-off'" /></button>
        </template>
        <a class="orb-button" href="https://github.com/YunYouJun/augma" target="_blank" rel="noreferrer" aria-label="GitHub" data-tooltip="GitHub" style="--orb-color: #343a40"><DeviceIcon name="github" /></a>
        <a class="orb-button" href="/components/" aria-label="组件文档" data-tooltip="组件文档" style="--orb-color: #4dade0"><DeviceIcon name="globe" /></a>
      </div>
    </div>
  </nav>
</template>

<style scoped>
.device-dock { position: fixed; z-index: 20; bottom: 0; left: 0; right: 0; height: 84px; border-top: 2px solid rgb(255 255 255 / 90%); }
.dock-pointer { position: absolute; left: calc(50% - 10px); top: 0; width: 0; height: 0; border: 10px solid transparent; border-top-color: rgb(255 255 255 / 90%); }
.dock-scroll { height: 100%; overflow-x: auto; overflow-y: hidden; scrollbar-width: none; }
.dock-scroll::-webkit-scrollbar { display: none; }
.dock-buttons { display: flex; width: max-content; gap: 7px; margin: 0 auto; padding: 15px 8px 20px; }
.dock-buttons .orb-button { width: 48px; height: 48px; }
.dock-buttons .orb-button::before { inset: 4.5px; }
.dock-buttons .orb-button svg { width: 24px; height: 24px; }
.dock-buttons .orb-button[aria-pressed='true']::before { box-shadow: 0 0 0 3px rgb(255 255 255 / 25%); }
.dock-buttons .orb-button::after { bottom: auto; top: 48px; font-size: 10px; padding: 3px 5px; }
.dock-arc { position: absolute; inset: 0 0 auto; width: 100%; height: 28px; fill: none; stroke: rgb(255 255 255 / 90%); stroke-width: 2; pointer-events: none; }
.dock-arc path { vector-effect: non-scaling-stroke; }
.is-curved { height: 100px; border-top: 0; }
.is-curved .dock-pointer { top: 2px; }
.is-curved .dock-buttons { padding-top: 20px; }
.is-curved .orb-button { translate: 0 var(--arc-offset, 0px); }
.is-curved .orb-button:nth-child(1), .is-curved .orb-button:nth-child(9) { --arc-offset: 12px; }
.is-curved .orb-button:nth-child(2), .is-curved .orb-button:nth-child(8) { --arc-offset: 7px; }
.is-curved .orb-button:nth-child(3), .is-curved .orb-button:nth-child(7) { --arc-offset: 3px; }
.is-curved .orb-button:nth-child(4), .is-curved .orb-button:nth-child(6) { --arc-offset: 1px; }
@media (max-width: 760px) { .device-dock { left: 0; right: 0; } }
@media (max-width: 480px) { .device-dock { height: 78px; } .dock-buttons { gap: 1px; padding: 12px 5px; } .dock-buttons .orb-button { width: 40px; height: 44px; } .dock-buttons .orb-button::before { inset: 4px 2px; } .dock-buttons .orb-button svg { width: 22px; height: 22px; } }
@media (max-width: 480px) { .is-curved { height: 94px; } .is-curved .dock-buttons { padding-top: 18px; } }
</style>
