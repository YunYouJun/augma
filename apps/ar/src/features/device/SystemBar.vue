<script setup lang="ts">
import type { ShortcutHint, ShortcutId } from './shortcuts'
import { shallowRef, useTemplateRef } from 'vue'
import { t } from '../../i18n/locale'
import DeviceIcon from './DeviceIcon.vue'

const props = defineProps<{ curved: boolean, time: string, fullscreen: boolean, fullscreenSupported: boolean, dark: boolean, unread: number, cameraLive: boolean, shortcuts: Partial<Record<ShortcutId, ShortcutHint>> }>()
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
const tip = (label: string, id: ShortcutId) => props.shortcuts[id] ? `${label} · ${props.shortcuts[id].label}` : label
function collapse(event: KeyboardEvent) {
  if (!expanded.value)
    return
  // Escape closes the menu only, not the open app behind it.
  event.stopPropagation()
  expanded.value = false
  menuTrigger.value?.focus()
}
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
  <header class="system-bar" :aria-label="t('systemBar.label')">
    <button type="button" class="orb-button voice-button" :aria-label="t('module.commands')" :data-tooltip="tip(t('module.commands'), 'voice')" :aria-keyshortcuts="shortcuts.voice?.aria" @click="emit('commands', $event.currentTarget as HTMLElement)"><DeviceIcon name="microphone" /></button>
    <div class="system-clock">
      <time>{{ time }}</time>
      <svg v-if="curved" class="system-arc" viewBox="0 0 1000 32" preserveAspectRatio="none" aria-hidden="true"><path d="M0 2 Q500 58 1000 2" /></svg>
      <div v-else class="system-rule" />
    </div>
    <div class="system-menu" @keydown.esc="collapse">
      <button ref="menuTrigger" type="button" class="orb-button" :aria-label="t('systemBar.menu')" :data-tooltip="t('systemBar.menu')" :aria-expanded="expanded" aria-controls="system-actions" @click="expanded = !expanded"><DeviceIcon :name="expanded ? 'menu-open' : 'menu'" /></button>
      <div v-if="expanded" id="system-actions" class="system-actions">
        <button v-if="fullscreenSupported" type="button" class="orb-button" :aria-label="t(fullscreen ? 'systemBar.exitFullscreen' : 'systemBar.enterFullscreen')" :data-tooltip="tip(t(fullscreen ? 'systemBar.exitFullscreen' : 'systemBar.enterFullscreen'), 'fullscreen')" :aria-keyshortcuts="shortcuts.fullscreen?.aria" @click="emit('fullscreen')"><DeviceIcon name="expand" /></button>
        <button type="button" class="orb-button" :aria-label="t('camera.flip')" :data-tooltip="t('camera.flip')" :disabled="!cameraLive" @click="emit('flip')"><DeviceIcon name="flip" /></button>
        <button type="button" class="orb-button" :aria-label="t('systemBar.toggleDark')" :data-tooltip="tip(t('systemBar.toggleDark'), 'dark')" :aria-keyshortcuts="shortcuts.dark?.aria" :aria-pressed="dark" @click="emit('theme')"><DeviceIcon :name="dark ? 'moon' : 'sun'" /></button>
        <button type="button" class="orb-button" :aria-label="t('module.settings')" :data-tooltip="tip(t('module.settings'), 'settings')" :aria-keyshortcuts="shortcuts.settings?.aria" @click="open('settings')"><DeviceIcon name="settings" /></button>
        <button type="button" class="orb-button" :aria-label="t('module.notifications')" :data-tooltip="tip(t('module.notifications'), 'notifications')" :aria-keyshortcuts="shortcuts.notifications?.aria" @click="open('notifications')"><DeviceIcon name="notifications" /><span v-if="unread" class="notification-count">{{ unread }}</span></button>
        <button type="button" class="orb-button" :aria-label="t('module.device')" :data-tooltip="tip(t('module.device'), 'device')" :aria-keyshortcuts="shortcuts.device?.aria" @click="open('device')"><DeviceIcon name="device" /></button>
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
