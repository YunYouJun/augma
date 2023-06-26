import type { Indexable } from '@augma/types'

export type AgmColorType =
  | ''
  | 'primary'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'

export const AgmTypeArray: AgmColorType[] = [
  '',
  'primary',
  'success',
  'warning',
  'danger',
  'info',
]

export const AgmTypeMap: Indexable<AgmColorType> = {
  default: '',
  primary: 'primary',
  success: 'success',
  warning: 'warning',
  danger: 'danger',
  info: 'info',
}

/**
 * 获取类型对应颜色
 * @param type
 * @returns
 */
export function getAgmColorByType(type: string) {
  if (type && AgmTypeMap[type])
    return `var(--agm-${type})`
  else
    return type
}

export type ComponentSize = 'large' | 'medium' | 'small' | ''
