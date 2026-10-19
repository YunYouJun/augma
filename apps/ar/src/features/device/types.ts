import type { Message } from '../../i18n/locale'

export type DeviceModule = 'space' | 'navigation' | 'audio' | 'notifications' | 'settings' | 'weather' | 'camera' | 'commands' | 'device'
export type Connection = 'connected' | 'connecting' | 'disconnected' | 'sleeping'
export type SceneId = 'garden' | 'city'
export type LandmarkId = 'terrace' | 'pavilion' | 'tree' | 'gallery' | 'station' | 'square'

interface LandmarkPlacement {
  id: LandmarkId
  distance: number
  x: number
  y: number
}

/** A landmark with its name and description translated into the active locale. */
export interface Landmark extends LandmarkPlacement {
  name: string
  description: string
}

export interface DeviceNotice {
  id: number
  title: Message
  detail: Message
  /** Creation timestamp, formatted when displayed so it follows the active locale. */
  at: number
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
  speechFeedback: boolean
}

export const scenes: { id: SceneId, landmarks: LandmarkPlacement[] }[] = [
  {
    id: 'garden',
    landmarks: [
      { id: 'terrace', distance: 120, x: 68, y: 35 },
      { id: 'pavilion', distance: 80, x: 29, y: 51 },
      { id: 'tree', distance: 45, x: 53, y: 65 },
    ],
  },
  {
    id: 'city',
    landmarks: [
      { id: 'gallery', distance: 240, x: 70, y: 37 },
      { id: 'station', distance: 160, x: 30, y: 48 },
      { id: 'square', distance: 60, x: 55, y: 66 },
    ],
  },
]

export const deviceModules: readonly DeviceModule[] = ['space', 'navigation', 'audio', 'notifications', 'settings', 'weather', 'camera', 'commands', 'device']
