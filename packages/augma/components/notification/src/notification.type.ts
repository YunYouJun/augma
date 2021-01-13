import type { VNode } from "vue";

export interface INotificationHandle {
  close: () => void;
}

export type INotification = (
  options?: INotificationOptions
) => INotificationHandle;

export type INotificationOptions = {
  duration?: number;
  id?: string;
  message?: string | VNode;
  zIndex?: number;
  onClose?: () => void;
  onClick?: () => void;
  offset?: number; // default 0
  position?: "top-right" | "top-left" | "bottom-right" | "bottom-left"; // default top-right
  showClose?: boolean;
  type?: "success" | "warning" | "info" | "error" | "";
  title?: string;
  icon?: string;
};

export type NotificationVM = VNode;

type NotificationQueueItem = {
  vm: NotificationVM;
  $el: HTMLElement;
};

export type NotificationQueue = Array<NotificationQueueItem>;
