<script setup lang="ts">
import type { Locale, Message, MessageKey } from '../../i18n/locale'
import type { ShortcutHint, ShortcutId } from './shortcuts'
import type { DeviceModule } from './types'
import type { VoiceCommand } from './voiceCommands'
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
import { locale, setLocale, t } from '../../i18n/locale'
import CameraControls from './CameraControls.vue'
import CommandPanel from './CommandPanel.vue'
import DeviceDock from './DeviceDock.vue'
import DeviceWindow from './DeviceWindow.vue'
import NavigationPanel from './NavigationPanel.vue'
import NotificationPanel from './NotificationPanel.vue'
import SceneBackdrop from './SceneBackdrop.vue'
import SettingsPanel from './SettingsPanel.vue'
import { ariaChord, chordLabel, parseChord, shortcutIds } from './shortcuts'
import ShortcutsDialog from './ShortcutsDialog.vue'
import SoundPanel from './SoundPanel.vue'
import SpacePanel from './SpacePanel.vue'
import SystemBar from './SystemBar.vue'
import { deviceModules } from './types'
import { useAssistantKey } from './useAssistantKey'
import { useShortcuts } from './useShortcuts'
import { useSpeechCommands } from './useSpeechCommands'
import { useSpeechFeedback } from './useSpeechFeedback'
import { clearWindowPlacements } from './useWindowPlacement'
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
const message = shallowRef<Message | null>(null)
const fullscreen = shallowRef(false)
const fullscreenSupported = shallowRef(false)
const layoutResetVersion = shallowRef(0)
let lastTrigger: HTMLElement | null = null
const title = computed(() => activeModule.value ? t(`module.${activeModule.value}`) : '')
const panelStyle = computed(() => ({ '--window-alpha': `${settings.opacity / 100 * 0.7}` }))
const worldVisible = computed(() => online.value && settings.showHud && !settings.focus && !xr.ready.value && (activeModule.value === 'space' || activeModule.value === 'navigation'))
type DesktopWindow = Window & {
  __AUGMA_DESKTOP_MODULE__?: DeviceModule
  __AUGMA_DESKTOP_IMMERSIVE__?: boolean
  /** The macOS app's voice menu key as a chord, `null` when the menu item has no key. */
  __AUGMA_DESKTOP_VOICE_SHORTCUT__?: string | null
  webkit?: { messageHandlers?: { moduleSelection?: { postMessage: (module: DeviceModule | null) => void } } }
}
const desktopWindow = window as DesktopWindow
const desktopImmersive = desktopWindow.__AUGMA_DESKTOP_IMMERSIVE__ === true
// The simulated surroundings stand in for the real world until the camera or AR shows it.
const backdropVisible = computed(() => settings.sceneBackdrop && !desktopImmersive && !camera.stream.value && !xr.ready.value)
const nativeChord = (value: unknown) => typeof value === 'string' && parseChord(value) ? value : null
/** Follows the menu item, which the user can rebind under App Shortcuts in System Settings. */
const nativeVoiceShortcut = shallowRef(nativeChord(desktopWindow.__AUGMA_DESKTOP_VOICE_SHORTCUT__))
const nativeVoiceLabel = computed(() => nativeVoiceShortcut.value ? chordLabel(nativeVoiceShortcut.value, true) : '')
const shortcutsOpen = shallowRef(false)
const shortcuts = useShortcuts({
  run: runShortcut,
  available: id => id !== 'fullscreen' || fullscreenSupported.value,
  escape: () => {
    if (!activeModule.value || !settings.showHud)
      return false
    closeApp()
    return true
  },
})
const shortcutsEnabled = computed({ get: () => shortcuts.enabled.value, set: shortcuts.setEnabled })
const customizedShortcuts = computed(() => shortcutIds.filter(shortcuts.customized))
const shortcutHints = computed(() => {
  const hints: Partial<Record<ShortcutId, ShortcutHint>> = {}
  if (!shortcuts.enabled.value)
    return hints
  for (const id of shortcutIds) {
    const chord = shortcuts.bindings.value[id]
    if (chord)
      hints[id] = { label: chordLabel(chord, shortcuts.mac), aria: ariaChord(chord) }
  }
  return hints
})

const feedback = useSpeechFeedback(() => settings.speechFeedback)
const localeSaved = shallowRef(true)
const assistantKey = useAssistantKey()
const speech = useSpeechCommands({
  isPanelVisible: () => activeModule.value === 'commands' && settings.showHud,
  onCommand: (command) => {
    executeCommand(command)
  },
  onReply: reply => feedback.speak(reply),
  apiKey: () => assistantKey.key.value,
})

