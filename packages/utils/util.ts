import type { Ref } from "vue";
import { getCurrentInstance } from "vue";
import { AugmaOptions } from "./config";

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

/**
 * 对象遍历为数组
 * @param obj
 */
export function entries<T>(obj: Hash<T>): [string, T][] {
  return Object.keys(obj).map((key: string) => [key, obj[key]]);
}

/**
 * 获取全局配置
 */
export function useGlobalConfig(): AugmaOptions {
  const vm = getCurrentInstance();
  if ("$AUGMA" in vm.proxy) {
    return vm.proxy["$AUGMA"];
  }
  return {} as AugmaOptions;
}
