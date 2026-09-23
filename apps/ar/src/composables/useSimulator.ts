import type { Connection, DeviceModule, DeviceNotice, SceneId } from '../features/device/types'
import { computed, onMounted, onUnmounted, readonly, shallowRef } from 'vue'
import { scenes } from '../features/device/types'

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
  const time = shallowRef('')
  const date = shallowRef('')
  let sequence = 0
  let scanTimer: ReturnType<typeof setInterval> | undefined
  let connectTimer: ReturnType<typeof setTimeout> | undefined
  let clockTimer: ReturnType<typeof setInterval> | undefined
  const scene = computed(() => scenes.find(item => item.id === sceneId.value)!)
  const selected = computed(() => scene.value.landmarks.find(item => item.id === selectedId.value)!)
  const online = computed(() => connection.value === 'connected')
  const unread = computed(() => notices.value.filter(item => !item.read).length)
  const routeProgress = computed(() => (routeStep.value ?? 0) / 4 * 100)
  const remaining = computed(() => Math.round(selected.value.distance * (1 - routeProgress.value / 100)))
  const routeInstruction = computed(() => {
    if (routeStep.value === null)
      return '选择一个地点，预览步行路线。'
    return ['沿前方步道直行', '在下一个路口右转', '继续前往目标锚点', '目的地就在前方', `已到达${selected.value.name}`][routeStep.value]
  })

  function notify(title: string, detail: string) {
    notices.value = [{
      id: ++sequence,
      title,
      detail,
      time: new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }),
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
        notify('空间扫描完成', `${scene.value.name}已识别 3 个模拟锚点，可选中锚点并开始导航。`)
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
    notify('已切换模拟场景', `当前场景：${scene.value.name}。`)
  }
  function togglePin() {
    if (!online.value || scanProgress.value !== 100)
      return
    pinned.value = !pinned.value
    notify(pinned.value ? '空间锚点已固定' : '空间锚点已释放', '锚点仅作用于当前模拟场景。')
  }
  function startRoute() {
    if (!online.value)
      return
    routeStep.value = 0
    openModule('navigation')
    notify('模拟导航已开始', `目的地：${selected.value.name}。使用「前进一步」演示行进过程。`)
  }
  function advanceRoute() {
    if (!online.value || routeStep.value === null || routeStep.value >= 4)
      return
    routeStep.value++
    if (routeStep.value === 4)
      notify('已到达目的地', `${selected.value.name}的模拟路线已完成。`)
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
    notify(next === 'sleeping' ? '模拟设备已待机' : '模拟设备已断开', '扫描与导航已停止，摄像头和声音将关闭。')
  }
  function connect() {
    if (connection.value === 'connected' || connection.value === 'connecting')
      return
    connection.value = 'connecting'
    connectTimer = setTimeout(() => {
      connection.value = 'connected'
      notify('模拟设备已连接', '视界已就绪，可以扫描空间或选择一个应用。')
    }, 900)
  }
  function tick() {
    const now = new Date()
    time.value = now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
    date.value = now.toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' })
  }
  onMounted(() => {
    tick()
    clockTimer = setInterval(tick, 1000)
    notify('欢迎进入 Augma', '这是本地设备模拟。地点、距离与扫描结果均为演示数据。')
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
    time: readonly(time),
    date: readonly(date),
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
