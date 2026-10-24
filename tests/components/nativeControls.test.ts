import { mount, shallowMount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, shallowRef, toRef } from 'vue'
import { useCamera } from '../../apps/ar/src/composables/useCamera'
import { useDisplaySettings } from '../../apps/ar/src/composables/useDisplaySettings'
import { useSimulator } from '../../apps/ar/src/composables/useSimulator'
import { useSoundscape } from '../../apps/ar/src/composables/useSoundscape'
import { useXr } from '../../apps/ar/src/composables/useXr'
import DeviceSimulator from '../../apps/ar/src/features/device/DeviceSimulator.vue'
import { useNativeControls } from '../../apps/ar/src/features/device/useNativeControls'
import { useSpeechCommands } from '../../apps/ar/src/features/device/useSpeechCommands'
import { locale, localeKey, setLocale } from '../../apps/ar/src/i18n/locale'

const cleanups: (() => void)[] = []
const dispatch = (action: unknown, value?: unknown) => window.dispatchEvent(new CustomEvent('augma:native-action', { detail: { action, value } }))
const visibility = (detail: unknown) => window.dispatchEvent(new CustomEvent('augma:native-visibility', { detail }))

function setup(native = true, nativeSpeech = false, hostState?: unknown, nativeMapCamera = false, nativeSpace = false) {
  const postMessage = vi.fn()
  const speechMessages = vi.fn()
  const hostMessages = vi.fn()
  const spaceMessages = vi.fn()
  Object.assign(window, {
    __AUGMA_DESKTOP_NATIVE_CONTROLS__: native,
    __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__: nativeMapCamera,
    __AUGMA_DESKTOP_NATIVE_SPACE__: nativeSpace,
    __AUGMA_DESKTOP_HOST_SERVICES__: hostState !== undefined,
    __AUGMA_DESKTOP_HOST_STATE__: hostState,
    webkit: { messageHandlers: { nativeState: { postMessage }, ...(nativeSpeech ? { speechCommand: { postMessage: speechMessages } } : {}), ...(nativeSpace ? { nativeSpace: { postMessage: spaceMessages } } : {}), ...(hostState !== undefined ? { hostServices: { postMessage: hostMessages } } : {}) } },
  })
  let device!: ReturnType<typeof useSimulator>
  let display!: ReturnType<typeof useDisplaySettings>
  let sound!: ReturnType<typeof useSoundscape>
  let camera!: ReturnType<typeof useCamera>
  let xr!: ReturnType<typeof useXr>
  let speech!: ReturnType<typeof useSpeechCommands>
  let controls!: ReturnType<typeof useNativeControls>
  const snapshot = vi.fn()
  const prepareXr = vi.fn(async () => {})
  const wrapper = mount(defineComponent({
    setup() {
      device = useSimulator()
      display = useDisplaySettings()
      sound = useSoundscape(toRef(display.settings, 'volume'))
      camera = useCamera()
      xr = useXr()
      speech = useSpeechCommands({ isPanelVisible: () => true, onCommand: vi.fn(), onReply: vi.fn(), apiKey: () => null })
      controls = useNativeControls({
        device,
        settings: display.settings,
        sound,
        camera,
        xr,
        speech,
        message: shallowRef(null),
        notification: shallowRef(false),
        storageAvailable: display.storageAvailable,
        speechFeedbackSupported: false,
        startSpeech: speech.start,
        changeLocale: setLocale,
        resetSettings: display.reset,
        snapshot,
        prepareXr,
      })
      return () => h('div')
    },
  }))
  cleanups.push(() => wrapper.unmount())
  const latest = () => Object.assign({}, ...postMessage.mock.calls.map(([packet]) => packet.changes))
  return { wrapper, device, display, sound, camera, xr, speech, speechMessages, hostMessages, spaceMessages, prepareXr, postMessage, latest, enabled: controls.enabled, sceneVisible: controls.sceneVisible, snapshot }
}

