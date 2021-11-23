import { AgmColorType } from '@augma/shared'

import type { VNode } from 'vue'
export type Position =
  | 'top-right'
  | 'top-left'
  | 'bottom-right'
  | 'bottom-left'

export interface INotificationHandle {
  close: () => void
}

export type INotificationOptions = {
  duration?: number
  id?: string
  message?: string | VNode
  zIndex?: number
  onClose?: () => void
  onClick?: () => void
  offset?: number // default 0
  position?: Position // default top-right
  showClose?: boolean
  type?: AgmColorType
  title?: string
  icon?: string
}

export type INotification = (
  options?: INotificationOptions
) => INotificationHandle

export type NotificationVM = VNode

type NotificationQueueItem = {
  vm: NotificationVM
}

export type NotificationQueue = Array<NotificationQueueItem>
