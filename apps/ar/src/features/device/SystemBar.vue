<script setup lang="ts">
import { shallowRef, useTemplateRef } from 'vue'
import DeviceIcon from './DeviceIcon.vue'

defineProps<{ curved: boolean, time: string, fullscreen: boolean, fullscreenSupported: boolean, dark: boolean, unread: number, cameraLive: boolean }>()
const emit = defineEmits<{
  commands: [trigger: HTMLElement]
  fullscreen: []
  flip: []
  theme: []
  settings: [trigger: HTMLButtonElement | null]
  notifications: [trigger: HTMLButtonElement | null]
  device: [trigger: HTMLButtonElement | null]
}>()
const expanded = shallowRef(false)
const menuTrigger = useTemplateRef<HTMLButtonElement>('menuTrigger')
function open(app: 'settings' | 'notifications' | 'device') {
  expanded.value = false
  if (app === 'settings')
    emit('settings', menuTrigger.value)
  else if (app === 'notifications')
    emit('notifications', menuTrigger.value)
  else
    emit('device', menuTrigger.value)
}
</script>

<template>
  <header class="system-bar" aria-label="Augma 系统栏">
    <button type="button" class="orb-button voice-button" aria-label="语音指令" data-tooltip="语音指令" @click="emit('commands', $event.currentTarget as HTMLElement)"><DeviceIcon name="microphone" /></button>
    <div class="system-clock">
      <time>{{ time }}</time>
      <svg v-if="curved" class="system-arc" viewBox="0 0 1000 32" preserveAspectRatio="none" aria-hidden="true"><path d="M0 2 Q500 58 1000 2" /></svg>
      <div v-else class="system-rule" />
    </div>
    <div class="system-menu" @keydown.esc="expanded = false">
      <button ref="menuTrigger" type="button" class="orb-button" aria-label="系统菜单" data-tooltip="系统菜单" :aria-expanded="expanded" aria-controls="system-actions" @click="expanded = !expanded"><DeviceIcon :name="expanded ? 'menu-open' : 'menu'" /></button>
      <div v-if="expanded" id="system-actions" class="system-actions">
        <button v-if="fullscreenSupported" type="button" class="orb-button" :aria-label="fullscreen ? '退出全屏' : '进入全屏'" :data-tooltip="fullscreen ? '退出全屏' : '进入全屏'" @click="emit('fullscreen')"><DeviceIcon name="expand" /></button>
        <button type="button" class="orb-button" aria-label="切换镜头" data-tooltip="切换镜头" :disabled="!cameraLive" @click="emit('flip')"><DeviceIcon name="flip" /></button>
        <button type="button" class="orb-button" aria-label="切换深色视界" data-tooltip="切换深色视界" :aria-pressed="dark" @click="emit('theme')"><DeviceIcon :name="dark ? 'moon' : 'sun'" /></button>
        <button type="button" class="orb-button" aria-label="设置" data-tooltip="设置" @click="open('settings')"><DeviceIcon name="settings" /></button>
        <button type="button" class="orb-button" aria-label="通知" data-tooltip="通知" @click="open('notifications')"><DeviceIcon name="notifications" /><span v-if="unread" class="notification-count">{{ unread }}</span></button>
        <button type="button" class="orb-button" aria-label="设备" data-tooltip="设备" @click="open('device')"><DeviceIcon name="device" /></button>
      </div>
    </div>
  </header>
</template>

<style scoped>
.system-bar { position: fixed; top: 28px; left: 28px; right: 28px; z-index: 20; display: flex; justify-content: space-between; pointer-events: none; }
.system-bar button { pointer-events: auto; }
.voice-button { --orb-color: #98d447; }
.system-clock { position: absolute; top: 4px; left: 60px; right: 60px; text-align: center; }
.system-clock time { color: white; font: bold 20.8px/.9 'Courier New', Courier, monospace; letter-spacing: 0; }
.system-rule { margin-top: 8px; height: 2px; background: rgb(255 255 255 / 88%); }
.system-arc { display: block; width: 100%; height: 32px; margin-top: 8px; overflow: visible; fill: none; stroke: rgb(255 255 255 / 88%); stroke-width: 2; pointer-events: none; }
.system-arc path { vector-effect: non-scaling-stroke; }
.system-menu { position: relative; pointer-events: auto; }
.system-actions { display: grid; gap: 4px; margin-top: 4px; }
.system-actions .orb-button::after { left: auto; right: 50px; top: 50%; bottom: auto; transform: translateY(-50%); }
@media (max-width: 480px) { .system-bar { left: 12px; right: 12px; top: 16px; } .system-clock { left: 56px; right: 56px; } }
</style>