const initialHostState = () => ({
  locale: 'zh-CN',
  settings: { opacity: 92, volume: 47, dark: false, showHud: true, mirror: false, focus: false, depthMotion: false, sceneBackdrop: true, curvedHud: false, speechFeedback: true },
  audio: { trackIndex: 0, playing: false, busy: false, elapsed: 0, duration: 120, error: '' },
})
const updateHostState = (detail: unknown) => {
  Object.assign(window, { __AUGMA_DESKTOP_HOST_STATE__: detail })
  window.dispatchEvent(new CustomEvent('augma:host-state', { detail }))
}

beforeEach(() => {
  vi.useFakeTimers()
  setLocale('zh-CN')
})
afterEach(() => {
  cleanups.splice(0).forEach(cleanup => cleanup())
  for (const key of ['__AUGMA_DESKTOP_NATIVE_CONTROLS__', '__AUGMA_DESKTOP_NATIVE_MAP_CAMERA__', '__AUGMA_DESKTOP_NATIVE_SPACE__', '__AUGMA_DESKTOP_HOST_SERVICES__', '__AUGMA_DESKTOP_HOST_STATE__', 'webkit'])
    delete (window as unknown as Record<string, unknown>)[key]
  vi.unstubAllGlobals()
  vi.useRealTimers()
  localStorage.clear()
})

