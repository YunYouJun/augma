<script setup lang="ts">
import type { DeviceModule } from './types'
import { AgmButton, AgmToast } from 'augma'
import { computed, nextTick, onMounted, onUnmounted, shallowRef, toRef, useTemplateRef, watch } from 'vue'
import ArHud from '../../components/ArHud.vue'
import CameraView from '../../components/CameraView.vue'
import { useCamera } from '../../composables/useCamera'
import { useDepthMotion } from '../../composables/useDepthMotion'
import { useDisplaySettings } from '../../composables/useDisplaySettings'
import { useSimulator } from '../../composables/useSimulator'
import { useSoundscape } from '../../composables/useSoundscape'
import { useXr } from '../../composables/useXr'
import CameraControls from './CameraControls.vue'
import CommandPanel from './CommandPanel.vue'
import DeviceDock from './DeviceDock.vue'
import DeviceWindow from './DeviceWindow.vue'
import NavigationPanel from './NavigationPanel.vue'
import NotificationPanel from './NotificationPanel.vue'
import SettingsPanel from './SettingsPanel.vue'
import SoundPanel from './SoundPanel.vue'
import SpacePanel from './SpacePanel.vue'
import SystemBar from './SystemBar.vue'
import { deviceModules } from './types'
import WeatherPanel from './WeatherPanel.vue'
import WorldScene from './WorldScene.vue'

const device = useSimulator()
const { connection, online, activeModule, scene, selected, scanProgress, scanning, pinned, routeStep, routeProgress, remaining, routeInstruction, notices, unread, time } = device
const { settings, storageAvailable, reset } = useDisplaySettings()
const camera = useCamera()
const xr = useXr()
const root = useTemplateRef<HTMLElement>('deviceRoot')
const depthEnabled = computed(() => settings.depthMotion && settings.showHud && online.value && !xr.ready.value)
const { active: depthActive, reducedMotion } = useDepthMotion(root, depthEnabled)
const sound = useSoundscape(toRef(settings, 'volume'))
const view = useTemplateRef<InstanceType<typeof CameraView>>('cameraView')
const canvas = useTemplateRef<HTMLCanvasElement>('xrCanvas')
const notification = shallowRef(false)
const message = shallowRef('')
const fullscreen = shallowRef(false)
const fullscreenSupported = shallowRef(false)
let lastTrigger: HTMLElement | null = null
const title = computed(() => deviceModules.find(module => module.id === activeModule.value)?.label || '')
const panelStyle = computed(() => ({ '--window-alpha': `${settings.opacity / 100 * 0.7}` }))
const worldVisible = computed(() => online.value && settings.showHud && !settings.focus && !xr.ready.value && (activeModule.value === 'space' || activeModule.value === 'navigation'))
type DesktopWindow = Window & {
  __AUGMA_DESKTOP_MODULE__?: DeviceModule
  webkit?: { messageHandlers?: { moduleSelection?: { postMessage: (module: DeviceModule | null) => void } } }
}
const desktopWindow = window as DesktopWindow

function selectDesktopModule(event: Event) {
  const module = (event as CustomEvent<{ module?: unknown }>).detail?.module
  if (module === null) {
    device.closeModule()
    return
  }
  if (typeof module !== 'string' || !deviceModules.some(item => item.id === module))
    return
  settings.showHud = true
  device.openModule(module as DeviceModule)
}

function toast(text: string) {
  message.value = text
  notification.value = true
  device.notify(text, '本次设备体验的操作记录。')
}
function openApp(module: DeviceModule, trigger: HTMLElement | null = null) {
  if (activeModule.value === module && settings.showHud) {
    closeApp()
    return
  }
  lastTrigger = trigger
  settings.showHud = true
  device.openModule(module)
}
function closeApp() {
  device.closeModule()
  void nextTick(() => {
    if (lastTrigger?.isConnected)
      lastTrigger.focus({ preventScroll: true })
  })
}
function snapshot() {
  toast(view.value?.capture() ? '摄像头画面已保存' : '画面尚未就绪，请稍后重试')
}
async function prepareXr() {
  camera.stop()
  if (canvas.value)
    await xr.prepare(canvas.value)
}
async function toggleFullscreen() {
  try {
    if (document.fullscreenElement)
      await document.exitFullscreen()
    else
      await document.documentElement.requestFullscreen()
  }
  catch {
    toast('未能切换全屏，请检查浏览器权限')
  }
}
function syncFullscreen() {
  fullscreen.value = !!document.fullscreenElement
}
function resetSettings() {
  reset()
  toast('已恢复默认设置')
}
function runCommand(command: 'map' | 'scan' | 'audio' | 'hide') {
  if (command === 'hide') {
    settings.showHud = false
    return
  }
  if (command === 'map')
    device.openModule('navigation')
  if (command === 'scan') {
    device.openModule('space')
    device.scan()
  }
  if (command === 'audio') {
    device.openModule('audio')
    if (online.value)
      void sound.play()
  }
}
watch(online, (value) => {
  if (!value) {
    camera.stop()
    xr.stop()
    sound.pause()
  }
})
watch(activeModule, module => desktopWindow.webkit?.messageHandlers?.moduleSelection?.postMessage(module))
onMounted(() => {
  window.addEventListener('augma:select-module', selectDesktopModule)
  if (desktopWindow.__AUGMA_DESKTOP_MODULE__)
    selectDesktopModule(new CustomEvent('augma:select-module', { detail: { module: desktopWindow.__AUGMA_DESKTOP_MODULE__ } }))
  void xr.detect()
  fullscreenSupported.value = !!document.fullscreenEnabled
  syncFullscreen()
  document.addEventListener('fullscreenchange', syncFullscreen)
})
onUnmounted(() => {
  window.removeEventListener('augma:select-module', selectDesktopModule)
  document.removeEventListener('fullscreenchange', syncFullscreen)
})
</script>

