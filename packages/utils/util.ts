import type { Ref } from "vue";
/**
 * 清除定时器
 * @param timer
 */
export const clearTimer = (timer: NodeJS.Timeout | null) => {
  if (timer) {
    clearTimeout(timer);
  }
  timer = null;
};