describe('native control boundary', () => {
  it('delegates native space actions without running webpage scan, anchors or routes', async () => {
    const native = setup(true, false, undefined, true, true)
    for (const [action, value] of [['scene', 'city'], ['landmark', 'tree'], ['scan'], ['pin'], ['routeStart'], ['routeNext'], ['routeStop'], ['cancelScan']])
      dispatch(action, value)
    await nextTick()
    vi.advanceTimersByTime(3000)
    expect(native.spaceMessages.mock.calls.map(([body]) => body)).toEqual([
      { action: 'scene', value: 'city' },
      { action: 'landmark', value: 'tree' },
      { action: 'scan' },
      { action: 'pin' },
      { action: 'routeStart' },
      { action: 'routeNext' },
      { action: 'routeStop' },
      { action: 'cancelScan' },
    ])
    expect(native.device.scene.value.id).toBe('garden')
    expect(native.device.scanning.value).toBe(false)
    expect(native.device.scanProgress.value).toBe(0)
    expect(native.device.routeStep.value).toBeNull()
    expect(native.device.pinned.value).toBe(false)
    dispatch('scene', 'malicious')
    dispatch('landmark', {})
    expect(native.spaceMessages).toHaveBeenCalledTimes(8)
    native.wrapper.unmount()
    dispatch('scan')
    expect(native.spaceMessages).toHaveBeenCalledTimes(8)
  })

  it('hands spoken space actions to RealityKit without mounting web scenery', async () => {
    const native = setup(true, false, undefined, true, true)
    native.wrapper.unmount()
    const simulator = shallowMount(DeviceSimulator)
    cleanups.push(() => simulator.unmount())
    dispatch('submit', '扫描空间')
    dispatch('submit', '开始导航')
    dispatch('submit', '下一步')
    dispatch('submit', '停止导航')
    await nextTick()
    expect(native.spaceMessages.mock.calls.map(([body]) => body.action)).toEqual(['scan', 'routeStart', 'routeNext', 'routeStop'])
    expect(simulator.findComponent({ name: 'WorldScene' }).exists()).toBe(false)
    expect(simulator.findComponent({ name: 'SceneBackdrop' }).exists()).toBe(false)
    expect(native.latest()).toMatchObject({ scanning: false, scanProgress: 0, routeStep: null })
  })
  it('delegates camera controls to the native module and never starts browser camera or XR', async () => {
    const getUserMedia = vi.fn()
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    const native = setup(true, false, undefined, true)
    const cameraStart = vi.spyOn(native.camera, 'start')
    const cameraFlip = vi.spyOn(native.camera, 'flip')
    const xrEnter = vi.spyOn(native.xr, 'enter')
    native.xr.supported.value = true
    for (const action of ['cameraStart', 'cameraFlip', 'capture']) {
      native.device.openModule('space')
      dispatch(action)
      expect(native.device.activeModule.value).toBe('camera')
    }
    dispatch('xrPrepare')
    native.xr.ready.value = true
    dispatch('xrEnter')
    await native.camera.start()
    expect(cameraStart).toHaveBeenCalledOnce()
    expect(cameraFlip).not.toHaveBeenCalled()
    expect(getUserMedia).not.toHaveBeenCalled()
    expect(native.snapshot).not.toHaveBeenCalled()
    expect(native.prepareXr).not.toHaveBeenCalled()
    expect(xrEnter).not.toHaveBeenCalled()
    native.device.closeModule()
    native.wrapper.unmount()
    dispatch('cameraStart')
    expect(native.device.activeModule.value).toBeNull()
  })

  it('keeps simulated route actions in Space while the navigation module belongs to MapKit', () => {
    const native = setup(true, false, undefined, true)
    dispatch('routeStart')
    expect(native.device.activeModule.value).toBe('space')
    expect(native.device.routeStep.value).toBe(0)
    native.device.openModule('navigation')
    dispatch('routeNext')
    expect(native.device.activeModule.value).toBe('space')
    expect(native.device.routeStep.value).toBe(1)
    native.device.openModule('navigation')
    dispatch('routeStop')
    expect(native.device.activeModule.value).toBe('space')
    expect(native.device.routeStep.value).toBeNull()
  })

  it('keeps spoken simulated routes in Space and opens the native map without a simulated map backdrop', async () => {
    const native = setup(true, false, undefined, true)
    native.wrapper.unmount()
    const moduleSelection = vi.fn()
    Object.assign(window, { webkit: { messageHandlers: { nativeState: { postMessage: native.postMessage }, moduleSelection: { postMessage: moduleSelection } } } })
    const simulator = shallowMount(DeviceSimulator)
    cleanups.push(() => simulator.unmount())
    dispatch('submit', '开始导航')
    await nextTick()
    expect(moduleSelection).toHaveBeenLastCalledWith('space')
    expect(native.latest()).toMatchObject({ routeStep: 0 })
    dispatch('submit', '下一步')
    await nextTick()
    expect(moduleSelection).toHaveBeenLastCalledWith('space')
    expect(native.latest()).toMatchObject({ routeStep: 1 })
    dispatch('submit', '停止导航')
    await nextTick()
    expect(moduleSelection).toHaveBeenLastCalledWith('space')
    expect(native.latest()).toMatchObject({ routeStep: null })
    dispatch('submit', '打开地图')
    await nextTick()
    expect(moduleSelection).toHaveBeenLastCalledWith('navigation')
    expect(simulator.findComponent({ name: 'WorldScene' }).exists()).toBe(false)
  })

  it('keeps real audio independent from simulated sleep and accepts audio commands while offline', async () => {
    const createAudio = vi.fn()
    const getUserMedia = vi.fn()
    vi.stubGlobal('AudioContext', createAudio)
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    const state = initialHostState()
    const native = setup(true, true, { ...state, audio: { ...state.audio, playing: true } })
    native.wrapper.unmount()
    const simulator = shallowMount(DeviceSimulator)
    cleanups.push(() => simulator.unmount())
    native.hostMessages.mockClear()
    dispatch('sleep')
    await nextTick()
    expect(native.latest()).toMatchObject({ online: false })
    expect(native.hostMessages).not.toHaveBeenCalled()

    updateHostState(state)
    dispatch('submit', '播放音乐')
    dispatch('submit', '暂停音乐')
    dispatch('play')
    dispatch('track', 1)
    dispatch('seek', 15)
    await nextTick()
    expect(native.hostMessages.mock.calls.map(([action]) => action)).toEqual([
      { action: 'play' },
      { action: 'pause' },
      { action: 'play' },
      { action: 'track', value: 1 },
      { action: 'seek', value: 15 },
    ])
    expect(createAudio).not.toHaveBeenCalled()
    expect(getUserMedia).not.toHaveBeenCalled()
    dispatch('cameraStart')
    expect(getUserMedia).not.toHaveBeenCalled()
  })

  it('routes settings, locale and audio requests exclusively to native host services', async () => {
    const createAudio = vi.fn()
    vi.stubGlobal('AudioContext', createAudio)
    const native = setup(true, false, initialHostState())
    native.hostMessages.mockClear()
    dispatch('setting', { key: 'volume', value: 900 })
    dispatch('setting', { key: 'opacity', value: -20 })
    dispatch('setting', { key: 'showHud', value: 'false' })
    dispatch('setting', { key: '__proto__', value: true })
    dispatch('setting', { key: 'volume', value: Number.NaN })
    dispatch('locale', 'ja-JP')
    dispatch('play')
    dispatch('track', 2)
    dispatch('track', 1.5)
    dispatch('seek', 999)
    dispatch('pause')
    dispatch('resetSettings')
    await nextTick()
    expect(native.hostMessages.mock.calls.map(([action]) => action)).toEqual([
      { action: 'setting', key: 'volume', value: 100 },
      { action: 'setting', key: 'opacity', value: 60 },
      { action: 'locale', value: 'ja-JP' },
      { action: 'play' },
      { action: 'track', value: 2 },
      { action: 'seek', value: 120 },
      { action: 'pause' },
      { action: 'resetSettings' },
    ])
    expect(createAudio).not.toHaveBeenCalled()
    expect(native.display.settings).toMatchObject({ volume: 47, opacity: 92 })
    expect(native.sound.trackIndex.value).toBe(0)
    expect(native.sound.playing.value).toBe(false)
    expect(locale.value).toBe('zh-CN')
    for (const key of ['settings', 'locale', 'sound', 'soundElapsed'])
      expect(native.latest()).not.toHaveProperty(key)
  })

  it('applies authoritative host snapshots without feedback or browser storage writes', async () => {
    const state = initialHostState()
    const native = setup(true, false, state)
    const writeStorage = vi.spyOn(localStorage, 'setItem')
    native.hostMessages.mockClear()
    updateHostState({
      ...state,
      locale: 'ja-JP',
      settings: { ...state.settings, dark: true, volume: 12, focus: true },
      audio: { trackIndex: 2, playing: true, busy: false, elapsed: 31.5, duration: 120, error: '' },
    })
    await nextTick()
    expect(native.display.settings).toMatchObject({ dark: true, volume: 12, focus: true })
    expect(document.documentElement.getAttribute('data-agm-theme')).toBe('dark')
    expect(locale.value).toBe('ja-JP')
    expect(native.sound.trackIndex.value).toBe(2)
    expect(native.sound.playing.value).toBe(true)
    expect(native.sound.elapsed.value).toBe(31.5)
    expect(native.hostMessages).not.toHaveBeenCalled()
    expect(writeStorage).not.toHaveBeenCalled()
    expect(native.latest().labels['module.weather']).toBe('天気')
    native.postMessage.mockClear()
    updateHostState({ ...state, locale: 'ja-JP', settings: { ...state.settings, dark: true, volume: 12, focus: true }, audio: { ...state.audio, playing: true, elapsed: 31.75 } })
    await nextTick()
    expect(native.sound.elapsed.value).toBe(31.75)
    expect(native.postMessage).not.toHaveBeenCalled()
    expect(native.hostMessages).not.toHaveBeenCalled()
    writeStorage.mockRestore()
  })

  it('validates legacy preferences once without overriding the initial native state', async () => {
    localStorage.setItem('augma-device-settings-v1', JSON.stringify({ dark: true, volume: 400, opacity: 20, showHud: 'false', arbitrary: 'ignored' }))
    localStorage.setItem(localeKey, 'ja-JP')
    const native = setup(true, false, initialHostState())
    expect(native.hostMessages).toHaveBeenCalledExactlyOnceWith({ action: 'legacyPreferences', settings: { dark: true, volume: 100, opacity: 60 }, locale: 'ja-JP' })
    expect(native.display.settings).toMatchObject({ dark: false, volume: 47, opacity: 92 })
    expect(locale.value).toBe('zh-CN')
    native.hostMessages.mockClear()
    native.display.settings.mirror = true
    await nextTick()
    expect(native.hostMessages).toHaveBeenCalledExactlyOnceWith({ action: 'setting', key: 'mirror', value: true })
    expect(JSON.parse(localStorage.getItem('augma-device-settings-v1')!)).toMatchObject({ dark: true, volume: 400 })
    expect(localStorage.getItem(localeKey)).toBe('ja-JP')
    native.wrapper.unmount()
    native.hostMessages.mockClear()
    const remounted = mount(defineComponent({
      setup() {
        useDisplaySettings()
        return () => h('div')
      },
    }))
    cleanups.push(() => remounted.unmount())
    expect(native.hostMessages).not.toHaveBeenCalled()
  })

  it('imports a valid legacy locale even if the old settings JSON is corrupt', () => {
    localStorage.setItem('augma-device-settings-v1', '{invalid')
    localStorage.setItem(localeKey, 'en-US')
    const native = setup(true, false, initialHostState())
    expect(native.hostMessages).toHaveBeenCalledExactlyOnceWith({ action: 'legacyPreferences', settings: {}, locale: 'en-US' })
    expect(native.display.storageAvailable.value).toBe(true)
  })

  it('keeps native audio alive across visibility changes and removes snapshot listeners on disposal', () => {
    const state = initialHostState()
    const native = setup(true, false, { ...state, audio: { ...state.audio, playing: true, elapsed: 10 } })
    native.hostMessages.mockClear()
    document.dispatchEvent(new Event('visibilitychange'))
    visibility({ visible: false })
    expect(native.sound.playing.value).toBe(true)
    native.wrapper.unmount()
    updateHostState({ ...state, settings: { ...state.settings, dark: true }, audio: { ...state.audio, elapsed: 20 } })
    expect(native.display.settings.dark).toBe(false)
    expect(native.sound.playing.value).toBe(true)
    expect(native.sound.elapsed.value).toBe(10)
    expect(native.hostMessages).not.toHaveBeenCalled()
  })

  it('ignores malformed host fields and requires both an explicit flag and a native handler', () => {
    const native = setup(true, false, initialHostState())
    native.hostMessages.mockClear()
    for (const detail of [null, [], { settings: [], audio: [] }, { settings: { volume: Number.NaN, dark: 'true' }, locale: 'invalid', audio: { trackIndex: 1.5, playing: 'true', elapsed: Number.POSITIVE_INFINITY } }])
      updateHostState(detail)
    expect(native.display.settings).toMatchObject({ volume: 47, dark: false })
    expect(native.sound.trackIndex.value).toBe(0)
    expect(native.sound.elapsed.value).toBe(0)
    expect(native.hostMessages).not.toHaveBeenCalled()
    native.wrapper.unmount()
    const browser = setup(false)
    Object.assign(window, { __AUGMA_DESKTOP_HOST_SERVICES__: true })
    updateHostState({ settings: { volume: 99, dark: true } })
    expect(browser.display.settings).toMatchObject({ volume: 35, dark: false })
    expect(browser.hostMessages).not.toHaveBeenCalled()
  })

  it('bounds bridge traffic during a full scan', async () => {
    const { postMessage } = setup()
    postMessage.mockClear()
    dispatch('scan')
    await vi.advanceTimersByTimeAsync(2100)
    const bytes = postMessage.mock.calls.reduce((sum, [message]) => sum + new TextEncoder().encode(JSON.stringify(message)).length, 0)
    expect(bytes).toBeLessThan(16_384)
    expect(postMessage.mock.calls.every(([packet]) => !packet.initial && !('labels' in packet.changes))).toBe(true)
  })

  it('drives scanning, selection and navigation and publishes the resulting state', async () => {
    const { latest } = setup()
    expect(latest()).toMatchObject({ version: 2, online: true, scene: { id: 'garden' } })
    dispatch('scan')
    await vi.advanceTimersByTimeAsync(2000)
    expect(latest()).toMatchObject({ scanProgress: 100, scanning: false })
    dispatch('pin')
    dispatch('landmark', 'tree')
    dispatch('routeStart')
    dispatch('routeNext')
    await nextTick()
    expect(latest()).toMatchObject({ pinned: true, selected: { id: 'tree' }, routeStep: 1, routeProgress: 25 })
    dispatch('scene', 'city')
    await nextTick()
    expect(latest()).toMatchObject({ scanProgress: 0, pinned: false, routeStep: null, selected: { id: 'gallery' } })
    dispatch('sleep')
    dispatch('scan')
    dispatch('routeStart')
    await nextTick()
    expect(latest()).toMatchObject({ online: false, scanning: false, routeStep: null })
  })

  it('validates actions and values and reports translated updates without credentials', async () => {
    const { display, sound, latest, snapshot } = setup()
    dispatch('setting', { key: 'volume', value: 900 })
    dispatch('setting', { key: 'opacity', value: -20 })
    dispatch('setting', { key: 'showHud', value: 'false' })
    dispatch('setting', { key: '__proto__', value: true })
    dispatch('setting', { key: 'volume', value: Number.NaN })
    dispatch('track', 1.5)
    dispatch('capture')
    dispatch('unknown')
    window.dispatchEvent(new CustomEvent('augma:native-action', { detail: null }))
    expect(display.settings).toMatchObject({ volume: 100, opacity: 60, showHud: true })
    expect(sound.trackIndex.value).toBe(0)
    expect(snapshot).not.toHaveBeenCalled()
    dispatch('locale', 'ja-JP')
    await nextTick()
    expect(locale.value).toBe('ja-JP')
    expect(latest().labels['module.weather']).toBe('天気')
    expect(latest().speech).not.toHaveProperty('apiKey')
    dispatch('resetSettings')
    await nextTick()
    expect(latest().settings).toMatchObject({ volume: 35, opacity: 88 })
  })

  it('does not enable native controls in the browser and removes listeners on disposal', async () => {
    const web = setup(false)
    dispatch('sleep')
    expect(web.enabled).toBe(false)
    expect(web.device.online.value).toBe(true)
    expect(web.postMessage).not.toHaveBeenCalled()
    const native = setup()
    native.wrapper.unmount()
    native.postMessage.mockClear()
    dispatch('sleep')
    await nextTick()
    expect(native.device.online.value).toBe(true)
    expect(native.postMessage).not.toHaveBeenCalled()
  })

  it('accepts only boolean visibility details from the enabled native host', () => {
    const native = setup()
    const stopCamera = vi.spyOn(native.camera, 'stop')
    for (const detail of [undefined, null, false, {}, { visible: 'false' }, { visible: 0 }, { visible: null }])
      visibility(detail)
    expect(native.sceneVisible.value).toBe(true)
    expect(stopCamera).not.toHaveBeenCalled()
    visibility({ visible: false })
    visibility({ visible: false })
    expect(native.sceneVisible.value).toBe(false)
    expect(stopCamera).toHaveBeenCalledOnce()
  })

  it('releases hidden camera, XR, scanning and speech while keeping audio playing', async () => {
    const stopTrack = vi.fn()
    const stopAudio = vi.fn()
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [{ stop: stopTrack }] }) } })
    vi.stubGlobal('AudioContext', class {
      resume = vi.fn().mockResolvedValue(undefined)
      suspend = vi.fn().mockResolvedValue(undefined)
      close = vi.fn().mockResolvedValue(undefined)
      createGain = () => ({ gain: { value: 0, setTargetAtTime: vi.fn() }, connect: vi.fn(), disconnect: vi.fn() })
      createOscillator = () => ({ frequency: { value: 0 }, detune: { value: 0 }, connect: vi.fn(), start: vi.fn(), disconnect: vi.fn(), stop: stopAudio })
    })
    const { camera, xr, sound, speech, speechMessages, device, sceneVisible } = setup(true, true)
    await camera.start()
    await sound.play()
    xr.ready.value = true
    xr.active.value = true
    xr.busy.value = true
    speech.start()
    dispatch('scan')
    expect(camera.stream.value).not.toBeNull()
    expect(speech.status.value).toBe('requesting')
    expect(device.scanning.value).toBe(true)

    visibility({ visible: false })
    expect(sceneVisible.value).toBe(false)
    expect(stopTrack).toHaveBeenCalledOnce()
    expect(camera.stream.value).toBeNull()
    expect(xr.ready.value).toBe(false)
    expect(xr.active.value).toBe(false)
    expect(xr.busy.value).toBe(false)
    expect(speech.status.value).toBe('idle')
    expect(speechMessages).toHaveBeenLastCalledWith('cancel')
    expect(device.scanning.value).toBe(false)
    expect(sound.playing.value).toBe(true)
    expect(stopAudio).not.toHaveBeenCalled()
    const progress = device.scanProgress.value
    await vi.advanceTimersByTimeAsync(500)
    expect(device.scanProgress.value).toBe(progress)
  })

  it('releases a camera permission response that arrives after the scene is hidden', async () => {
    let resolve!: (stream: MediaStream) => void
    const stopTrack = vi.fn()
    const getUserMedia = vi.fn(() => new Promise<MediaStream>((done) => {
      resolve = done
    }))
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    const { camera } = setup()
    const pending = camera.start()
    expect(camera.busy.value).toBe(true)
    visibility({ visible: false })
    resolve({ getTracks: () => [{ stop: stopTrack }] } as unknown as MediaStream)
    await pending
    expect(stopTrack).toHaveBeenCalledOnce()
    expect(camera.stream.value).toBeNull()
    expect(camera.busy.value).toBe(false)
  })

  it('blocks hidden scene actions and restores rendering without restarting media', () => {
    const native = setup()
    const startCamera = vi.spyOn(native.camera, 'start')
    native.xr.supported.value = true
    visibility({ visible: false })
    dispatch('scan')
    dispatch('cameraStart')
    dispatch('xrPrepare')
    expect(native.device.scanning.value).toBe(false)
    expect(startCamera).not.toHaveBeenCalled()
    expect(native.prepareXr).not.toHaveBeenCalled()
    visibility({ visible: true })
    expect(native.sceneVisible.value).toBe(true)
    expect(startCamera).not.toHaveBeenCalled()
    expect(native.prepareXr).not.toHaveBeenCalled()
    dispatch('scan')
    expect(native.device.scanning.value).toBe(true)
    dispatch('cameraStart')
    expect(startCamera).toHaveBeenCalledOnce()
  })

  it('ignores host visibility in ordinary browser mode and removes its listener on unmount', () => {
    const web = setup(false)
    const stopCamera = vi.spyOn(web.camera, 'stop')
    web.device.scan()
    visibility({ visible: false })
    expect(web.sceneVisible.value).toBe(true)
    expect(web.device.scanning.value).toBe(true)
    expect(stopCamera).not.toHaveBeenCalled()
    const native = setup()
    native.wrapper.unmount()
    visibility({ visible: false })
    expect(native.sceneVisible.value).toBe(true)
    expect(web.sceneVisible.value).toBe(true)
  })
})