function executeCommand(command: VoiceCommand) {
  const result = runCommand(command)
  toast(result)
  feedback.speak(t(result))
}

function startSpeech() {
  // Keep the synthesized voice out of the microphone.
  feedback.cancel()
  speech.start()
}

function changeLocale(next: Locale) {
  localeSaved.value = setLocale(next)
  feedback.cancel()
}

function saveAssistantKey(value: string) {
  toast({ key: assistantKey.save(value) ? 'toast.assistantKeySaved' : 'toast.assistantKeyFailed' })
}

function removeAssistantKey() {
  speech.cancel()
  assistantKey.remove()
  toast({ key: 'toast.assistantKeyRemoved' })
}

function toggleSpeechShortcut() {
  if (!speech.available)
    return
  if (speech.status.value === 'listening') {
    speech.stop()
    return
  }
  if (speech.status.value !== 'idle') {
    speech.cancel()
    return
  }
  settings.showHud = true
  device.openModule('commands')
  startSpeech()
}

/** The focused control, to return focus to when an app opened from the keyboard closes. */
function shortcutTrigger() {
  const element = document.activeElement
  // Focus inside the panel being replaced cannot be restored later.
  return element instanceof HTMLElement && element !== document.body && !element.closest('.device-window') ? element : null
}

function announceToggle(name: MessageKey, on: boolean) {
  // A short confirmation without adding to the device's notification list.
  message.value = { key: 'shortcuts.toggled', params: { name: { key: name }, state: { key: on ? 'shortcuts.on' : 'shortcuts.off' } } }
  notification.value = true
}

function runShortcut(id: ShortcutId) {
  switch (id) {
    case 'help':
      shortcutsOpen.value = true
      return
    case 'voice':
      if (speech.available)
        toggleSpeechShortcut()
      else
        openApp('commands', shortcutTrigger())
      return
    case 'hud':
      settings.showHud = !settings.showHud
      return announceToggle('dock.showHud', settings.showHud)
    case 'dark':
      settings.dark = !settings.dark
      return announceToggle('settings.dark', settings.dark)
    case 'mirror':
      settings.mirror = !settings.mirror
      return announceToggle('settings.mirror', settings.mirror)
    case 'focus':
      settings.focus = !settings.focus
      return announceToggle('settings.focus', settings.focus)
    case 'fullscreen':
      void toggleFullscreen()
      return
    default:
      openApp(id, shortcutTrigger())
  }
}

function selectDesktopModule(event: Event) {
  const module = (event as CustomEvent<{ module?: unknown }>).detail?.module
  if (module === null) {
    device.closeModule()
    return
  }
  if (typeof module !== 'string' || !deviceModules.includes(module as DeviceModule))
    return
  settings.showHud = true
  device.openModule(module as DeviceModule)
}

function syncNativeVoiceShortcut(event: Event) {
  nativeVoiceShortcut.value = nativeChord((event as CustomEvent<{ shortcut?: unknown }>).detail?.shortcut)
}

