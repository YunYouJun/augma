import { getCurrentInstance } from 'vue'
import { toRawType } from '@vue/shared'
import type { AugmaOptions } from './config'
import type { Hash } from './types'

/**
 * 清除定时器
 * @param timer
 */
export const clearTimer = (timer: any) => {
  if (timer)
    clearTimeout(timer)

  timer = null
}

/**
 * 对象遍历为数组
 * @param obj
 */
export function entries<T>(obj: Hash<T>): [string, T][] {
  return Object.keys(obj).map((key: string) => [key, obj[key]])
}

/**
 * 获取全局配置
 */
export function useGlobalConfig(): AugmaOptions {
  const vm = getCurrentInstance()
  if ('$AUGMA' in vm.proxy)
    return vm.proxy.$AUGMA

  return {} as AugmaOptions
}

export const isBool = (val: unknown) => typeof val === 'boolean'
export const isHTMLElement = (val: unknown) =>
  toRawType(val).startsWith('HTML')