<template>
  <div ref="deviceRoot" class="ar-app" :class="{ 'is-live': !!camera.stream.value || xr.ready.value, 'is-dark': settings.dark, 'has-depth': depthActive, 'has-curves': settings.curvedHud, 'has-window': activeModule && settings.showHud }" :style="panelStyle">
    <h1 class="agm-sr-only">Augma 模拟视界</h1>
    <CameraView ref="cameraView" :stream="camera.stream.value" :mirror="settings.mirror" />
    <canvas v-show="xr.ready.value" ref="xrCanvas" class="xr-canvas" aria-label="空间 AR 画面" />
    <SystemBar :curved="settings.curvedHud" :time="time" :fullscreen="fullscreen" :fullscreen-supported="fullscreenSupported" :dark="settings.dark" :unread="unread" :camera-live="!!camera.stream.value" @commands="openApp('commands', $event)" @fullscreen="toggleFullscreen" @flip="camera.flip" @theme="settings.dark = !settings.dark" @settings="openApp('settings', $event)" @notifications="openApp('notifications', $event)" @device="openApp('device', $event)" />
    <main class="device-workspace" aria-label="Augma 设备视界">
      <WorldScene v-if="worldVisible" :map-mode="activeModule === 'navigation'" :scene="scene.id" :landmarks="scene.landmarks" :selected="selected.id" :scanning="scanning" :pinned="pinned" :route="routeStep !== null" :route-progress="routeProgress" @select="device.selectLandmark" />
      <DeviceWindow v-if="activeModule && settings.showHud" :key="activeModule" :title="title" :app="activeModule" @close="closeApp">
        <SpacePanel v-if="activeModule === 'space'" :scene="scene.id" :selected="selected" :scanning="scanning" :progress="scanProgress" :pinned="pinned" :online="online" @scene="device.changeScene" @scan="device.scan" @cancel="device.cancelScan" @pin="device.togglePin" @navigate="device.startRoute" />
        <NavigationPanel v-else-if="activeModule === 'navigation'" :landmarks="scene.landmarks" :selected="selected" :step="routeStep" :progress="routeProgress" :remaining="remaining" :instruction="routeInstruction" :online="online" @select="device.selectLandmark" @start="device.startRoute" @advance="device.advanceRoute" @cancel="device.cancelRoute" />
        <SoundPanel v-else-if="activeModule === 'audio'" v-model:volume="settings.volume" :playing="sound.playing.value" :busy="sound.busy.value" :elapsed="sound.elapsed.value" :duration="sound.duration" :track-index="sound.trackIndex.value" :error="sound.error.value" :online="online" @play="sound.play" @pause="sound.pause" @track="sound.selectTrack" @seek="sound.seek" />
        <NotificationPanel v-else-if="activeModule === 'notifications'" :notices="notices" @clear="device.clearNotices" />
        <SettingsPanel v-else-if="activeModule === 'settings'" v-model:opacity="settings.opacity" v-model:dark="settings.dark" v-model:focus="settings.focus" v-model:mirror="settings.mirror" v-model:depth-motion="settings.depthMotion" v-model:curved-hud="settings.curvedHud" :reduced-motion="reducedMotion" :storage-available="storageAvailable" @reset="resetSettings" />
        <WeatherPanel v-else-if="activeModule === 'weather'" />
        <CameraControls v-else-if="activeModule === 'camera'" :camera="camera" :xr="xr" :online="online" @capture="snapshot" @prepare-xr="prepareXr" />
        <CommandPanel v-else-if="activeModule === 'commands'" @command="runCommand" />
        <ArHud v-else :connection="connection" :live="!!camera.stream.value" :scene="scene.name" @connect="device.connect" @sleep="device.suspend('sleeping')" @disconnect="device.suspend('disconnected')" />
      </DeviceWindow>
      <div v-if="!online && activeModule !== 'device'" class="standby-view"><p>{{ connection === 'sleeping' ? '设备正在待机' : connection === 'connecting' ? '正在建立连接' : '模拟设备已断开' }}</p><AgmButton :loading="connection === 'connecting'" @click="device.connect">{{ connection === 'sleeping' ? '唤醒设备' : '连接模拟设备' }}</AgmButton></div>
    </main>
    <DeviceDock :curved="settings.curvedHud" :active="settings.showHud ? activeModule : null" :show-hud="settings.showHud" :mirror="settings.mirror" @select="openApp" @mirror="settings.mirror = !settings.mirror" @hud="settings.showHud = !settings.showHud" />
    <AgmToast v-model:open="notification" :title="message" />
  </div>
</template>
