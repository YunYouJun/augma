export type DeviceModule = 'space' | 'navigation' | 'audio' | 'notifications' | 'settings' | 'weather' | 'camera' | 'commands' | 'device'
export type Connection = 'connected' | 'connecting' | 'disconnected' | 'sleeping'
export type SceneId = 'garden' | 'city'

export interface Landmark {
  id: string
  name: string
  description: string
  distance: number
  x: number
  y: number
}

export interface DeviceNotice {
  id: number
  title: string
  detail: string
  time: string
  read: boolean
}

export interface DisplaySettings {
  opacity: number
  volume: number
  dark: boolean
  showHud: boolean
  mirror: boolean
  focus: boolean
  depthMotion: boolean
  curvedHud: boolean
}

export const scenes: { id: SceneId, name: string, description: string, landmarks: Landmark[] }[] = [
  {
    id: 'garden',
    name: '空中庭院',
    description: '沿着光的方向，重新发现身边的空间。',
    landmarks: [
      { id: 'terrace', name: '观景平台', description: '穿过庭院，在开阔处停留片刻。', distance: 120, x: 68, y: 35 },
      { id: 'pavilion', name: '玻璃回廊', description: '连接庭院两侧的透明步行空间。', distance: 80, x: 29, y: 51 },
      { id: 'tree', name: '中央绿洲', description: '一处可以静下来聆听的绿意。', distance: 45, x: 53, y: 65 },
    ],
  },
  {
    id: 'city',
    name: '城市漫游',
    description: '让下一段旅程，浮现在眼前。',
    landmarks: [
      { id: 'gallery', name: '光之美术馆', description: '沿步道前往街角的公共展览空间。', distance: 240, x: 70, y: 37 },
      { id: 'station', name: '空中车站', description: '经过连桥，到达城市交通节点。', distance: 160, x: 30, y: 48 },
      { id: 'square', name: '街角广场', description: '建筑之间的小型开放广场。', distance: 60, x: 55, y: 66 },
    ],
  },
]

export const deviceModules: { id: DeviceModule, label: string }[] = [
  { id: 'space', label: '空间' },
  { id: 'navigation', label: '导航' },
  { id: 'audio', label: '声音' },
  { id: 'notifications', label: '通知' },
  { id: 'settings', label: '设置' },
  { id: 'weather', label: '天气' },
  { id: 'camera', label: '摄像头' },
  { id: 'commands', label: '语音指令' },
  { id: 'device', label: '设备' },
]
