import type { Ref } from "vue";
/**
 * 清除定时器
 * @param timer
 */
export const clearTimer = (timer: Ref<TimeoutHandle>) => {
  clearTimeout(timer);
  timer = null;
};
