import type { Connection, DeviceModule, DeviceNotice, Landmark, SceneId } from '../features/device/types'
import type { Message } from '../i18n/locale'
import { computed, onMounted, onUnmounted, readonly, shallowRef } from 'vue'
import { scenes } from '../features/device/types'
import { formatTime, locale, t } from '../i18n/locale'

export function useSimulator() {
  const connection = shallowRef<Connection>('connected')
  const activeModule = shallowRef<DeviceModule | null>(null)
  const sceneId = shallowRef<SceneId>('garden')
  const scanProgress = shallowRef(0)
  const scanning = shallowRef(false)
  const pinned = shallowRef(false)
  const selectedId = shallowRef('terrace')
  const routeStep = shallowRef<number | null>(null)
  const notices = shallowRef<DeviceNotice[]>([])
  const now = shallowRef(Date.now())
  let sequence = 0
  let scanTimer: ReturnType<typeof setInterval> | undefined
  let connectTimer: ReturnType<typeof setTimeout> | undefined
  let clockTimer: ReturnType<typeof setInterval> | undefined
  const scene = computed(() => {
    const data = scenes.find(item => item.id === sceneId.value)!
    return {
      id: data.id,
      name: t(`scene.${data.id}.name`),
      description: t(`scene.${data.id}.description`),
      landmarks: data.landmarks.map((item): Landmark => ({ ...item, name: t(`landmark.${item.id}.name`), description: t(`landmark.${item.id}.description`) })),
    }
  })
  const selected = computed(() => scene.value.landmarks.find(item => item.id === selectedId.value)!)
  const sceneName = (): Message => ({ key: `scene.${sceneId.value}.name` })
  const selectedName = (): Message => ({ key: `landmark.${selected.value.id}.name` })
  const time = computed(() => formatTime(now.value))
  const date = computed(() => new Date(now.value).toLocaleDateString(locale.value, { month: 'long', day: 'numeric', weekday: 'long' }))
  const online = computed(() => connection.value === 'connected')
  const unread = computed(() => notices.value.filter(item => !item.read).length)
  const routeProgress = computed(() => (routeStep.value ?? 0) / 4 * 100)
  const remaining = computed(() => Math.round(selected.value.distance * (1 - routeProgress.value / 100)))
  const routeInstruction = computed(() => {
    if (routeStep.value === null)
      return t('navigation.instruction.idle')
    return t(`navigation.instruction.${routeStep.value as 0 | 1 | 2 | 3 | 4}`, { name: selected.value.name })
  })

  function notify(title: Message, detail: Message) {
    notices.value = [{
      id: ++sequence,
      title,
      detail,
      at: Date.now(),
      read: activeModule.value === 'notifications',
    }, ...notices.value].slice(0, 30)
  }
  function markRead() {
    notices.value = notices.value.map(item => ({ ...item, read: true }))
  }
  function openModule(module: DeviceModule) {
    activeModule.value = module
    if (module === 'notifications')
      markRead()
  }
  function closeModule() {
    activeModule.value = null
  }
  function cancelScan() {
    clearInterval(scanTimer)
    scanning.value = false
  }
  function scan() {
    if (!online.value || scanning.value)
      return
    scanProgress.value = 0
    pinned.value = false
    scanning.value = true
    scanTimer = setInterval(() => {
      scanProgress.value = Math.min(100, scanProgress.value + 5)
      if (scanProgress.value === 100) {
        cancelScan()
        notify({ key: 'notice.scanComplete.title' }, { key: 'notice.scanComplete.detail', params: { scene: sceneName() } })
      }
    }, 100)
  }
  function selectLandmark(id: string) {
    if (!online.value || !scene.value.landmarks.some(item => item.id === id))
      return
    if (selectedId.value !== id)
      routeStep.value = null
    selectedId.value = id
  }
  function changeScene(id: SceneId) {
    if (!online.value || sceneId.value === id || !scenes.some(item => item.id === id))
      return
    cancelScan()
    sceneId.value = id
    selectedId.value = scene.value.landmarks[0].id
    scanProgress.value = 0
    pinned.value = false
    routeStep.value = null
    notify({ key: 'notice.sceneChanged.title' }, { key: 'notice.sceneChanged.detail', params: { scene: sceneName() } })
  }
  function togglePin() {
    if (!online.value || scanProgress.value !== 100)
      return
    pinned.value = !pinned.value
    notify({ key: pinned.value ? 'notice.anchorPinned.title' : 'notice.anchorReleased.title' }, { key: 'notice.anchor.detail' })
  }
  function startRoute() {
    if (!online.value)
      return
    routeStep.value = 0
    openModule('navigation')
    notify({ key: 'notice.routeStarted.title' }, { key: 'notice.routeStarted.detail', params: { name: selectedName() } })
  }
  function advanceRoute() {
    if (!online.value || routeStep.value === null || routeStep.value >= 4)
      return
    routeStep.value++
    if (routeStep.value === 4)
      notify({ key: 'notice.arrived.title' }, { key: 'notice.arrived.detail', params: { name: selectedName() } })
  }
  function cancelRoute() {
    routeStep.value = null
  }
  function suspend(next: 'sleeping' | 'disconnected') {
    clearTimeout(connectTimer)
    cancelScan()
    scanProgress.value = 0
    pinned.value = false
    routeStep.value = null
    connection.value = next
    notify({ key: next === 'sleeping' ? 'notice.sleeping.title' : 'notice.disconnected.title' }, { key: 'notice.suspended.detail' })
  }
  function connect() {
    if (connection.value === 'connected' || connection.value === 'connecting')
      return
    connection.value = 'connecting'
    connectTimer = setTimeout(() => {
      connection.value = 'connected'
      notify({ key: 'notice.connected.title' }, { key: 'notice.connected.detail' })
    }, 900)
  }
  function tick() {
    now.value = Date.now()
  }
  onMounted(() => {
    tick()
    clockTimer = setInterval(tick, 1000)
    notify({ key: 'notice.welcome.title' }, { key: 'notice.welcome.detail' })
  })
  onUnmounted(() => {
    cancelScan()
    clearTimeout(connectTimer)
    clearInterval(clockTimer)
  })
  return {
    connection: readonly(connection),
    activeModule: readonly(activeModule),
    scene,
    selected,
    online,
    scanProgress: readonly(scanProgress),
    scanning: readonly(scanning),
    pinned: readonly(pinned),
    routeStep: readonly(routeStep),
    routeProgress,
    remaining,
    routeInstruction,
    notices: readonly(notices),
    unread,
    time,
    date,
    scan,
    cancelScan,
    selectLandmark,
    changeScene,
    togglePin,
    startRoute,
    advanceRoute,
    cancelRoute,
    suspend,
    connect,
    openModule,
    closeModule,
    notify,
    markRead,
    clearNotices: () => { notices.value = [] },
  }
}