function toast(text: Message) {
  message.value = text
  notification.value = true
  device.notify(text, { key: 'notice.action.detail' })
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
  toast({ key: view.value?.capture() ? 'toast.snapshotSaved' : 'toast.snapshotNotReady' })
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
    toast({ key: 'toast.fullscreenFailed' })
  }
}
function syncFullscreen() {
  fullscreen.value = !!document.fullscreenElement
}
function resetSettings() {
  reset()
  shortcuts.resetAll()
  clearWindowPlacements()
  layoutResetVersion.value++
  toast({ key: 'toast.settingsReset' })
}
function runCommand(command: VoiceCommand): Message {
  speech.cancel()
  switch (command) {
    case 'hide':
      settings.showHud = false
      return { key: 'result.hide' }
    case 'show':
      settings.showHud = true
      return { key: 'result.show' }
    case 'map':
      device.openModule('navigation')
      return { key: 'result.map' }
    case 'scan':
      if (!online.value)
        return { key: 'result.scanOffline' }
      device.openModule('space')
      device.scan()
      return { key: 'result.scan' }
    case 'audio':
      if (!online.value)
        return { key: 'result.audioOffline' }
      device.openModule('audio')
      void sound.play()
      return { key: 'result.audio' }
    case 'audioPause':
      sound.pause()
      device.openModule('audio')
      return { key: 'result.audioPause' }
    case 'weather':
      device.openModule('weather')
      return { key: 'result.weather' }
    case 'notifications':
      device.openModule('notifications')
      return { key: 'result.notifications' }
    case 'settings':
      device.openModule('settings')
      return { key: 'result.settings' }
    case 'camera':
      device.openModule('camera')
      return { key: 'result.camera' }
    case 'dark':
      settings.dark = true
      return { key: 'result.dark' }
    case 'light':
      settings.dark = false
      return { key: 'result.light' }
    case 'routeStart':
      if (!online.value)
        return { key: 'result.routeStartOffline' }
      device.startRoute()
      return { key: 'result.routeStart', params: { name: { key: `landmark.${selected.value.id}.name` } } }
    case 'routeNext':
      if (!online.value || routeStep.value === null)
        return { key: 'result.routeNextIdle' }
      if (routeStep.value >= 4)
        return { key: 'result.routeAlreadyArrived' }
      device.openModule('navigation')
      device.advanceRoute()
      return { key: routeStep.value === 4 ? 'result.routeArrived' : 'result.routeNext' }
    case 'routeStop':
      if (routeStep.value === null)
        return { key: 'result.routeStopIdle' }
      device.cancelRoute()
      device.openModule('navigation')
      return { key: 'result.routeStop' }
  }
}
watch(online, (value) => {
  if (!value) {
    camera.stop()
    xr.stop()
    sound.pause()
  }
})
watch(activeModule, (module) => {
  desktopWindow.webkit?.messageHandlers?.moduleSelection?.postMessage(module)
  if (module !== 'commands')
    speech.cancel()
})
watch(() => settings.showHud, (visible) => {
  if (!visible)
    speech.cancel()
})
watch(() => settings.speechFeedback, (enabled) => {
  if (!enabled)
    feedback.cancel()
})
watch(locale, (value) => {
  document.documentElement.lang = value
  document.title = t('app.documentTitle')
}, { immediate: true })
onMounted(() => {
  if (desktopImmersive)
    document.documentElement.classList.add('augma-desktop-immersive')
  window.addEventListener('augma:select-module', selectDesktopModule)
  window.addEventListener('augma:toggle-speech', toggleSpeechShortcut)
  window.addEventListener('augma:voice-shortcut', syncNativeVoiceShortcut)
  if (desktopWindow.__AUGMA_DESKTOP_MODULE__)
    selectDesktopModule(new CustomEvent('augma:select-module', { detail: { module: desktopWindow.__AUGMA_DESKTOP_MODULE__ } }))
  void xr.detect()
  fullscreenSupported.value = !!document.fullscreenEnabled
  syncFullscreen()
  document.addEventListener('fullscreenchange', syncFullscreen)
})
onUnmounted(() => {
  if (desktopImmersive)
    document.documentElement.classList.remove('augma-desktop-immersive')
  window.removeEventListener('augma:select-module', selectDesktopModule)
  window.removeEventListener('augma:toggle-speech', toggleSpeechShortcut)
  window.removeEventListener('augma:voice-shortcut', syncNativeVoiceShortcut)
  speech.cancel()
  document.removeEventListener('fullscreenchange', syncFullscreen)
})
</script>

<template>
  <div ref="deviceRoot" class="ar-app" :class="{ 'is-live': !!camera.stream.value || xr.ready.value, 'is-dark': settings.dark, 'is-desktop-immersive': desktopImmersive, 'has-depth': depthActive, 'has-curves': settings.curvedHud, 'has-window': activeModule && settings.showHud }" :style="panelStyle">
    <h1 class="agm-sr-only">{{ t('app.heading') }}</h1>
    <SceneBackdrop v-if="backdropVisible" :scene="scene.id" />
    <CameraView ref="cameraView" :stream="camera.stream.value" :mirror="settings.mirror" />
    <canvas v-show="xr.ready.value" ref="xrCanvas" class="xr-canvas" :aria-label="t('app.xrCanvas')" />
    <SystemBar :curved="settings.curvedHud" :time="time" :fullscreen="fullscreen" :fullscreen-supported="fullscreenSupported" :dark="settings.dark" :unread="unread" :camera-live="!!camera.stream.value" :shortcuts="shortcutHints" @commands="openApp('commands', $event)" @fullscreen="toggleFullscreen" @flip="camera.flip" @theme="settings.dark = !settings.dark" @settings="openApp('settings', $event)" @notifications="openApp('notifications', $event)" @device="openApp('device', $event)" />
    <main class="device-workspace" :aria-label="t('app.workspace')">
      <WorldScene v-if="worldVisible" :map-mode="activeModule === 'navigation'" :scene="scene.id" :landmarks="scene.landmarks" :selected="selected.id" :scanning="scanning" :pinned="pinned" :route="routeStep !== null" :route-progress="routeProgress" @select="device.selectLandmark" />
      <DeviceWindow v-if="activeModule && settings.showHud" :key="activeModule" :title="title" :app="activeModule" :reset-version="layoutResetVersion" @close="closeApp">
        <SpacePanel v-if="activeModule === 'space'" :scene="scene.id" :selected="selected" :scanning="scanning" :progress="scanProgress" :pinned="pinned" :online="online" @scene="device.changeScene" @scan="device.scan" @cancel="device.cancelScan" @pin="device.togglePin" @navigate="device.startRoute" />
        <NavigationPanel v-else-if="activeModule === 'navigation'" :landmarks="scene.landmarks" :selected="selected" :step="routeStep" :progress="routeProgress" :remaining="remaining" :instruction="routeInstruction" :online="online" @select="device.selectLandmark" @start="device.startRoute" @advance="device.advanceRoute" @cancel="device.cancelRoute" />
        <SoundPanel v-else-if="activeModule === 'audio'" v-model:volume="settings.volume" :playing="sound.playing.value" :busy="sound.busy.value" :elapsed="sound.elapsed.value" :duration="sound.duration" :track-index="sound.trackIndex.value" :error="sound.error.value ? t(sound.error.value) : ''" :online="online" @play="sound.play" @pause="sound.pause" @track="sound.selectTrack" @seek="sound.seek" />
        <NotificationPanel v-else-if="activeModule === 'notifications'" :notices="notices" @clear="device.clearNotices" />
        <SettingsPanel v-else-if="activeModule === 'settings'" v-model:opacity="settings.opacity" v-model:dark="settings.dark" v-model:focus="settings.focus" v-model:mirror="settings.mirror" v-model:depth-motion="settings.depthMotion" v-model:scene-backdrop="settings.sceneBackdrop" v-model:curved-hud="settings.curvedHud" v-model:speech-feedback="settings.speechFeedback" v-model:shortcuts-enabled="shortcutsEnabled" :locale="locale" :speech-feedback-supported="feedback.supported" :assistant-native="speech.native" :assistant-ready="speech.assistantReady.value" :reduced-motion="reducedMotion" :storage-available="storageAvailable && localeSaved" @locale="changeLocale" @reset="resetSettings" @shortcuts="shortcutsOpen = true" @save-key="saveAssistantKey" @remove-key="removeAssistantKey" />
        <WeatherPanel v-else-if="activeModule === 'weather'" />
        <CameraControls v-else-if="activeModule === 'camera'" :camera="camera" :xr="xr" :online="online" @capture="snapshot" @prepare-xr="prepareXr" />
        <CommandPanel v-else-if="activeModule === 'commands'" :speech-available="speech.available" :native="speech.native" :voice-shortcut="nativeVoiceLabel" :assistant-ready="speech.assistantReady.value" :speech-status="speech.status.value" :transcript="speech.transcript.value" :reply="speech.reply.value" :speech-error="speech.error.value ? t(speech.error.value) : ''" @command="executeCommand" @start="startSpeech" @stop="speech.stop" @cancel="speech.cancel" @submit="speech.submitText" />
        <ArHud v-else :connection="connection" :live="!!camera.stream.value" :scene="scene.name" @connect="device.connect" @sleep="device.suspend('sleeping')" @disconnect="device.suspend('disconnected')" />
      </DeviceWindow>
      <div v-if="!online && activeModule !== 'device'" class="standby-view"><p>{{ t(`connection.${connection}`) }}</p><AgmButton :loading="connection === 'connecting'" @click="device.connect">{{ t(connection === 'sleeping' ? 'device.wake' : 'device.connect') }}</AgmButton></div>
    </main>
    <DeviceDock :curved="settings.curvedHud" :active="settings.showHud ? activeModule : null" :show-hud="settings.showHud" :mirror="settings.mirror" :shortcuts="shortcutHints" @select="openApp" @mirror="settings.mirror = !settings.mirror" @hud="settings.showHud = !settings.showHud" />
    <AgmToast v-model:open="notification" :title="message ? t(message) : ''" :close-label="t('toast.close')" :region-label="t('toast.region')" />
    <ShortcutsDialog v-model:open="shortcutsOpen" v-model:enabled="shortcutsEnabled" :bindings="shortcuts.bindings.value" :customized="customizedShortcuts" :hidden="fullscreenSupported ? [] : ['fullscreen']" :mac="shortcuts.mac" :native-voice="speech.native ? nativeVoiceShortcut : null" :storage-available="shortcuts.storageAvailable.value" @assign="shortcuts.assign" @reset="shortcuts.reset" @reset-all="shortcuts.resetAll" />
  </div>
</template>
